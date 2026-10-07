# Tarefa 30.10 (Sprint 30, frente 5 — diretiva do dev de 2026-10-07) —
# garante o `User` local dos GESTORES DE UNIDADE a partir do Pessoas.
#
# ── O furo que esta tarefa fecha ───────────────────────────────────────────
# O `User` local nasce por unidade de LOTAÇÃO (`ImportarServidoresUnidadeJob`
# percorre `unidade.servidores`, isto é, lotação principal e vigente). Um
# gestor de unidade (atual/substituto/excepcional) que NÃO tenha lotação
# vigente NUNCA é importado → não tem `User` local → não consegue logar → não
# exerce o passo 5 (hierarquia) da cascata, que avalia o `usuario` LOGADO
# (`AutorizacaoFrequencia#gestor_de_orgao_do?` → `Pessoas::Unidade#gestor?/#cadeia_ascendente`).
# Medido no Pessoas: 1330 unidades, 518 gestores distintos, dos quais 24 SEM
# lotação vigente — exatamente os que este serviço passa a cobrir. É um furo de
# COBERTURA DE DADOS, não de autorização: o passo 5 já lê gestor do Pessoas
# (29.4); nada de autorização nova é implementado aqui.
#
# ── Fonte (SOMENTE LEITURA) ────────────────────────────────────────────────
# Enumera os gestores distintos pela UNIÃO das três colunas de `unidades`
# (`gestor_id`, `gestor_substituto_id`, `gestor_excepcional_id`) e carrega as
# `Pessoas::Pessoa` correspondentes. O `PessoasRecord` é `readonly!` por
# contrato — nenhuma escrita é feita no banco espelho. O `User`/cache criados
# são LOCAIS (banco do Frequencia).
#
# ── Q12 (decisão do dev — recomendação acatada) ────────────────────────────
# Criamos `User` local para TODOS os 518 gestores, INCLUSIVE os cujo único
# vínculo de gestão aponta para unidade INELEGÍVEL/extinta. A conta é NEUTRA
# (não concede autorização por si); a elegibilidade é avaliada em TEMPO DE
# REQUEST pelo passo 5 (`Pessoas::Unidade#elegivel?`). Por isso NÃO filtramos
# por `elegivel?` na enumeração — filtrar produziria uma cobertura PARCIAL
# artificial e um novo ponto cego no shadow. Ver `iteration_30.md` §Q12.
#
# ── Idempotência ───────────────────────────────────────────────────────────
# Chave estável = CPF. `User.find_or_initialize_by(cpf:)` (via
# `GarantirUserLocalService`) só CRIA quando ausente e nunca sobrescreve o
# existente. O `FrequentadorCache` é atualizado SÓ na criação — logo
# "2ª execução = 0 criações / 0 escritas". `DRY_RUN` percorre o mesmo caminho
# sem escrever nada.
#
# ── Relatório SEM PII ──────────────────────────────────────────────────────
# Nenhuma linha do relatório imprime CPF, login ou nome: os não-resolvidos são
# agrupados por MOTIVO (contagem). Nada é silenciosamente ignorado.
#
# Uso:
#   ImportarGestoresDeUnidadeService.call                  # garante de verdade
#   ImportarGestoresDeUnidadeService.call(dry_run: true)    # só relatório
class ImportarGestoresDeUnidadeService
  # Relatório final. `nao_resolvidos` é enumerável (por MOTIVO, sem PII).
  Resultado = Struct.new(:processados, :atribuidos, :sem_alteracao, :nao_resolvidos, :erros, :dry_run, :falha_leitura, keyword_init: true) do
    # Contabilidade fechada: todo gestor enumerado vira um dos quatro destinos.
    def total_contabilizado
      atribuidos + sem_alteracao + nao_resolvidos.size + erros
    end

    # String para o log da task e inspeção manual. Agrupa os não-resolvidos por
    # MOTIVO (contagem) — nunca imprime CPF/login/nome (PII).
    def resumo
      modo = dry_run ? "DRY-RUN (nenhuma escrita)" : "execução real"
      linhas = [
        "Garantia do User local dos gestores de unidade (Pessoas -> Frequencia) — #{modo}"
      ]
      linhas << "  ⚠️ FALHA DE LEITURA DO PESSOAS — nenhum gestor lido; nada foi garantido" if falha_leitura
      linhas += [
        "  gestores distintos: #{processados}",
        "  criados:            #{atribuidos}",
        "  sem alteração:      #{sem_alteracao}",
        "  não resolvidos:     #{nao_resolvidos.size}",
        "  erros:              #{erros}"
      ]
      nao_resolvidos.group_by(&:motivo).each do |motivo, itens|
        linhas << "    - #{itens.size}x #{motivo}"
      end
      linhas.join("\n")
    end
  end

  # Sem CPF no payload: o motivo basta (sem PII).
  NaoResolvido = Struct.new(:motivo, keyword_init: true)

  # `unidades:` permite injetar a coleção (testes) sem tocar o Pessoas. Cada
  # item deve responder a `gestor_id`/`gestor_substituto_id`/
  # `gestor_excepcional_id` e às três associações homônimas.
  def self.call(unidades: nil, dry_run: false)
    new(dry_run: dry_run).call(unidades)
  end

  def initialize(dry_run: false)
    @dry_run = dry_run
    @atribuidos = 0
    @sem_alteracao = 0
    @nao_resolvidos = []
    @erros = 0
    # Distingue "a leitura do Pessoas FALHOU" de "não há gestores". Só é setado
    # no caminho de leitura (não quando as unidades são injetadas).
    @falha_leitura = false
  end

  def call(unidades = nil)
    gestores = enumerar_gestores(unidades || carregar_unidades)

    gestores.each { |pessoa| processar(pessoa) }

    Resultado.new(
      processados: gestores.size,
      atribuidos: @atribuidos,
      sem_alteracao: @sem_alteracao,
      nao_resolvidos: @nao_resolvidos,
      erros: @erros,
      dry_run: @dry_run,
      falha_leitura: @falha_leitura
    )
  end

  private

  # --- leitura read-only do Pessoas -----------------------------------------

  # Seam de leitura do Pessoas — ÚNICO ponto que toca o banco espelho (read-only
  # por contrato `PessoasRecord`). É um método de CLASSE próprio (OWN) para
  # poder ser stubado nos testes SEM `remove_method` (ver
  # test/support/class_method_stub_helper.rb). `includes` pré-carrega as 3
  # associações de gestor (evita N+1 na enumeração).
  def self.unidades_do_pessoas
    Pessoas::Unidade.includes(:gestor, :gestor_substituto, :gestor_excepcional).to_a
  end

  # Falha de leitura vira `falha_leitura` — nunca é confundida com "nenhum
  # gestor".
  def carregar_unidades
    self.class.unidades_do_pessoas
  rescue StandardError => e
    @falha_leitura = true
    Rails.logger.error("[ImportarGestoresDeUnidadeService] ERRO ao ler unidades do Pessoas: #{e.class} - #{e.message}")
    []
  end

  # --- enumeração dos gestores distintos ------------------------------------

  # União de `gestor_id`/`gestor_substituto_id`/`gestor_excepcional_id` de todas
  # as unidades, deduplicada por ID (identidade) e depois por CPF. Retorna uma
  # lista de `Pessoas::Pessoa` — e `nil` para um id cuja pessoa NÃO existe no
  # Pessoas (vínculo órfão/indisponível), que entra no relatório como não
  # resolvido (nunca é silenciosamente ignorado).
  #
  # NÃO filtra por `unidade.elegivel?` (Q12 — ver cabeçalho da classe).
  def enumerar_gestores(unidades)
    por_id = {}
    unidades.each do |unidade|
      triplas(unidade).each do |id, pessoa|
        id = id.to_s.presence
        next if id.nil?

        por_id[id] = pessoa unless por_id.key?(id)
      end
    end

    deduplicar_por_cpf(por_id.values)
  end

  # As 3 associações de gestor de uma unidade como pares `[id, pessoa]`.
  # `id` vem da COLUNA (`gestor_id`), `pessoa` da associação — assim um id
  # presente sem pessoa (FK órfã) é detectável.
  def triplas(unidade)
    [
      [ unidade.gestor_id, unidade.gestor ],
      [ unidade.gestor_substituto_id, unidade.gestor_substituto ],
      [ unidade.gestor_excepcional_id, unidade.gestor_excepcional ]
    ]
  end

  # Deduplica por CPF (mesma pessoa referida por várias unidades/associações).
  # Pessoas SEM CPF (ou ausentes) são preservadas — já vêm deduplicadas por id
  # e o CPF em branco não é uma chave válida para colapsar identidades.
  def deduplicar_por_cpf(gestores)
    vistos = {}
    gestores.select do |pessoa|
      cpf = normalizar_cpf(pessoa&.cpf)
      next true if cpf.blank?

      if vistos.key?(cpf)
        false
      else
        vistos[cpf] = true
      end
    end
  end

  # --- garantir o User local de um gestor -----------------------------------

  def processar(pessoa)
    if pessoa.nil?
      return registrar_nao_resolvido("pessoa do gestor ausente ou indisponível no Pessoas")
    end

    cpf = normalizar_cpf(pessoa.cpf)
    if cpf.blank?
      return registrar_nao_resolvido("gestor sem CPF no Pessoas")
    end

    if pessoa.nome.blank?
      return registrar_nao_resolvido("gestor sem nome no Pessoas")
    end

    criado = garantir(cpf, pessoa)
    criado ? @atribuidos += 1 : @sem_alteracao += 1
  rescue StandardError => e
    # Uma pessoa ruim não pode abortar o lote. O erro é contado e logado — sem
    # PII (só a classe da exceção). Ex.: colisão de `username` (RecordInvalid)
    # entra aqui, nunca é resolvida em silêncio.
    @erros += 1
    Rails.logger.error("[ImportarGestoresDeUnidadeService] ERRO ao garantir User de gestor: #{e.class}")
  end

  # Em dry-run apenas PROJETA a criação (consulta `User.exists?`), sem escrever
  # nada. Na execução real, cria o `User` (se ausente) e atualiza o
  # FrequentadorCache SÓ na criação. Retorna `true` se criou.
  def garantir(cpf, pessoa)
    if @dry_run
      !User.exists?(cpf: cpf)
    else
      criado = GarantirUserLocalService.call(cpf: cpf, pessoa: pessoa)
      AtualizarFrequentadorCacheService.call(cpf: cpf, pessoa: pessoa) if criado
      criado
    end
  end

  # --- utilidades -----------------------------------------------------------

  # CPF normalizado como chave: `""`/`nil` → `nil` (mesmo cuidado do
  # ImportarGestoresIndividuaisService).
  def normalizar_cpf(cpf)
    cpf.to_s.presence
  end

  def registrar_nao_resolvido(motivo)
    @nao_resolvidos << NaoResolvido.new(motivo: motivo)
    Rails.logger.info("[ImportarGestoresDeUnidadeService] gestor não resolvido: #{motivo}")
    nil
  end
end
