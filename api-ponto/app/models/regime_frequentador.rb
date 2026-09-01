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
end
