require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(nome_completo: "Admin Teste", password: "123456", admin: true)
    post login_path, params: { username: @admin.username, password: "123456" }
  end

  # Pedido do usuário (2026-09-02): index passou a listar
  # Pessoas::Vinculo.ativos (mesmo padrão de admin/frequentadores, task
  # 10.10) em vez de só User.order(:nome_completo). pessoas_test não tem
  # schema carregado (task 8.13) — stuba o ponto de entrada, mesmo padrão
  # já usado em frequentadores_controller_test.rb.
  test "deve listar usuarios" do
    Pessoas::Vinculo.define_singleton_method(:frequentadores_ativos) { |**_kwargs| Kaminari.paginate_array([]).page(1) }

    get users_path

    assert_response :success
  ensure
    Pessoas::Vinculo.singleton_class.remove_method(:frequentadores_ativos)
  end

  test "usuario local sem cpf aparece na secao separada, mesmo sem vinculo no pessoas2" do
    Pessoas::Vinculo.define_singleton_method(:frequentadores_ativos) { |**_kwargs| Kaminari.paginate_array([]).page(1) }
    sem_cpf = User.create!(nome_completo: "Admin Sem Vinculo", password: "123456")

    get users_path

    assert_response :success
    assert_select "td", text: "Admin Sem Vinculo"
    assert_select "code", text: sem_cpf.username
  ensure
    Pessoas::Vinculo.singleton_class.remove_method(:frequentadores_ativos)
  end

  test "deve mostrar formulario de novo usuario" do
    get new_user_path
    assert_response :success
    assert_select ".app-content-header h1", "Novo Usuário"
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

  test "edit exibe campos desabilitados para frequentador vinculado ao Pessoas (com cpf)" do
    user = User.create!(nome_completo: "Vindo Do Pessoas", password: "123456", cpf: "11122233344")

    get edit_user_path(user)

    assert_response :success
    assert_select "input[name='user[nome_completo]'][disabled]"
    assert_select "input[type='submit']", count: 0
  end

  test "edit nao desabilita campos para usuario sem cpf (cadastro manual)" do
    user = User.create!(nome_completo: "Manual", password: "123456")

    get edit_user_path(user)

    assert_response :success
    assert_select "input[name='user[nome_completo]']:not([disabled])"
    assert_select "input[type='submit']"
  end

  test "update bloqueia edicao de frequentador vinculado ao Pessoas mesmo via POST direto" do
    user = User.create!(nome_completo: "Vindo Do Pessoas", password: "123456", cpf: "11122233344")

    patch user_path(user), params: { user: { nome_completo: "Tentativa De Alterar" } }

    assert_redirected_to users_path
    assert_equal "Vindo Do Pessoas", user.reload.nome_completo
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
