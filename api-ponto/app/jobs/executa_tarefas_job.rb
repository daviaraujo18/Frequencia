# Sprint 31, task 31.2 — job de despacho da fila de recálculo por evento
# (PRD §5.2, L140-146). Port ADAPTADO do job `ExecutaTarefas` do legado:
# roda a cada ~5min (agendado em `config/schedule.yml`, produção) e DRENA a
# fila persistente (`TarefaRecalculo.pendentes`, entregue na 31.1),
# despachando cada tarefa por `tipo_entidade` ao handler correspondente.
#
# Esta task entrega SÓ o despacho. NÃO entram aqui: a lógica de recálculo
# (fica nos handlers das 31.3–31.5), retry/backoff sofisticado nem
# dashboard/UI da fila.
#
# Padrão dos outros jobs do app (CalcularFrequenciaJob e os de importação):
# advisory lock via `pg_try_advisory_lock`/`pg_advisory_unlock`, `rescue
# StandardError` POR ITEM sem derrubar o lote inteiro, log de erro por item.
class ExecutaTarefasJob < ApplicationJob
  queue_as :default

  # Chave DISTINTA das 5 já existentes no app — é um lock próprio, para que a
  # execução concorrente deste job não processe a mesma tarefa 2× sem
  # bloquear/colidir com os demais jobs (que têm suas próprias chaves):
  #   ImportarDadosPessoaJob        → 837_462_915
  #   ImportarServidoresUnidadeJob  → 592_017_384
  #   ImportarGestoresIndividuaisJob→ 471_209_336
  #   SincronizarAfastamentosJob    → 194_773_608
  #   CalcularFrequenciaJob         → 451_926_073
  # 728_104_536 foi escolhida por não coincidir com nenhuma delas (o valor em
  # si é arbitrário; o contrato é apenas a unicidade entre os jobs, que também
  # é verificada por teste).
  LOCK_KEY = 728_104_536

  # Registry de handlers por `tipo_entidade` (contrato MÍNIMO — de propósito,
  # sem framework de plugins): um mapa `tipo => callable`, em que o callable
  # recebe a `TarefaRecalculo` e executa o recálculo daquele tipo. Fica VAZIO
  # de fábrica — os handlers reais são registrados nas tarefas 31.3–31.5 via
  # `registrar_handler`. Nesta task ele é exercitado com um handler FAKE
  # injetado nos testes.
  #
  # `@handlers` é ivar de classe (o registry é global ao processo). Fica nil
  # até o primeiro uso, para não exigir inicialização no boot nem acoplar à
  # ordem de autoload do Zeitwerk.
  @handlers = nil

  class << self
    # Mapa `tipo_entidade` (String) => callable. Nunca congelado — o
    # registro é incremental conforme os handlers nascem.
    def handlers
      @handlers ||= {}
    end

    # Registra o handler de um tipo. Os handlers reais chamam isto (31.3–31.5);
    # os testes injetam um fake por aqui.
    def registrar_handler(tipo_entidade, callable)
      handlers[tipo_entidade.to_s] = callable
    end
  end

  # Sem argumentos — é disparado pelo agendador (sidekiq-cron) a cada 5min.
  def perform
    return unless lock_adquirido?

    begin
      TarefaRecalculo.pendentes.find_each { |tarefa| processar(tarefa) }
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

  # Processa UMA tarefa. Cada item é isolado: um erro aqui vira `erro` no item
  # e o lote segue para os próximos (`rescue StandardError`).
  def processar(tarefa)
    # Tipos adiados (sem domínio no Frequência hoje — ver 31.1): no-op
    # silencioso. O registry NEM é consultado: mesmo que alguém registrasse um
    # handler para um tipo adiado, ele não seria chamado aqui. Marca como
    # processada/skip (decisão registrada) e segue — nunca `raise`.
    return marcar_como_processada(tarefa) if adiada?(tarefa)

    handler = self.class.handlers[tarefa.tipo_entidade]

    # Tipo declarado no PRD mas ainda SEM handler registrado (as 31.3–31.5
    # ainda não rodaram): não é falha do item, então não é `erro` — skip
    # explícito. O registry é a fonte da verdade do que está "implementado".
    # O `warn` existe para o cenário FUTURO: quando as 31.3–31.5 criarem os
    # produtores destes tipos, um handler que não foi registrado (falha de
    # autoload/boot) faria a tarefa ser drenada sem efeito — sem este log, a
    # perda seria silenciosa. Tipos adiados NÃO passam por aqui (saem antes),
    # então o warn sinaliza só o caso anômalo.
    if handler.nil?
      Rails.logger.warn("[ExecutaTarefasJob] sem handler para #{tarefa.tipo_entidade}; drenando como processada (id=#{tarefa.id})")
      return marcar_como_processada(tarefa)
    end

    handler.call(tarefa)
    marcar_como_processada(tarefa)
  rescue StandardError => e
    # Erro de UM item não derruba o lote (o `find_each` continua). A tarefa
    # vira `erro` — sai de `pendentes`, então não é reprocessada
    # automaticamente (retry sofisticado está fora do escopo desta task).
    Rails.logger.error("[ExecutaTarefasJob] Falha ao processar tarefa #{tarefa.id} (#{tarefa.tipo_entidade}): #{e.message}")
    tarefa.update!(status: TarefaRecalculo::STATUS_ERRO)
  end

  def adiada?(tarefa)
    TarefaRecalculo::TIPOS_ADIADOS.include?(tarefa.tipo_entidade)
  end

  # Sai da fila marcando `processada` + `processada_em`. Vale tanto para o item
  # efetivamente recalculado quanto para o skip (adiado ou sem handler): ambos
  # "esvaziam" a fila — é o que sustenta a idempotência do drain. `processada_em`
  # só é setado no sucesso/skip (a coluna significa "processada"; o desfecho de
  # falha vai no `status`, e não há coluna separada de erro — recorte da 31.1).
  def marcar_como_processada(tarefa)
    tarefa.update!(status: TarefaRecalculo::STATUS_PROCESSADA, processada_em: Time.current)
  end
end
