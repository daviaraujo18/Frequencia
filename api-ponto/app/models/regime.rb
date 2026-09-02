class Regime < ApplicationRecord
  # AG-2 (docs/PRD-FREQUENCIA.md §4.2) — agregado forte de jornada/período.
  # Estrutura trazida da Intranet legada (Regime.java,
  # ConfiguracaoFrequencia.java) em 2026-08-31 — a Intranet será
  # descomissionada e o Frequencia precisa ser autossuficiente com as
  # mesmas regras de negócio. Ver docs/01-inventario/02-regime-jornada.md.
  #
  # Escopo desta etapa: só estrutura/schema. O motor de cálculo que usa
  # esses campos (metaSemanal, periodosSemana, banco de horas) fica para
  # a Fase B (Sprints 16+) — ver decisão registrada no SPRINT-PLAN.md.
  #
  # NÃO replica o bug conhecido do legado (Q4, ConfiguracaoFrequencia#clone
  # copia limiteCredito em limiteDebito) — aqui não existe lógica de clone.

  # Códigos reais de `presenca_regime_categoriavinculo` — confirmados em
  # 2026-08-31 consultando o banco de produção da Intranet (`SELECT DISTINCT
  # categoria`, todos os 309 regimes, não só os ativos): 6 desses códigos
  # são usados de fato nos regimes já importados; `RESIDENTE` foi
  # adicionado a pedido do usuário (2026-09-02) como categoria nova
  # disponível — existe no enum real do legado (`CategoriaVinculoEnum.java`)
  # mas nunca esteve vinculada a um regime até agora, então nenhum dos 309
  # regimes importados tem essa categoria (fica disponível pra uso daqui
  # pra frente).
  CATEGORIAS_DISPONIVEIS = %w[
    SERVIDOR_CARREIRA
    CARGO_COMISSIONADO
    ESTAGIARIO
    RESIDENTE
    TERCEIRIZADO
    AUXILIAR_DA_JUSTICA
    CEDIDO
  ].freeze

  # `enums/Modalidade.java` do legado. Confirmado em 2026-08-31 no banco de
  # produção: `HORAS` (285) e `OCORRENCIAS` (24) são os únicos valores
  # realmente usados nos 309 regimes — `HORAS_COM_INTERVALO` nunca aparece
  # em nenhum registro, o que confirma (sem resolver o "porquê") a dúvida Q1
  # da doc de engenharia reversa: existe e é calculável, mas não é usada na
  # prática. Mantida na lista pois é um valor válido do enum/motor de
  # cálculo, só não tem uso real observado.
  MODALIDADES_DISPONIVEIS = %w[HORAS HORAS_COM_INTERVALO OCORRENCIAS].freeze

  # Só para exibição (dropdown, listagem) — o valor persistido é sempre o
  # código real (`CATEGORIAS_DISPONIVEIS`), nunca o rótulo. Rótulos
  # atualizados a pedido do usuário (2026-09-02).
  CATEGORIAS_LABELS = {
    "SERVIDOR_CARREIRA" => "Servidor Efetivo",
    "CARGO_COMISSIONADO" => "Servidor Comissionado",
    "ESTAGIARIO" => "Estagiário",
    "RESIDENTE" => "Residente",
    "TERCEIRIZADO" => "Terceirizado",
    "AUXILIAR_DA_JUSTICA" => "Auxiliar de justiça",
    "CEDIDO" => "Cedido"
  }.freeze

  # Idem, para modalidade — o valor persistido continua sendo o código real.
  MODALIDADES_LABELS = {
    "HORAS" => "Horas",
    "HORAS_COM_INTERVALO" => "Horas com intervalo",
    "OCORRENCIAS" => "Ocorrências"
  }.freeze

  has_many :regime_frequentadores, dependent: :restrict_with_exception
  has_many :users, through: :regime_frequentadores
  has_many :regime_categorias, dependent: :destroy

  belongs_to :anterior, class_name: "Regime", optional: true
  belongs_to :padrao, class_name: "Regime", optional: true

  validates :nome, presence: true
  validates :modalidade, inclusion: { in: MODALIDADES_DISPONIVEIS }, allow_nil: true

  def categorias
    regime_categorias.map(&:categoria)
  end

  # Formatação de dias/horários pra coluna "Resumo" — mesmo formato do
  # legado (`Regime.java#getResumo()`: "{dias} de {inicio} às {fim}", um
  # item por período de `expediente`). É só formatação de exibição, não o
  # motor de cálculo (metaSemanal/banco de horas) — isso continua Fase B.
  # `resumo` (campo digitado manualmente no form) tem prioridade quando
  # presente; senão computa a partir do `expediente` real.
  def resumo_exibicao
    return [ resumo ] if resumo.present?

    Array(expediente).map do |periodo|
      "#{periodo['dias']} de #{periodo['inicio']} às #{periodo['fim']}"
    end
  end

  def categorias=(lista)
    self.regime_categorias = Array(lista).reject(&:blank?).map { |categoria| RegimeCategoria.new(categoria: categoria) }
  end
end
