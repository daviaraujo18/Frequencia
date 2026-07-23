require "test_helper"

class PunchTypeServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  # --- Cenário 1: Sem registros no dia ---

  test "returns entry when no records exist for the user today" do
    assert_equal "entry", PunchTypeService.determine(@user.id)
  end

  test "returns entry when user has records only on previous days" do
    yesterday = Time.zone.now - 1.day

    travel_to yesterday do
      TimeRecord.create!(
        user: @user,
        raw_data: "yesterday entry",
        punched_at: yesterday,
        authentication_mode: "biometric",
        punch_type: "entry"
      )
    end

    assert_equal "entry", PunchTypeService.determine(@user.id)
  end

  # --- Cenário 2: Último registro é 'entry' → retorna 'exit' ---

  test "returns exit when last record today is entry" do
    now = Time.zone.now

    TimeRecord.create!(
      user: @user,
      raw_data: "entry punch",
      punched_at: now - 1.hour,
      authentication_mode: "biometric",
      punch_type: "entry"
    )

    assert_equal "exit", PunchTypeService.determine(@user.id)
  end

  # --- Cenário 3: Último registro é 'exit' → retorna 'entry' ---

  test "returns entry when last record today is exit" do
    now = Time.zone.now

    TimeRecord.create!(
      user: @user,
      raw_data: "exit punch",
      punched_at: now - 1.hour,
      authentication_mode: "biometric",
      punch_type: "exit"
    )

    assert_equal "entry", PunchTypeService.determine(@user.id)
  end

  # --- Teste de alternância com múltiplos registros ---
  # Garante que o service usa o MAIS RECENTE (ordenado por punched_at DESC)

  test "returns exit when most recent record is entry even with older exit" do
    now = Time.zone.now

    # Registro mais antigo: exit
    TimeRecord.create!(
      user: @user,
      raw_data: "older exit",
      punched_at: now - 2.hours,
      authentication_mode: "biometric",
      punch_type: "exit"
    )

    # Registro mais recente: entry
    TimeRecord.create!(
      user: @user,
      raw_data: "recent entry",
      punched_at: now - 1.hour,
      authentication_mode: "biometric",
      punch_type: "entry"
    )

    # O último registro é 'entry' → deve retornar 'exit'
    assert_equal "exit", PunchTypeService.determine(@user.id)
  end

  test "returns entry when most recent record is exit even with older entry" do
    now = Time.zone.now

    # Registro mais antigo: entry
    TimeRecord.create!(
      user: @user,
      raw_data: "older entry",
      punched_at: now - 2.hours,
      authentication_mode: "biometric",
      punch_type: "entry"
    )

    # Registro mais recente: exit
    TimeRecord.create!(
      user: @user,
      raw_data: "recent exit",
      punched_at: now - 1.hour,
      authentication_mode: "biometric",
      punch_type: "exit"
    )

    # O último registro é 'exit' → deve retornar 'entry'
    assert_equal "entry", PunchTypeService.determine(@user.id)
  end

  # --- Cenário 4: Registros de dias anteriores não afetam ---

  test "previous day records do not interfere with current day decision" do
    now = Time.zone.now
    yesterday = now - 1.day

    travel_to yesterday do
      # Ontem o usuário registrou 'entry' como último registro
      TimeRecord.create!(
        user: @user,
        raw_data: "yesterday entry",
        punched_at: yesterday + 1.hour,
        authentication_mode: "biometric",
        punch_type: "entry"
      )
    end

    # Hoje não há registros → deve retornar 'entry' (início do dia)
    assert_equal "entry", PunchTypeService.determine(@user.id)
  end

  test "previous day exit does not force entry today" do
    now = Time.zone.now
    yesterday = now - 1.day

    travel_to yesterday do
      TimeRecord.create!(
        user: @user,
        raw_data: "yesterday exit",
        punched_at: yesterday + 1.hour,
        authentication_mode: "biometric",
        punch_type: "exit"
      )
    end

    # Hoje sem registros → 'entry' (começa novo dia)
    assert_equal "entry", PunchTypeService.determine(@user.id)
  end

  # --- Cenário 5: Usuário inexistente → fallback seguro 'entry' ---

  test "returns entry for non-existent user" do
    assert_equal "entry", PunchTypeService.determine(999_999)
  end

  # --- Teste de borda: reference_time é aceito como parâmetro ---

  test "accepts reference_time parameter without error" do
    reference = Time.zone.now - 1.day
    result = PunchTypeService.determine(@user.id, reference)
    assert_equal "entry", result
  end
end
