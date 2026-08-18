require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(nome_completo: "Admin Teste", password: "123456", admin: true)
    post login_path, params: { username: @admin.username, password: "123456" }
  end

  test "deve listar usuarios" do
    get users_path
    assert_response :success
  end

  test "deve mostrar formulario de novo usuario" do
    get new_user_path
    assert_response :success
    assert_select "h2", "Novo Usuário"
  end

  test "deve criar usuario" do
    assert_difference("User.count") do
      post users_path, params: { user: { nome_completo: "Novo Usuário", password: "123456", password_confirmation: "123456" } }
    end
    assert_redirected_to users_path
  end

  test "deve mostrar formulario de edicao" do
    user = User.create!(nome_completo: "Editável", password: "123456")
    get edit_user_path(user)
    assert_response :success
  end

  test "deve atualizar usuario" do
    user = User.create!(nome_completo: "Editável", password: "123456")
    patch user_path(user), params: { user: { nome_completo: "Nome Alterado" } }
    assert_redirected_to users_path
    assert_equal "Nome Alterado", user.reload.nome_completo
  end

  test "deve inativar usuario" do
    user = User.create!(nome_completo: "Inativável", password: "123456")
    delete user_path(user)
    assert_redirected_to users_path
    assert_equal 0, user.reload.status
  end

  test "deve excluir usuario inativo sem registros" do
    user = User.create!(nome_completo: "Excluível", password: "123456", status: 0)
    assert_difference("User.count", -1) do
      delete purge_user_path(user)
    end
    assert_redirected_to users_path
  end

  test "nao deve excluir usuario ativo" do
    user = User.create!(nome_completo: "Ativo", password: "123456")
    delete purge_user_path(user)
    assert_redirected_to users_path
    assert_not_nil User.find_by(id: user.id)
  end

  test "nao deve excluir usuario inativo com registros de ponto" do
    user = User.create!(nome_completo: "Com Registro", password: "123456", status: 0)
    TimeRecord.create!(user: user, raw_data: "abc", punched_at: Time.zone.now, authentication_mode: "manual")
    delete purge_user_path(user)
    assert_redirected_to users_path
    assert_not_nil User.find_by(id: user.id)
  end
end
