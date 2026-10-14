# Sprint 31, task 31.4 — handler do evento `RECALCULAR_TODOS` da fila de
# recálculo por evento (PRD §5.2, L146): "força recálculo de todos os
# frequentadores com vínculo ativo".
#
# Diferença de eixo em relação aos handlers de registro (31.3): lá o alvo é
# UM par (user, data) vindo do `payload`; aqui o alvo é o CONJUNTO de
# frequentadores com VÍNCULO ATIVO, resolvido em tempo de execução — não há
# alvo no `payload` (o tipo é um "gatilho global", não um evento por entidade).
#
# Eixo "vínculo ativo" (NÃO inventado aqui): é o MESMO do `Pessoas::Vinculo.ativos`
# já consumido pela cascata (`FrequentadoresVisiveis`, 29.6) e por
# `Pessoas::Vinculo.frequentadores_ativos`. O `ativos` seleciona vínculos com
# `vinculos_estados.nome == "em_exercicio"` e sem `fim` (ou fim ainda não
# alcançado). Como `PessoasRecord` é READONLY e vive em OUTRO banco Postgres,
# NÃO há JOIN cross-database: resolvemos os CPFs no Pessoas e depois
# selecionamos os `User` locais por CPF (`User.where(cpf: cpfs)`), exatamente
# como a 29.x liga `users.cpf` ↔ pessoas (mesmo padrão de `cpfs_por_nome`/`cpfs_por_orgao`).
#
# Pipeline: mesma FILOSOFIA do `CalcularFrequenciaJob` (17.5) — por usuário,
# recalcula os ÚLTIMOS 3 DIAS (`CalculoDiarioService.calcular`) e consolida o
# MÊS CORRENTE (`ConsolidacaoMensalService.consolidar`). O loop é um MIRROR
# deliberado do job (poucas linhas) em vez de extrair um colaborador
# compartilhado: preservar o comportamento do job é regra, e refatorá-lo para
# acomodar esta task aumentaria o risco de regressão sem ganho real de
# reuso. Ambos os services são idempotentes (`find_or_initialize_by`), então
# rodar o handler 2× produz o MESMO estado.
#
# Guarda de mês finalizado (32.2, débito D2 da 31.4): o handler espelha a guarda
# do `CalcularFrequenciaJob` (32.1) — predicado `ConsolidacaoMensalService.finalizado?`
# lido ANTES de cada escrita (por DIA, no laço) e antes de consolidar, com memo
# por [ano, mes] local à execução por usuário. Sem a guarda, `calcular` reescrevia
# o `CalculoDiario` de um mês fechado antes de o `consolidar` levantar o erro.
#
# DECISÃO DE LOCK/CONCORRÊNCIA (obrigatória — ver o risco da task): este
# handler roda DENTRO do drain do `ExecutaTarefasJob`, que JÁ segura o advisory
# lock próprio `728_104_536`. Por isso NÃO pegamos um segundo advisory lock
# aqui — em particular, NÃO reusamos o `CalcularFrequenciaJob::LOCK_KEY`
# (`451_926_073`): sob concorrência com o job noturno, um
# `pg_try_advisory_lock(451_926_073)` retornaria `false`, o handler sairia sem
# fazer nada e o `ExecutaTarefasJob` marcaria a tarefa como `processada` —
# ou seja, a tarefa seria DRENADA SEM EFEITO, silenciosamente. Isso é pior do
# que a sobreposição que o lock evitaria: a sobreposição com o job noturno é
# CONVERGENTE (ambos rodam o mesmo pipeline idempotente sobre os mesmos dados),
# então rodar em paralelo é aceitável — o pior caso é trabalho duplicado, não
# dado incorreto.
#
# Registro no registry do `ExecutaTarefasJob`: feito no boot por
# `config/initializers/recalculo_handlers.rb` (via `to_prepare`, idempotente e
# explícito), NÃO no carregamento deste arquivo — o autoload do Zeitwerk é lazy
# e registrar em tempo de carga faria o handler só existir depois que algo
# referenciasse a constante.
class RecalcularTodosHandler
  # Mesmo valor de `CalcularFrequenciaJob::DIAS_RECALCULADOS` — mirror
  # deliberado da filosofia do job noturno (não reabrir a decisão de design).
  DIAS_RECALCULADOS = 3

  class << self
    # Contrato do registry (`ExecutaTarefasJob.registrar_handler`): recebe a
    # `TarefaRecalculo`. Ignora o `payload` — o alvo é o conjunto de
    # frequentadores com vínculo ativo, resolvido em tempo de execução.
    #
    # Nunca levanta para condições "esperadas". Erro em UM usuário é isolado
    # (`rescue StandardError` por usuário, log por CPF) e o lote segue — mesmo
    # padrão do `CalcularFrequenciaJob`.
    #
    # @param _tarefa [TarefaRecalculo]
    def call(_tarefa)
      cpfs = cpfs_com_vinculo_ativo

      # Lista vazia: NADA com vínculo ativo (ou o Pessoas indisponível sem
      # resultado). Guard explícito para NÃO varrer a base inteira por engano:
      # `User.where(cpf: [])` já é vazio, mas o guard documenta a intenção e
      # evita qualquer evolução futura que troque o filtro.
      return if cpfs.empty?

      User.where(cpf: cpfs).find_each { |user| processar_usuario(user) }
    end

    private

    # CPFs dos frequentadores com VÍNCULO ATIVO. `compact` é higiene: descarta
    # CPFs nulos (pessoa sem CPF no Pessoas) para não propagar `nil` no array.
    # (O `IN (..., NULL)` do Postgres já ignora NULL — nunca casaria os `User`
    # sem CPF; o `compact` só mantém a lista limpa.)
    def cpfs_com_vinculo_ativo
      Pessoas::Vinculo.ativos
        .joins(:pessoa)
        .distinct
        .pluck("pessoas.cpf")
        .compact
    end

    # Recalcula UM usuário: últimos 3 dias + mês corrente — mirror do loop de
    # `CalcularFrequenciaJob#processar_usuario` (32.1). Manter a semântica
    # IGUAL à do job é obrigatório (débito D2/17.5): qualquer divergência de
    # guarda aqui recria o desalinhamento que a 32.2 corrige.
    def processar_usuario(user)
      return if user.cpf.blank?

      hoje = Date.current

      # Memoização de `finalizado?` por [ano, mes] — escopo LOCAL desta
      # execução por usuário (não é cache global), igual ao job. O handler
      # processa MUITOS usuários, então o memo é por usuário/execução. O
      # predicado era consultado até 4×/usuário (3× no laço dos dias + 1× antes
      # de consolidar); fora da virada de mês os 3 dias são o MESMO mês ⇒ 3
      # `find_by` idênticos. No máximo 2 meses distintos por execução (corrente
      # e, na virada, o anterior).
      #
      # Usa `Hash#key?` em vez de `||=`: o valor é booleano e o caminho comum é
      # `false` ("mês aberto"); um `||=` simples faria o `false` reconsultar e
      # anularia o ganho. `key?` distingue "não cacheado" de "cacheado como
      # false".
      meses_finalizados = {}
      finalizado = lambda do |ano, mes|
        chave = [ ano, mes ]
        return meses_finalizados[chave] if meses_finalizados.key?(chave)

        meses_finalizados[chave] = ConsolidacaoMensalService.finalizado?(user, ano, mes)
      end

      # Guarda de mês finalizado POR DIA (débito D2/17.5), espelhando o
      # `CalcularFrequenciaJob` (32.1) e o `RegistroRecalculoHandler` (31.3):
      # `calcular` faz `save!` sem trava própria, então checar a finalização
      # ANTES de calcular cada dia é o que impede reescrever o `CalculoDiario`
      # de um mês fechado (a trava 17.2 só levanta `MesFinalizadoError` no fim
      # do `consolidar`, tarde demais — a escrita já teria ocorrido). A guarda
      # é por dia, não só pelo mês de `hoje`: os 3 últimos dias podem cruzar a
      # virada de mês (ex.: dia 1 recalcula 01, e os dias 31/30 do mês ANTERIOR,
      # que pode estar finalizado). Mês finalizado ⇒ skip silencioso do dia.
      (0...DIAS_RECALCULADOS).each do |dias_atras|
        dia = hoje - dias_atras
        next if finalizado.call(dia.year, dia.month)

        CalculoDiarioService.calcular(user, dia)
      end

      # Consolidação do mês corrente: também pulada quando o mês já está
      # finalizado, pelo mesmo motivo (não reagregar um mês congelado). O
      # `rescue MesFinalizadoError` abaixo permanece como salvaguarda de corrida.
      return if finalizado.call(hoje.year, hoje.month)

      ConsolidacaoMensalService.consolidar(user, hoje.year, hoje.month)
    rescue ConsolidacaoMensalService::MesFinalizadoError
      # Esperado: mês já finalizado pela trava da 17.2 ⇒ skip silencioso (não é
      # erro) — mesmo tratamento do `CalcularFrequenciaJob`. Com a guarda prévia
      # acima, este é o caso de CORRIDA (TOCTOU — débito conhecido): o mês foi
      # finalizado por outro processo entre o predicado e o `consolidar`. O
      # caminho para corrigir um mês fechado é o retificador (decisão 17.2).
    rescue StandardError => e
      # Erro genuíno (qualquer etapa): loga por CPF e SEGUE para o próximo
      # usuário — um item ruim não derruba o lote.
      Rails.logger.error("[RecalcularTodosHandler] Falha ao processar CPF #{user.cpf}: #{e.message}")
    end
  end
end
