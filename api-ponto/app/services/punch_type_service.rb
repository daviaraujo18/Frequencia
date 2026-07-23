class PunchTypeService
  def self.determine(user_id, reference_time = Time.current)
    new(user_id, reference_time).determine
  end

  def initialize(user_id, reference_time)
    @user_id = user_id
    @reference_time = reference_time
  end

  def determine
    last_record = TimeRecord.last_today(@user_id)
    return "entry" if last_record.nil? || last_record.punch_type == "exit"

    "exit"
  end
end
