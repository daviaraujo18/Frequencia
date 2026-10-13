class CreateTarefasRecalculo < ActiveRecord::Migration[8.0]
  # Sprint 31, task 31.1 — fila assíncrona de recálculo por evento (PRD §5.2,
  # L139-148). Port ADAPTADO da estrutura de `presenca_historicotarefa`
  # (legado) ao domínio do Frequência: só os campos com consumidor conhecido
  # (`tipo_entidade`, `status`, `payload`, `referencia`, `processada_em`) —
  # não replica 1:1 o esquema legado (regra global: não portar campo sem
  # necessidade).
  #
  # `referencia` é a chave estável do evento/alvo (base da idempotência do
  # `TarefaRecalculo.enfileirar!`): duas mudanças do MESMO alvo produzem a
  # MESMA referência, então a fila guarda no máximo UMA tarefa PENDENTE por
  # par (`tipo_entidade`, `referencia`). Tarefas já processadas/em erro NÃO
  # entram na regra — reprocessar um alvo depois de drenado cria uma linha
  # nova (o índice parcial só cobre `status = 'pendente'`).
  #
  # `payload` é `jsonb` (padrão já existente no app, ver `regimes.expediente`)
  # e carrega os dados específicos do alvo/handler (ex.: user_id, data).
  def change
    create_table :tarefas_recalculo do |t|
      # Um dos 7 tipos do PRD §5.2 (ver `TarefaRecalculo::TIPOS_ENTIDADE`).
      t.string :tipo_entidade, null: false

      # "pendente" | "processada" | "erro" (ver `TarefaRecalculo::STATUSES`).
      t.string :status, null: false, default: "pendente"

      # Dados do alvo consumidos pelo handler do tipo (default `{}`).
      t.jsonb :payload, null: false, default: {}

      # Chave estável do evento/alvo — base da idempotência.
      t.string :referencia, null: false

      # Preenchido quando a tarefa é drenada (status vira processada/erro).
      t.datetime :processada_em

      t.timestamps
    end

    # Sustenta a idempotência: no máximo UMA tarefa PENDENTE por par
    # (tipo, referência). Índice UNIQUE **parcial** (`where: "status =
    # 'pendente'"`) — mesmo estilo de
    # `index_gestor_individual_gerenciados_on_par_ativo`. O parcial é o que
    # permite reprocessar o mesmo alvo depois de drenado (a linha antiga já
    # não é pendente), sem bloquear para sempre — é também o que fecha a
    # corrida entre dois `enfileirar!` concorrentes no lado do banco.
    add_index :tarefas_recalculo,
              [ :tipo_entidade, :referencia ],
              unique: true,
              where: "status = 'pendente'",
              name: "index_tarefas_recalculo_on_pendente_unico"

    # Consulta do job de despacho (31.2): `where(status: "pendente")`.
    add_index :tarefas_recalculo, :status
  end
end
