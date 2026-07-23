class TimeRecord < ApplicationRecord
  belongs_to :user

  validates :raw_data, presence: true
  validates :punched_at, presence: true
  validates :authentication_mode, presence: true, inclusion: { in: %w[biometric manual] }
  validates :punch_type, inclusion: { in: %w[entry exit], allow_nil: true }

  scope :by_date, ->(date) { where(punched_at: date.beginning_of_day..date.end_of_day) }
  def self.last_today(user_id)
    where(user_id: user_id, punched_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
      .order(punched_at: :desc, created_at: :desc)
      .first
  end
end
