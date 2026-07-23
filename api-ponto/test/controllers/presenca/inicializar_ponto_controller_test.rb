require "test_helper"

module Presenca
  class InicializarPontoControllerTest < ActionDispatch::IntegrationTest
    test "GET show renders HTML and includes hidden fields" do
      get "/presenca/InicializarPonto", params: {
        codigoAtivacao: "poc-ativacao-001",
        codigoUnicoMaquina: "ABC123"
      }

      assert_response :ok
      assert_includes @response.body, "Inicializando..."
      assert_includes @response.body, 'id="codigoAtivacao"'
      assert_includes @response.body, 'value="poc-ativacao-001"'
      assert_includes @response.body, 'id="codigoUnicoMaquina"'
      assert_includes @response.body, 'value="ABC123"'
    end

    test "GET show with valid codigoAtivacao displays spinner and does not render error" do
      get "/presenca/InicializarPonto", params: {
        codigoAtivacao: "poc-ativacao-001",
        codigoUnicoMaquina: "ABC123"
      }

      assert_response :ok
      assert_includes @response.body, "spinner"
      assert_not_includes @response.body, "Erro de Ativação"
    end

    test "GET show without codigoAtivacao renders error message" do
      get "/presenca/InicializarPonto"

      assert_response :ok
      assert_includes @response.body, "Erro de Ativação"
      assert_includes @response.body, "Código de ativação não informado"
    end

    test "GET show without codigoAtivacao does not trigger alert nor redirect" do
      get "/presenca/InicializarPonto"

      assert_response :ok
      assert_not_includes @response.body, "alert('recuperarFrequentadores')"
      assert_not_includes @response.body, "window.location.href = '/presenca/PontoDePresenca'"
    end

    test "GET show without codigoAtivacao renders empty hidden field" do
      get "/presenca/InicializarPonto"

      assert_response :ok
      assert_includes @response.body, 'id="codigoAtivacao"'
      assert_includes @response.body, 'id="codigoAtivacao" value=""'
    end

    test "GET show triggers recuperarFrequentadores alert" do
      get "/presenca/InicializarPonto", params: { codigoAtivacao: "poc-ativacao-001" }

      assert_response :ok
      assert_includes @response.body, "alert('recuperarFrequentadores')"
    end

    test "GET show redirects to PontoDePresenca" do
      get "/presenca/InicializarPonto", params: { codigoAtivacao: "poc-ativacao-001" }

      assert_response :ok
      assert_includes @response.body, "window.location.href = '/presenca/PontoDePresenca'"
    end
  end
end
