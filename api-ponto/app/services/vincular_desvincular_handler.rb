# Sprint 31, task 31.5 — handler do evento `VINCULAR_DESVINCULAR` da fila de
# recálculo por evento (PRD §5.2, L144): "recalcula os dias do período".
#
# A entidade que EMITE o evento é `RegimeFrequentador` (Q14, CONFIRMADA pelo
# dev): é o vínculo de um PERÍODO de regime a um frequentador
# (`momento_inicial`/`momento_final`) — o único domínio do Frequencia que casa
# com "recalcula os dias do período". O produtor é um CALLBACK `after_commit`
# no próprio model (ver `app/models/regime_frequentador.rb`): é o único locus
# de ciclo-de-vida do vínculo que existe, porque a app NUNCA escreve
# `regime_frequentadores` (confirmado por varredura — só `db/migrate` cria a
# tabela; as únicas referências são de LEITURA em `CalculoDiarioService` e
# `ConsolidacaoMensalService`). Não há controller/rota/service de CRUD de
# vínculo para pendurar o enfileiramento.
#
# Alvo (vem do `payload`, chaves String — `jsonb` chega desserializado):
# `user_id` + o PERÍODO (`momento_inicial`, `momento_final`). Recalcula os
# DIAS do período (`CalculoDiarioService.calcular`, idempotente por
# usuário+data) e consolida os MESES afetados (`ConsolidacaoMensalService.consolidar`,
# idempotente por usuário+ano+mês). O handler NÃO implementa regra de cálculo
# própria — é só o ponto de despacho da fila para o domínio que já existe.
#
# Registro no registry do `ExecutaTarefasJob`: feito no boot por
# `config/initializers/recalculo_handlers.rb` (via `to_prepare`, idempotente e
# explícito), NÃO no carregamento deste arquivo — o autoload do Zeitwerk é lazy
# e registrar em tempo de carga faria o handler só existir depois que algo
# referenciasse a constante.
class VincularDesvincularHandler
  # Chaves do `payload` (strings). Definidas pelo produtor — ver o callback
  # `enfileirar_recalculo` em `RegimeFrequentador`.
  USER_ID_KEY = "user_id"
  MOMENTO_INICIAL_KEY = "momento_inicial"
  MOMENTO_FINAL_KEY = "momento_final"

  # Período ABERTO (`momento_final` nil = vínculo vigente): o fim do intervalo
  # é `Date.current` — NUNCA o futuro (ver `recortar_fim`).
  #
  # Limite de observabilidade (NÃO é truncamento): a partir deste tamanho o
  # handler LOGA um `warn` para dar visibilidade a um período anormalmente
  # longo. O comportamento continua recalculando TODOS os dias do período —
  # decisão deliberada de volume, ver o comentário de `recalcular_periodo`.
  PERIODO_ALERTA_DIAS = 366

  class << self
    # Contrato do registry (`ExecutaTarefasJob.registrar_handler`): recebe a
    # `TarefaRecalculo`. Nunca levanta para condições "esperadas" — o job
    # marca `erro` só quando a exceção sobe.
    #
    # @param tarefa [TarefaRecalculo]
    def call(tarefa)
      payload = tarefa.payload || {}

      user = User.find_by(id: payload[USER_ID_KEY])
      inicio = parse_data(payload[MOMENTO_INICIAL_KEY])
      raw_fim = payload[MOMENTO_FINAL_KEY]
      fim = parse_data(raw_fim)

      # Payload inválido ⇒ skip silencioso (não é erro), MESMO tratamento da
      # 31.3. Três casos: alvo ausente (`user` inexistente), `momento_inicial`
      # ausente/não parseável, ou `momento_final` PRESENTE mas não parseável
      # (distinto de `momento_final` ausente, que é período ABERTO — válido).
      return if user.nil? || inicio.nil?
      return if raw_fim.present? && fim.nil?

      recalcular_periodo(user, inicio, fim)
      # NÃO há `rescue MesFinalizadoError` aqui (correção pós-review, 🟡-S1):
      # o `MesFinalizadoError` é tratado no ÚNICO ponto em que pode nascer — o
      # `consolidar` privado abaixo — e nem `finalizado?` nem
      # `CalculoDiarioService.calcular` o levantam. Um rescue neste nível seria
      # código morto (enganaria o leitor fazendo crer que há um caminho de erro
      # não tratado). A salvaguarda de corrida (TOCTOU) vive no `consolidar`.
    end

    private

    # Recalcula os DIAS do período [inicio, fim] e consolida os MESES distintos
    # afetados. `fim` nil = período aberto.
    def recalcular_periodo(user, inicio, fim)
      # Fim efetivo (período aberto ⇒ `Date.current`), recortado para nunca
      # passar de `Date.current` (nunca recalcula dia FUTURO).
      fim_data = recortar_fim(fim)

      # Período invertido (`fim < inicio`) ou inteiramente futuro ⇒ nada a
      # recalcular. Skip silencioso (payload inválido, não é erro).
      return if inicio > fim_data

      dias = (inicio..fim_data).to_a

      # DECISÃO DE VOLUME (risco registrado na task): a consolidação roda UMA
      # VEZ POR (ano, mês) DISTINTO do período — nunca uma vez por dia —, o que
      # corta o custo de agregação do mês para 1 por mês em vez de 1 por dia.
      # Os dias em si SÃO todos recalculados (o feature é justamente o recálculo
      # RETROATIVO do período; truncar dias produziria dados errados — e o
      # enunciado proíbe truncar em silêncio). Mitigações: idempotência (rerodar
      # é seguro) + isolamento por dia/mês (um item ruim não derruba o resto) +
      # `warn` de observabilidade para períodos anormalmente longos.
      if dias.size > PERIODO_ALERTA_DIAS
        Rails.logger.warn(
          "[VincularDesvincularHandler] periodo longo: #{dias.size} dias " \
          "(user_id=#{user.id}, #{inicio}..#{fim_data}); recalculando TODOS os dias"
        )
      end

      # Uma entrada por mês, em ordem cronológica (Hash preserva a ordem de
      # inserção e `dias` está ordenado). Para cada mês: se NÃO estiver
      # finalizado, recalcula cada dia do mês no intervalo e consolida UMA vez.
      dias.group_by { |dia| [ dia.year, dia.month ] }.each do |(ano, mes), dias_do_mes|
        recalcular_mes(user, ano, mes, dias_do_mes)
      end
    end

    # Fim efetivo do intervalo: `momento_final` (ou `Date.current` se o período
    # está ABERTO), recortado em `Date.current` para NUNCA recalculre dia
    # FUTURO (lição/bug B da 31.3). O caso "início ainda no futuro" é tratado
    # pelo caller (`inicio > fim_data` ⇒ skip).
    def recortar_fim(fim)
      fim_data = fim || Date.current
      fim_data = Date.current if fim_data > Date.current
      fim_data
    end

    # Recalcula os dias de UM mês e consolida o mês UMA vez.
    #
    # Mês FINALIZADO (trava 17.2): skip silencioso daquele mês — não reescreve
    # nenhum dia e não consolida, coerente com a 31.3 (o caminho para corrigir
    # um mês fechado é o retificador, decisão 17.2). A checagem prévia é o
    # guard determinístico; o `rescue MesFinalizadoError` de `consolidar` cobre
    # a corrida residual (TOCTOU — débito conhecido, ver 31.3).
    def recalcular_mes(user, ano, mes, dias)
      return if ConsolidacaoMensalService.finalizado?(user, ano, mes)

      # Grão do isolamento de erro: POR DIA no recálculo e POR MÊS na
      # consolidação. Um dia que falhe é logado e pulado, os demais dias do mês
      # seguem; a consolidação do mês roda na sequência (idempotente). Um mês
      # que falhe na consolidação é logado e pulado, os demais meses seguem —
      # nada derruba o período inteiro.
      dias.each { |dia| recalcular_dia(user, dia) }
      consolidar(user, ano, mes)
    end

    def recalcular_dia(user, dia)
      CalculoDiarioService.calcular(user, dia)
    rescue StandardError => e
      Rails.logger.error("[VincularDesvincularHandler] Falha ao calcular o dia #{dia} do user #{user.id}: #{e.message}")
    end

    def consolidar(user, ano, mes)
      ConsolidacaoMensalService.consolidar(user, ano, mes)
    rescue ConsolidacaoMensalService::MesFinalizadoError
      # Esperado (corrida): mês finalizado por outro processo entre o guard
      # prévio e o `consolidar` ⇒ skip silencioso (não é erro).
    rescue StandardError => e
      Rails.logger.error("[VincularDesvincularHandler] Falha ao consolidar #{ano}-#{mes} do user #{user.id}: #{e.message}")
    end

    # Coage o valor do payload (String ISO8601, Date/Time/DateTime) para `Date`.
    # Nil/blank ⇒ nil (usado tanto para "ausente" quanto para "aberto").
    # Não parseável ⇒ nil (o caller distingue "presente mas inválido").
    def parse_data(valor)
      return nil if valor.blank?
      return valor.to_date if valor.is_a?(Date) || valor.is_a?(Time)

      Date.parse(valor.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
