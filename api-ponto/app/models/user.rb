class User < ApplicationRecord
  has_secure_password

  has_many :time_records, dependent: :restrict_with_exception
  has_many :regime_frequentadores, dependent: :restrict_with_exception
  has_many :regimes, through: :regime_frequentadores

  # Sprint 19 (task 19.1, UC-08): intervenções (batida manual/errata) que
  # afetaram este usuário, e as que este usuário registrou como responsável
  # (admin) — mesmo model, dois papéis diferentes.
  has_many :intervencoes_frequencia, class_name: "IntervencaoFrequencia", dependent: :restrict_with_exception
  has_many :intervencoes_frequencia_como_responsavel, class_name: "IntervencaoFrequencia",
                                                        foreign_key: :responsavel_id,
                                                        inverse_of: :responsavel,
                                                        dependent: :restrict_with_exception

  # Sprint 19 (task 19.3, UC-10): intervenções que este usuário resolveu
  # (deferiu/indeferiu) como gestor — papel distinto de "responsavel"
  # (quem criou o pedido; pode ser nulo quando é o sistema que cria).
  has_many :intervencoes_frequencia_como_resolvedor, class_name: "IntervencaoFrequencia",
                                                       foreign_key: :resolvido_por_id,
                                                       inverse_of: :resolvido_por,
                                                       dependent: :restrict_with_exception

  # Vínculo do Frequentador local (login da estação) com o espelho de dados
  # do Pessoas (Sprint 10) — via CPF, não FK numérica. optional porque
  # frequentadores cadastrados manualmente (sem cpf) continuam válidos.
  belongs_to :frequentador_cache, foreign_key: :cpf, primary_key: :cpf, inverse_of: :user, optional: true

  before_validation :generate_username, on: :create

  validates :nome_completo, presence: true
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :status, presence: true
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validates :cpf, uniqueness: true, format: { with: /\A\d{11}\z/ }, allow_nil: true

  scope :ativos, -> { where(status: 1) }
  scope :com_digitais, -> { where.not(digitais_hash: nil) }

  private

  def generate_username
    return if username.present?

    parts = I18n.transliterate(nome_completo.to_s)
          .downcase
          .gsub(/[^a-z0-9\s]/, "")
          .split
          .compact

    return if parts.empty?

    base = parts.size == 1 ? parts.first : "#{parts.first}.#{parts.last}"

    return if base.blank?

    candidate = base
    suffix = 1
    while User.exists?(username: candidate)
      suffix += 1
      candidate = "#{base}.#{suffix}"
    end

    self.username = candidate
  end
end
