class TimeRecord < ApplicationRecord
  belongs_to :user

  validates :raw_data, presence: true
  validates :punched_at, presence: true
  validates :authentication_mode, presence: true, inclusion: { in: %w[biometric manual] }
end
