require "test_helper"

class TimeRecordTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  # --- Column punch_type ---

  test "punch_type column exists and can be nil" do
    record = TimeRecord.create!(
      user: @user,
      raw_data: "2026-07-22 08:00:00",
      punched_at: Time.zone.now,
      authentication_mode: "biometric"
    )
    assert_nil record.punch_type
  end

  test "punch_type can store entry" do
    record = TimeRecord.create!(
      user: @user,
      raw_data: "2026-07-22 08:00:00",
      punched_at: Time.zone.now,
      authentication_mode: "biometric",
      punch_type: "entry"
    )
    assert_equal "entry", record.punch_type
  end

  test "punch_type can store exit" do
    record = TimeRecord.create!(
      user: @user,
      raw_data: "2026-07-22 08:00:00",
      punched_at: Time.zone.now,
      authentication_mode: "biometric",
      punch_type: "exit"
    )
    assert_equal "exit", record.punch_type
  end

  # --- Validation ---

  test "validates punch_type inclusion in entry or exit" do
    record = TimeRecord.new(
      user: @user,
      raw_data: "2026-07-22 08:00:00",
      punched_at: Time.zone.now,
      authentication_mode: "biometric",
      punch_type: "invalid"
    )
    assert_not record.valid?
    assert_includes record.errors[:punch_type], "is not included in the list"
  end

  test "validates punch_type allows nil" do
    record = TimeRecord.new(
      user: @user,
      raw_data: "2026-07-22 08:00:00",
      punched_at: Time.zone.now,
      authentication_mode: "biometric",
      punch_type: nil
    )
    assert record.valid?
  end

  test "validates punch_type accepts entry" do
    record = TimeRecord.new(
      user: @user,
      raw_data: "2026-07-22 08:00:00",
      punched_at: Time.zone.now,
      authentication_mode: "biometric",
      punch_type: "entry"
    )
    assert record.valid?
  end

  test "validates punch_type accepts exit" do
    record = TimeRecord.new(
      user: @user,
      raw_data: "2026-07-22 08:00:00",
      punched_at: Time.zone.now,
      authentication_mode: "biometric",
      punch_type: "exit"
    )
    assert record.valid?
  end

  # --- Scope by_date ---

  test "scope by_date returns records for the given date" do
    date = Date.new(2026, 7, 22)

    TimeRecord.create!(
      user: @user,
      raw_data: "2026-07-22 08:00:00",
      punched_at: date.midday,
      authentication_mode: "biometric"
    )

    TimeRecord.create!(
      user: @user,
      raw_data: "2026-07-23 08:00:00",
      punched_at: Date.new(2026, 7, 23).midday,
      authentication_mode: "biometric"
    )

    result = TimeRecord.by_date(date)
    assert_equal 1, result.count
  end

  test "scope by_date returns empty when no records match" do
    result = TimeRecord.by_date(Date.new(2025, 1, 1))
    assert_empty result
  end

  # --- Scope last_today ---

  test "scope last_today returns the most recent record for user today" do
    now = Time.zone.now
    earlier_today = now - 2.hours

    record_earlier = TimeRecord.create!(
      user: @user,
      raw_data: "earlier",
      punched_at: earlier_today,
      authentication_mode: "biometric"
    )

    record_later = TimeRecord.create!(
      user: @user,
      raw_data: "later",
      punched_at: now,
      authentication_mode: "biometric"
    )

    result = TimeRecord.last_today(@user.id)
    assert_equal record_later, result
    assert_equal "later", result.raw_data
  end

  test "scope last_today returns nil if no records exist today" do
    result = TimeRecord.last_today(@user.id)
    assert_nil result
  end

  test "scope last_today respects user_id filter" do
    user_two = users(:two)
    now = Time.zone.now

    TimeRecord.create!(
      user: user_two,
      raw_data: "user two record",
      punched_at: now,
      authentication_mode: "biometric"
    )

    result = TimeRecord.last_today(@user.id)
    assert_nil result
  end

  test "scope last_today orders by punched_at desc and created_at desc" do
    now = Time.zone.now

    first_record = TimeRecord.create!(
      user: @user,
      raw_data: "first",
      punched_at: now - 1.hour,
      authentication_mode: "biometric"
    )

    second_record = TimeRecord.create!(
      user: @user,
      raw_data: "second",
      punched_at: now,
      authentication_mode: "biometric"
    )

    result = TimeRecord.last_today(@user.id)
    assert_equal second_record, result
    assert_equal "second", result.raw_data
  end
end
