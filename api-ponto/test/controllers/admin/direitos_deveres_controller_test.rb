require "test_helper"

module Admin
  class DireitosDeveresControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @user = User.create!(nome_completo: "Admin Teste", password: "123456", admin: true)
      post login_path, params: { username: @user.username, password: "123456" }
    end

    test "deve listar a tela" do
      get direitos_deveres_path
      assert_response :success
    end

    test "deve exibir afastamentos cadastrados com nome do frequentador" do
      FrequentadorCache.create!(cpf: "11122233344", nome: "Fulano de Tal")
      AfastamentoCache.create!(afastamento_id_pessoas: 1, cpf: "11122233344", tipo: "Férias", momento_inicial: 5.days.ago, momento_final: 1.day.ago)

      get direitos_deveres_path

      assert_response :success
      assert_select "td", text: "Férias"
      assert_select "td", text: "Fulano de Tal"
    end

    test "deve funcionar com base vazia" do
      get direitos_deveres_path

      assert_response :success
      assert_select "td", text: "Nenhum registro cadastrado"
    end

    test "afastamento sem frequentador_cache correspondente nao quebra a tela" do
      AfastamentoCache.create!(afastamento_id_pessoas: 1, cpf: "99988877766", tipo: "Férias")

      get direitos_deveres_path

      assert_response :success
    end

    test "filtra por tipo" do
      AfastamentoCache.create!(afastamento_id_pessoas: 1, cpf: "11122233344", tipo: "Férias")
      AfastamentoCache.create!(afastamento_id_pessoas: 2, cpf: "11122233344", tipo: "Licença")

      get direitos_deveres_path, params: { tipo: "Férias" }

      assert_response :success
      assert_select "td", text: "Férias"
      assert_select "td", text: "Licença", count: 0
    end

    test "deve redirecionar para login se nao autenticado" do
      delete logout_path
      get direitos_deveres_path
      assert_redirected_to login_path
    end

    test "sincronizar_agora enfileira SincronizarAfastamentosJob sem argumento (todos os frequentadores)" do
      assert_enqueued_with(job: SincronizarAfastamentosJob, args: []) do
        post sincronizar_agora_direitos_deveres_path
      end

      assert_redirected_to direitos_deveres_path
    end

    test "sincronizar_agora exige autenticacao" do
      delete logout_path

      post sincronizar_agora_direitos_deveres_path

      assert_redirected_to login_path
    end
  end
end
