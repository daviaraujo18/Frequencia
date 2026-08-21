require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(nome_completo: "Admin Teste", password: "123456")
    post login_path, params: { username: @user.username, password: "123456" }
  end

  test "deve carregar dashboard" do
    get dashboard_path
    assert_response :success
    assert_select ".app-content-header h1", "Dashboard"
  end

  test "deve redirecionar para login se nao autenticado" do
    delete logout_path
    get dashboard_path
    assert_redirected_to login_path
  end
end
