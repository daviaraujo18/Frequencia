# Sprint 31, task 31.3 — handler dos eventos `REGISTRO_FREQUENCIA` e
# `REGISTRO_ESTACAO` da fila de recálculo por evento (PRD §5.2, L145).
#
# O PRD descreve a regra como "recalcula o dia (se hoje) ou o mês". Este
# handler materializa exatamente isso: dado o alvo (`user` + `data`) no
# `payload` da `TarefaRecalculo`, recalcula SÓ o dia quando a data é HOJE,
# ou SÓ o mês (via consolidação) quando a data já passou. Não inventa um
# escopo temporal próprio (não reabre a filosofia do `CalcularFrequenciaJob`,
# que roda os últimos 3 dias + o mês corrente — decisão de design já tomada).
#
# Reuso do pipeline existente e JÁ IDEMPOTENTE: `CalculoDiarioService.calcular`
# (find_or_initialize_by usuário+data) e `ConsolidacaoMensalService.consolidar`
# (find_or_initialize_by usuário+ano+mês). O handler NÃO recalcula nada por
# conta própria — é só o ponto de despacho da fila para o domínio que já existe.
#
# Por que um handler único para os DOIS tipos: `REGISTRO_FREQUENCIA` (batida
# manual) e `REGISTRO_ESTACAO` (sincronização de estação) produzem o mesmo
# efeito de recálculo — o evento que os distingue é a ORIGEM do registro, não
# a regra de recálculo. Mantê-los no mesmo callable evita duplicar a lógica e
# é o contrato que o registry do `ExecutaTarefasJob` espera (um callable por
# `tipo_entidade`).
#
# Registro no registry: feito no boot por `config/initializers/recalculo_handlers.rb`
# (via `to_prepare`, idempotente e explícito), NÃO no carregamento deste arquivo
# — o autoload do Zeitwerk é lazy e registrar em tempo de carga faria o handler
# só existir depois que algo referenciasse a constante.
class RegistroRecalculoHandler
  # Chaves do `payload` (strings — `jsonb` chega desserializado com chaves
  # String). Definidas pelo produtor: ver `RegistroManualFrequenciaService` e
  # `Presenca::SincronizarRegistrosPontoController`.
  USER_ID_KEY = "user_id"
  DATA_KEY = "data"

  class << self
    # Contrato do registry (`ExecutaTarefasJob.registrar_handler`): recebe a
    # `TarefaRecalculo` e executa o recálculo do alvo. Nunca levanta para
    # condições "esperadas" — o job marca `erro` só quando a exceção sobe.
    #
    # @param tarefa [TarefaRecalculo]
    def call(tarefa)
      payload = tarefa.payload || {}
      user = User.find_by(id: payload[USER_ID_KEY])
      data = parse_data(payload[DATA_KEY])

      # Alvo ausente/inválido: nada a recalcular. Skip silencioso (não é
      # erro) — o registro pode ter sido removido entre a criação do evento
      # e o drain da fila; marcar `erro` aqui poluiria a fila sem ação útil.
      return if user.nil? || data.nil?

      recalcular(user, data)
    rescue ConsolidacaoMensalService::MesFinalizadoError
      # Mês fechado pela trava da 17.2 ⇒ skip silencioso, mesmo tratamento do
      # `CalcularFrequenciaJob`: não é erro, não marca `erro`, não loga como
      # falha. Nada a fazer — o retificador é o caminho para mês finalizado.
      #
      # Correção pós-review (bug A): o caso NORMAL de mês finalizado já é
      # barrado ANTES por `ConsolidacaoMensalService.finalizado?` (sem tocar
      # no dia). Este rescue permanece apenas como SALVAGUARDA DE CORRIDA.
      #
      # HONESTIDADE SOBRE A JANELA RESIDUAL (TOCTOU — débito conhecido, NÃO
      # coberto): este rescue evita APENAS a PROPAGAÇÃO da exceção, NÃO uma
      # reescrita. Se OUTRO processo finalizar o mês entre a checagem prévia
      # (`finalizado?` acima, que passou) e o `consolidar`, o ramo de data
      # passada já terá executado `CalculoDiarioService.calcular` — reescrevendo
      # o `CalculoDiario` do dia do mês recém-finalizado — ANTES de o
      # `consolidar` levantar `MesFinalizadoError` (aqui engolido). Ou seja: o
      # dia pode ter sido reescrito dentro dessa janela. A checagem prévia e o
      # `consolidar` são duas operações separadas (sem lock compartilhado), logo
      # a corrida existe. Probabilidade desprezível (a finalização de mês é
      # MANUAL e a janela é ínfima), mas o comportamento está documentado como
      # débito conhecido e deliberadamente não tratado nesta task.
    end

    private

    def recalcular(user, data)
      # Bug B (correção pós-review): data FUTURA é fora de escopo — não é
      # "hoje" nem "passado", então não há o que recalcular. Sem este guard,
      # a data futura (relógio da estação adiantado, `momento` futuro) cairia
      # no ramo do `else` e consolidaria um mês que ainda não aconteceu.
      return if data > Date.current

      # Bug A (correção pós-review): a trava de mês finalizado (17.2) vale
      # para o DIA também. `CalculoDiarioService.calcular` não tem guarda de
      # finalização (faz `save!` direto), e `consolidar` só levanta
      # `MesFinalizadoError` no FIM — sem esta checagem prévia, o dia seria
      # reescrito e só depois o erro subiria (e seria engolido), deixando o
      # `RegistroMensalFrequencia` desatualizado. Checar o mês-alvo ANTES de
      # recalcular qualquer coisa e pular tudo: nada muda. O caminho para
      # corrigir um mês fechado é o retificador (decisão 17.2).
      #
      # LIMITE DESTA CHECAGEM (TOCTOU — débito conhecido): o guard fecha o caso
      # determinístico (mês já finalizado quando o job roda), mas é "melhor
      # esforço" — NÃO fecha a janela em que o mês é finalizado por OUTRO
      # processo DEPOIS desta linha e ANTES do `consolidar`. Ver o comentário do
      # `rescue MesFinalizadoError` acima para a descrição da janela residual.
      return if ConsolidacaoMensalService.finalizado?(user, data.year, data.month)

      if data == Date.current
        # "Hoje": recalcula SÓ o dia (mais barato; o mês corrente é consolidado
        # pelo job noturno e o dia já é lido na hora). Não consolida o mês —
        # fiel ao "recalcula o dia (se hoje)" do PRD.
        CalculoDiarioService.calcular(user, data)
      else
        # Data passada: "recalcula o mês". Recalcular o mês É reagregar o
        # `RegistroMensalFrequencia`, mas a consolidação só soma os
        # `CalculoDiario` JÁ existentes — se o dia afetado for recalculado
        # apenas depois, a marcação nova não apareceria no mês. Por isso o
        # dia afetado é recalculado PRIMEIRO (`calcular`, idempotente) e só
        # então o mês é reagregado (`consolidar`, idempotente). Isso reusa o
        # mesmo pipeline do job noturno, sem reabrir a filosofia dele.
        CalculoDiarioService.calcular(user, data)
        ConsolidacaoMensalService.consolidar(user, data.year, data.month)
      end
    end

    def parse_data(valor)
      return nil if valor.blank?

      valor.is_a?(Date) ? valor : Date.parse(valor.to_s)
    rescue ArgumentError
      nil
    end
  end
end
