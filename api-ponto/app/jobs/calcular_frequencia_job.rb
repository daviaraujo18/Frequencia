# Sprint 17 (task 17.5) — job automático pra rodar o pipeline de cálculo
# (`CalculoDiarioService.calcular` → `ConsolidacaoMensalService.consolidar`),
# fechando o débito técnico registrado no fim da 17.4: os dois services
# existiam e funcionavam, mas nada os disparava automaticamente.
#
# Mesmo padrão dos outros jobs diários (`ImportarDadosPessoaJob`,
# `SincronizarAfastamentosJob`): advisory lock via `pg_try_advisory_lock`/
# `pg_advisory_unlock`, itera `User.where.not(cpf: nil).find_each`,
# `rescue StandardError` por usuário sem derrubar o job inteiro, log de
# erro por usuário.
#
# Escopo por execução (decisão já tomada, não reabrir):
# - Recalcula `CalculoDiario` (via `CalculoDiarioService.calcular`) dos
#   últimos 3 dias (hoje, ontem, anteontem) de cada usuário — não o mês
#   inteiro, caro e desnecessário rodar toda noite; 3 dias cobre correções
#   tardias de sincronização sem reprocessar histórico completo. O cálculo
#   já é idempotente (`find_or_initialize_by` dentro do service).
# - Consolida o mês corrente (via `ConsolidacaoMensalService.consolidar`)
#   de cada usuário, também idempotente.
# - GUARDA DE MÊS FINALIZADO POR DIA (débito D2/17.5, ver `processar_usuario`):
#   antes de calcular cada dia (e antes de consolidar o mês corrente), checa
#   `ConsolidacaoMensalService.finalizado?` e pula — a trava 17.2 precisa valer
#   também no recálculo automático, senão o `save!` do dia reescreveria um mês
#   fechado antes de o `consolidar` levantar o erro (que seria engolido).
# - `ConsolidacaoMensalService::MesFinalizadoError` segue esperado (mês fechado
#   pela trava da 17.2) e é pulado silenciosamente — não é erro, não conta
#   como falha, não loga como erro, só segue pro próximo usuário. Com a guarda
#   prévia, esse rescue passa a cobrir apenas a corrida (TOCTOU — débito
#   conhecido). Erros genuínos (`StandardError` de outra natureza, em qualquer
#   etapa) são logados por usuário, sem derrubar o job inteiro, mesmo padrão
#   dos outros dois jobs.
class CalcularFrequenciaJob < ApplicationJob
  queue_as :default

  DIAS_RECALCULADOS = 3

  # Chave distinta de ImportarDadosPessoaJob::LOCK_KEY (837_462_915),
  # ImportarServidoresUnidadeJob::LOCK_KEY (592_017_384) e
  # SincronizarAfastamentosJob::LOCK_KEY (194_773_608).
  LOCK_KEY = 451_926_073

  def perform(user_id = nil)
    return unless lock_adquirido?

    begin
      usuarios = user_id ? User.where(id: user_id) : User.where.not(cpf: nil)
      usuarios.find_each { |user| processar_usuario(user) }
    ensure
      liberar_lock
    end
  end

  private

  def lock_adquirido?
    ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})") == true
  end

  def liberar_lock
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{LOCK_KEY})")
  end

  def processar_usuario(user)
    return if user.cpf.blank?

    hoje = Date.current

    # Memoização de `finalizado?` por [ano, mes] — escopo LOCAL desta execução
    # por usuário (não é ivar de classe nem cache global: não sobrevive à
    # chamada atual). O predicado era consultado até 4×/usuário (3× no laço dos
    # dias + 1× antes de consolidar). Fora da virada de mês os 3 dias são o
    # MESMO mês ⇒ 3 `find_by` idênticos. Existem no máximo 2 meses distintos por
    # execução — o corrente e, na virada, o anterior —, então o memo reduz de até
    # 4 para no máximo 2 lookups por usuário.
    #
    # Usa `Hash#key?` em vez de `||=`: o valor é booleano e o caminho comum é
    # `false` ("mês aberto"); um `||=` simples faria o `false` reconsultar e
    # anularia o ganho. `key?` distingue "não cacheado" de "cacheado como false".
    meses_finalizados = {}
    finalizado = lambda do |ano, mes|
      chave = [ ano, mes ]
      return meses_finalizados[chave] if meses_finalizados.key?(chave)

      meses_finalizados[chave] = ConsolidacaoMensalService.finalizado?(user, ano, mes)
    end

    # Guarda de mês finalizado POR DIA (débito D2/17.5), espelhando o
    # `RegistroRecalculoHandler` (31.3, correção do bug A): `calcular` faz
    # `save!` sem trava própria, então checar a finalização ANTES de calcular
    # cada dia é o que impede reescrever o `CalculoDiario` de um mês fechado
    # (a trava 17.2 só levanta `MesFinalizadoError` no fim do `consolidar`,
    # tarde demais — a escrita já teria ocorrido). A guarda é por dia, não só
    # pelo mês de `hoje`: os 3 últimos dias podem cruzar a virada de mês (ex.:
    # dia 1 recalcula 01, e os dias 31/30 do mês ANTERIOR, que pode estar
    # finalizado). Mês finalizado ⇒ skip silencioso daquele dia.
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
    # Esperado: mês já finalizado pela trava da 17.2, não recalcula — não é
    # erro, segue pro próximo usuário silenciosamente. Com a guarda prévia
    # acima, este é o caso de CORRIDA (TOCTOU — débito conhecido): o mês foi
    # finalizado por outro processo entre o predicado e o `consolidar`.
  rescue StandardError => e
    Rails.logger.error("[CalcularFrequenciaJob] Falha ao processar CPF #{user.cpf}: #{e.message}")
  end
end
