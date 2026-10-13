# Sprint 19, task 19.1 (UC-08) — orquestra a criação de uma
# IntervencaoFrequencia, portado de `RegistroFrequencia#manualFromForm`
# (intranet/src/modules/presenca/beans/RegistroFrequencia.java:214-246).
#
# Batida manual (tipo: "batida_manual"): cria o TimeRecord real na hora
# (authentication_mode: "manual") e a IntervencaoFrequencia com
# status: "registrado", igual ao legado faz `Dao.save(this)` ANTES de criar
# a intervenção quando `!errata`.
#
# Errata (tipo: "errata"): NÃO cria TimeRecord — só a IntervencaoFrequencia
# com status: "pendente", igual ao legado só roda `Dao.save` no branch
# `!errata`. A resolução (aprovar cria o TimeRecord; rejeitar mantém só o
# histórico) é escopo de task futura da Sprint 19 (provavelmente 19.2,
# "desconsiderar/reconsiderar ponto") — não implementada aqui.
class RegistroManualFrequenciaService
  class << self
    # @param user [User] frequentador afetado
    # @param responsavel [User] admin que está registrando/solicitando
    # @param tipo ["batida_manual", "errata"]
    # @param momento [Time] data/hora do registro sendo inserido/corrigido
    # @param punch_type ["entry", "exit", nil]
    # @param justificativa [String] obrigatória
    # @return [IntervencaoFrequencia]
    def registrar(user:, responsavel:, tipo:, momento:, punch_type: nil, justificativa:)
      ApplicationRecord.transaction do
        time_record = nil

        if tipo == "batida_manual"
          time_record = TimeRecord.create!(
            user: user,
            punched_at: momento,
            punch_type: punch_type,
            authentication_mode: "manual",
            raw_data: "Batida manual registrada por #{responsavel.nome_completo}"
          )

          # Sprint 31 (task 31.3) — produtor da fila de recálculo por evento
          # (PRD §5.2): a criação do `TimeRecord` dispara o recálculo do dia
          # (se a data é hoje) ou do mês, sem esperar o job noturno.
          #
          # Enfileira DENTRO da mesma transação de criação (decidido na 31.3):
          # se algo depois falhar e a transação sofrer rollback, o `TimeRecord`
          # E a tarefa somem juntos — não sobra tarefa órfã apontando para um
          # registro que não existe. `enfileirar!` é idempotente por referência
          # estável `tipo:user_id:data` (2 batidas no mesmo dia = 1 tarefa
          # pendente). Só a batida manual cria `TimeRecord` (errata não cria —
          # ver o branch `tipo` acima), então só ela enfileira.
          TarefaRecalculo.enfileirar!(
            tipo_entidade: "REGISTRO_FREQUENCIA",
            referencia: "REGISTRO_FREQUENCIA:#{user.id}:#{momento.to_date.iso8601}",
            payload: { "user_id" => user.id, "data" => momento.to_date.iso8601 }
          )
        end

        IntervencaoFrequencia.create!(
          user: user,
          responsavel: responsavel,
          tipo: tipo,
          justificativa: justificativa,
          momento: momento,
          punch_type: punch_type,
          time_record: time_record,
          status: tipo == "batida_manual" ? "registrado" : "pendente"
        )
      end
    end
  end
end
