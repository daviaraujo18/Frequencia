class RegimeFrequentador < ApplicationRecord
  # Membro de AG-2 (docs/PRD-FREQUENCIA.md §4.2) — vínculo de um período de
  # regime a um frequentador. Corresponde ao legado
  # `presenca_regimefrequentador` (frequentador_id/regime_id/tipo/
  # momentoInicial/momentoFinal), sem os campos de auditoria de correção
  # (`momentoInicialOriginal`/`momentoFinalOriginal`/`dataAlteracao`), que
  # só fazem sentido quando existir edição retroativa (fora de escopo
  # desta sprint).

  belongs_to :user
  belongs_to :regime

  validates :momento_inicial, presence: true

  # --- Produtor da fila de recálculo por evento (Sprint 31, task 31.5) ----
  # PRD §5.2 (L144): `VINCULAR_DESVINCULAR` ⇒ "recalcula os dias do período".
  # A entidade que EMITE esse evento é o próprio `RegimeFrequentador` (Q14,
  # CONFIRMADA pelo dev): é o vínculo de um PERÍODO de regime a um
  # frequentador (`momento_inicial`/`momento_final`).
  #
  # Por que um CALLBACK `after_commit` e não um ponto de escrita explícito:
  # a app NUNCA escreve `regime_frequentadores` (varredura confirmou — nenhum
  # controller/rota/service/job/rake/seed; só `db/migrate` cria a tabela). Não
  # existe ponto de chamada de CRUD de vínculo onde enfileirar. O único locus
  # de ciclo-de-vida do vínculo que existe é o callback do model. Quando
  # surgir um CRUD de vínculo, este callback já o cobre sem alteração.
  #
  # Cobre os TRÊS verbos do ciclo de vida:
  #   - create  ⇒ vincular (novo período);
  #   - update  ⇒ alterar o período (só enfileira se `momento_inicial`/
  #               `momento_final` realmente mudou — ver `deve_enfileirar?`);
  #   - destroy ⇒ desvincular (encerrar/remover o vínculo).
  #
  # `after_commit` fica FORA da transação que persiste o vínculo — diferente
  # da 31.3, que enfileirava DENTRO (por causa da atomicidade com o
  # `TimeRecord`: se a transação rolasse back, tarefa e registro sumiam
  # juntos). Aqui isso é MELHOR: um rollback NÃO deixa tarefa órfã apontando
  # para um vínculo que não chegou a existir — o enfileiramento só roda depois
  # do commit, quando o vínculo é fato.
  after_commit :enfileirar_recalculo, on: [ :create, :update, :destroy ]

  # --- Precedência (Sprint 16, task 16.3) ---------------------------------
  # Portado de `TipoRegimeFrequentadorEnum.java` (ordem) +
  # `RegimentoServices.getRegimeFrequentador` (linhas 75-88, legado): quando
  # um frequentador tem mais de um `RegimeFrequentador` vigente na mesma
  # data, vence o de MAIOR ordem — TEMPORARIO(2) > DIFERENCIADO(1) >
  # OFICIAL(0).
  OFICIAL = "OFICIAL"
  DIFERENCIADO = "DIFERENCIADO"
  TEMPORARIO = "TEMPORARIO"

  TIPOS_DISPONIVEIS = [ OFICIAL, DIFERENCIADO, TEMPORARIO ].freeze

  PRECEDENCIA = {
    OFICIAL => 0,
    DIFERENCIADO => 1,
    TEMPORARIO => 2
  }.freeze

  # `tipo` hoje é campo livre (sem validação de valores), e o banco de dev
  # já tem `RegimeFrequentador`s existentes com `tipo` nil ou fora dos 3
  # valores válidos (ex: dado de teste/legado). Decisão: não quebrar esses
  # registros — um `tipo` ausente/desconhecido é tratado como a MENOR
  # precedência possível (abaixo até de OFICIAL), nunca levanta erro aqui.
  # Não adicionamos `validates :tipo, inclusion: ...` nesta task (fora de
  # escopo — mudaria comportamento de cadastro existente sem pedido
  # explícito); só a leitura/ordenação é defensiva.
  PRECEDENCIA_DESCONHECIDA = -1

  # Portado de `RegimeFrequentador.java:138-146` (`contem(Calendar data)`):
  # o período do vínculo contém a data quando `momento_inicial <= data` e
  # (`momento_final` é nil OU `data <= momento_final`).
  scope :vigentes_em, ->(data) {
    where("momento_inicial <= ?", data.to_date.end_of_day)
      .where("momento_final IS NULL OR momento_final >= ?", data.to_date.beginning_of_day)
  }

  # Portado de `RegimentoServices.getRegimeFrequentador(Frequentador, Calendar)`
  # (linhas 75-88, legado): lista os `RegimeFrequentador`s do usuário
  # vigentes na data, ordena por precedência (`PRECEDENCIA`) e retorna o de
  # MAIOR precedência (`TEMPORARIO > DIFERENCIADO > OFICIAL`). `nil` quando
  # não há nenhum vigente na data.
  #
  # Decisão de estrutura: método de classe em `RegimeFrequentador` (não
  # `User#regime_frequentador_vigente`) — a regra de precedência pertence
  # inteiramente aos dados do próprio `RegimeFrequentador` (seu `tipo` e
  # período), então fica mais natural como uma consulta de classe deste
  # model, no mesmo espírito de `RegimentoServices` ser um service dedicado
  # a `RegimeFrequentador`/`Regime` no legado.
  def self.vigente_para(user, data)
    where(user: user).vigentes_em(data).max_by { |rf| PRECEDENCIA.fetch(rf.tipo, PRECEDENCIA_DESCONHECIDA) }
  end

  private

  # Enfileira UMA tarefa `VINCULAR_DESVINCULAR` para o período do vínculo.
  #
  # CRÍTICO: `after_commit` roda DEPOIS do commit, mas uma exceção lançada
  # aqui PROPAGA para o caller e derruba a operação (o chamador vê um erro no
  # `create`/`update`/`destroy` que, na verdade, JÁ foi persistido). O
  # enfileiramento é um EFEITO COLATERAL best-effort — registrar a intenção de
  # recálculo NUNCA pode impedir a persistência do vínculo. Por isso todo o
  # corpo é protegido por `rescue StandardError` + log.
  def enfileirar_recalculo
    return unless deve_enfileirar?

    # `referencia` ESTÁVEL por período: 2 eventos do mesmo período (ex.: dois
    # creates com o mesmo intervalo, ou um create seguido do update que não
    # muda o período) ⇒ 1 única tarefa PENDENTE (o `enfileirar!` deduplica por
    # `tipo_entidade`+`referencia`). O `user_id` + as DATAS do período definem
    # a identidade do recálculo; o timestamp exato de `momento_inicial`/
    # `momento_final` (hora/minuto) é irrelevante — o recálculo é por DIA.
    referencia = "VINCULAR_DESVINCULAR:#{user_id}:#{momento_inicial.to_date.iso8601}:#{momento_final&.to_date&.iso8601}"

    TarefaRecalculo.enfileirar!(
      tipo_entidade: "VINCULAR_DESVINCULAR",
      referencia: referencia,
      payload: {
        "user_id" => user_id,
        "momento_inicial" => momento_inicial&.to_date&.iso8601,
        "momento_final" => momento_final&.to_date&.iso8601
      }
    )
  rescue StandardError => e
    # Nunca propaga: o vínculo já foi persistido; falhar em enfileirar o
    # recálculo é logável, não fatal. Um erro aqui NÃO pode derrubar o
    # `create`/`update`/`destroy` do chamador.
    Rails.logger.error("[RegimeFrequentador] Falha ao enfileirar recalculo do vinculo #{id}: #{e.message}")
  end

  # Quais ações enfileiram:
  #   - create/destroy: SEMPRE (vincular/desvincular);
  #   - update: SÓ quando o PERÍODO mudou. `saved_change_to_*`/`previous_changes`
  #     (não o `changed?`, que já foi limpo após o save). Em `after_commit`,
  #     `previous_changes` traz os atributos que foram de fato persistidos;
  #     `previously_new_record?`/`destroyed?` identificam create/destroy (o
  #     `previous_changes` de um create traz TODAS as colunas e o de um destroy
  #     vem vazio — por isso o discriminador é o estado, não o hash).
  def deve_enfileirar?
    return true if previously_new_record? || destroyed?

    previous_changes.key?("momento_inicial") || previous_changes.key?("momento_final")
  end
end
