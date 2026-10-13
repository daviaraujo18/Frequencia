# Sprint 31, task 31.1 — fila persistente de recálculo por evento (PRD §5.2,
# L139-148). Port ADAPTADO da tabela `presenca_historicotarefa` (legado) ao
# domínio do Frequência: só os campos com consumidor conhecido — o esquema
# legado NÃO é copiado 1:1 (regra global: não portar campo sem necessidade).
#
# Esta task entrega SÓ a estrutura da fila e a API de enfileiramento
# idempotente. NÃO entram aqui: o despacho (31.2) nem os handlers
# (31.3–31.5); nenhum produtor dos tipos adiados; nenhum uso de
# `Ability`/cascata.
#
# 7 tipos do PRD §5.2. `TIPOS_ENTIDADE` declara TODOS (fidelidade ao PRD), mas
# 3 deles — `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO` — estão ADIADOS: os models de
# domínio que os consumiriam NÃO existem no Frequência (brief da 30.3, §9.3),
# sob a política incremental (ruling 30.3 = A, emendado em 2026-10-07). Cada
# um nasce na tarefa que implementar a seção do PRD que o consome. Por isso o
# model os declara mas NENHUM produtor é criado para eles, e o despacho (31.2)
# não os toca — `TIPOS_ADIADOS` isola-os para o job (e para o meta-teste que
# prova a ausência de produtor).
class TarefaRecalculo < ApplicationRecord
  # O nome da tabela não segue a inferência do Rails (`tarefa_recalculos`) —
  # a tabela foi nomeada `tarefas_recalculo` (plural da 1ª palavra, padrão
  # herdado do domínio "tarefa de recálculo").
  self.table_name = "tarefas_recalculo"

  TIPOS_ENTIDADE = %w[
    FERIADO
    DIAEXCEPCIONAL
    DIREITO
    VINCULAR_DESVINCULAR
    REGISTRO_FREQUENCIA
    REGISTRO_ESTACAO
    RECALCULAR_TODOS
  ].freeze

  # Subconjunto de `TIPOS_ENTIDADE` sem domínio no Frequência hoje —
  # explicitamente adiado (o despacho os ignora com segurança).
  TIPOS_ADIADOS = %w[FERIADO DIAEXCEPCIONAL DIREITO].freeze

  STATUS_PENDENTE = "pendente"
  STATUS_PROCESSADA = "processada"
  STATUS_ERRO = "erro"
  STATUSES = [ STATUS_PENDENTE, STATUS_PROCESSADA, STATUS_ERRO ].freeze

  scope :pendentes, -> { where(status: STATUS_PENDENTE) }

  validates :tipo_entidade, presence: true, inclusion: { in: TIPOS_ENTIDADE }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :referencia, presence: true

  # Espelha no lado do Rails o índice UNIQUE parcial do banco (só a regra de
  # "no máximo UMA pendente por par"), para dar erro legível em criações
  # diretas; a garantia real — inclusive contra a corrida entre dois
  # `enfileirar!` concorrentes — é do índice `index_tarefas_recalculo_on_pendente_unico`.
  # O `if: :pendente?` casa com o `where` parcial: linhas não-pendentes
  # (processadas/erro) NÃO entram na regra.
  validates :referencia,
            uniqueness: { scope: :tipo_entidade, conditions: -> { where(status: STATUS_PENDENTE) } },
            if: :pendente?

  def pendente?
    status == STATUS_PENDENTE
  end

  # API de enfileiramento IDEMPOTENTE. Mesma `referencia` (por `tipo_entidade`)
  # em estado PENDENTE ⇒ devolve a linha existente, sem duplicar. Alvo/
  # referência distinto ⇒ cria uma linha nova. Depois de a tarefa ser drenada
  # (não é mais pendente), enfileirar o mesmo alvo cria uma linha NOVA (o
  # índice parcial e a validação só cobrem `pendente`).
  #
  # `referencia` é coagida a String para que o caller possa passar um id
  # inteiro sem quebrar a estabilidade da chave (ex.: `user_id` 7 e "7" casam).
  # O `payload` de uma tarefa já pendente NÃO é sobrescrito — a tarefa que
  # existe é devolvida como está (o alvo é o mesmo; o despacho lê o estado
  # atual do alvo, não um snapshot do payload).
  #
  # O `INSERT` é isolado num SAVEPOINT (`transaction(requires_new: true)`).
  # PORQUÊ: os produtores (RegistroManualFrequenciaService, SincronizarRegistrosPontoController)
  # chamam `enfileirar!` DENTRO da transação que persiste o `TimeRecord`. No
  # caminho de corrida, o `create!` estoura `ActiveRecord::RecordNotUnique`
  # (índice único parcial) e o `rescue` abaixo faz `pendentes.find_by!` — uma
  # query NOVA. Em PostgreSQL, um `unique_violation` ABORTA a transação inteira:
  # sem o savepoint, essa query subsequente levantaria `PG::InFailedSqlTransaction`
  # (não capturado) → derrubaria a transação do produtor → perderia o `TimeRecord`
  # (erro espúrio, sem corrupção). O savepoint confina o `unique_violation`, então
  # o `ROLLBACK TO SAVEPOINT` limpa o estado abortado e a transação do caller
  # segue saudável — o `find_by!` do rescue roda normalmente.
  #
  # Comportamento externo inalterado: fora de transação, `requires_new` só abre
  # uma transação normal; a idempotência (pendente existente ⇒ devolve a
  # existente; após drenada ⇒ cria nova) é a mesma.
  def self.enfileirar!(tipo_entidade:, referencia:, payload: {})
    tipo = tipo_entidade.to_s
    ref = referencia.to_s

    existente = pendentes.find_by(tipo_entidade: tipo, referencia: ref)
    return existente if existente

    # SAVEPOINT em volta SÓ do INSERT (ver comentário acima): protege a
    # transação do caller caso outro processo insira a linha PENDENTE do mesmo
    # par entre o SELECT acima e este INSERT.
    ActiveRecord::Base.transaction(requires_new: true) do
      create!(tipo_entidade: tipo, referencia: ref, payload: payload)
    end
  rescue ActiveRecord::RecordNotUnique
    # Corrida: outra linha PENDENTE do mesmo par foi inserida entre o SELECT
    # acima e o INSERT — o índice único parcial garantiu a unicidade; devolve
    # a que venceu.
    pendentes.find_by!(tipo_entidade: tipo, referencia: ref)
  rescue ActiveRecord::RecordInvalid => e
    # Mesma corrida, mas a linha concorrente já era visível à validação de
    # unicidade (o outro INSERT commitou antes dela rodar) ⇒ `RecordInvalid`
    # em vez de `RecordNotUnique`. Só trata o caso "referência já tomada";
    # qualquer outra invalidez (ex.: `tipo_entidade` fora de `TIPOS_ENTIDADE`)
    # sobe, para não mascarar erro de uso.
    raise unless e.record.errors.of_kind?(:referencia, :taken)

    pendentes.find_by!(tipo_entidade: tipo, referencia: ref)
  end
end
