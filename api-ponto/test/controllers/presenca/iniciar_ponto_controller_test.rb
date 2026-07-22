require "test_helper"

module Presenca
  class IniciarPontoControllerTest < ActionDispatch::IntegrationTest
    test "GET show returns 200" do
      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_response :ok
    end

    test "GET show renders landing page content" do
      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_includes @response.body, "codigoAtivacao"
      assert_includes @response.body, "downloadFrequentadores"
    end

    test "GET show contains hidden codigoAtivacao field" do
      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_includes @response.body, 'id="codigoAtivacao"'
      assert_includes @response.body, 'value="poc-ativacao-001"'
    end

    test "GET show contains bridge functions" do
      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_includes @response.body, "function sincronizaPonto"
      assert_includes @response.body, "function aguardarDigital"
      assert_includes @response.body, "function process"
      assert_includes @response.body, "function atualizaRelogioLocal"
      assert_includes @response.body, "function changeInfoDigital"
      assert_includes @response.body, "function lock"
      assert_includes @response.body, "function unlock"
    end

    test "GET show displays no records message when no last record" do
      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_includes @response.body, "Nenhum registro hoje"
    end

    test "GET show displays last record status when record exists" do
      # Controller hardcodes user_id=1 for demo — create matching user
      user = User.new(
        id: 1,
        nome_completo: "Demo User",
        username: "demo.user",
        password: "123456"
      )
      user.save!(validate: false)

      TimeRecord.create!(
        user: user,
        raw_data: "#{user.id}-#{Time.zone.now.strftime("%d:%m:%Y:%H:%M:%S")}",
        punched_at: Time.zone.now,
        authentication_mode: "biometric",
        punch_type: "entry"
      )

      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_includes @response.body, "Entrada"
    end
  end
end
