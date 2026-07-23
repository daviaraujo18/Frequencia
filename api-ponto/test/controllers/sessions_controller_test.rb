require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(nome_completo: "Admin Teste", password: "123456")
  end

  test "deve mostrar formulario de login" do
    get login_path
    assert_response :success
    assert_select "h3", "API Ponto TJPI"
  end

  test "deve fazer login com credenciais validas" do
    post login_path, params: { username: @user.username, password: "123456" }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
  end

  test "deve rejeitar login com senha invalida" do
    post login_path, params: { username: @user.username, password: "errada" }
    assert_response :unprocessable_entity
    assert_select ".alert-danger", "Usuário ou senha inválidos"
  end

  test "deve fazer logout" do
    post login_path, params: { username: @user.username, password: "123456" }
    delete logout_path
    assert_redirected_to login_path
  end
end
