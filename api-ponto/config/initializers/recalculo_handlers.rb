# Sprint 31, task 31.3 — registro dos handlers da fila de recálculo por evento
# (PRD §5.2) no registry do `ExecutaTarefasJob` (entregue na 31.2).
#
# O registry é estado de classe (`ExecutaTarefasJob.handlers`) e fica VAZIO de
# fábrica; cada handler de tipo se registra aqui. Fazer o registro num
# initializer (em vez de no corpo do próprio arquivo do handler) é a forma
# EXPLÍCITA de garantir que o registry esteja populado no boot, sem depender
# do autoload lazy do Zeitwerk — registrar em tempo de carga do arquivo do
# handler só aconteceria quando algo referenciasse a constante, o que não é
# garantido no boot do processo de trabalho (Sidekiq).
#
# `to_prepare` é o hook correto para referenciar constantes RECARREGÁVEIS de
# `app/` a partir de um initializer no Rails 7+/Zeitwerk: roda uma vez após o
# eager load em produção e antes de cada (re)carga em desenvolvimento. É
# IDEMPOTENTE por natureza — reexecutar apenas reatribui a MESMA chave do
# registry (`handlers[tipo] = callable`), sem duplicar nem acumular.
Rails.application.config.to_prepare do
  # Os dois eventos usam o MESMO handler (a regra de recálculo é idêntica; o
  # que difere é só a origem do registro — ver `RegistroRecalculoHandler`).
  # `method(:call)` preserva a assinatura do contrato do registry (recebe a
  # `TarefaRecalculo`).
  handler = RegistroRecalculoHandler.method(:call)

  ExecutaTarefasJob.registrar_handler("REGISTRO_FREQUENCIA", handler)
  ExecutaTarefasJob.registrar_handler("REGISTRO_ESTACAO", handler)
end
