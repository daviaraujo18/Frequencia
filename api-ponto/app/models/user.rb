class User < ApplicationRecord
  has_secure_password

  has_many :time_records, dependent: :restrict_with_exception

  before_validation :generate_username, on: :create

  validates :nome_completo, presence: true
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :status, presence: true
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

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
