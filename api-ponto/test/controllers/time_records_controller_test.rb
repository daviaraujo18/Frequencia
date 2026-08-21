require "test_helper"

class TimeRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(nome_completo: "Admin Teste", password: "123456")
    @user = User.create!(nome_completo: "Frequentador", password: "123456")
    @record = TimeRecord.create!(user: @user, raw_data: "#{@user.id}-15:07:2026:14:30:45", punched_at: Time.current, authentication_mode: "biometric")
    post login_path, params: { username: @admin.username, password: "123456" }
  end

  test "deve listar registros de ponto" do
    get time_records_path
    assert_response :success
    assert_select ".app-content-header h1", "Registros de Ponto"
  end

  test "deve filtrar por usuario" do
    get time_records_path, params: { user_id: @user.id }
    assert_response :success
  end

  test "deve filtrar por data" do
    get time_records_path, params: { start_date: Date.yesterday, end_date: Date.tomorrow }
    assert_response :success
  end
end
