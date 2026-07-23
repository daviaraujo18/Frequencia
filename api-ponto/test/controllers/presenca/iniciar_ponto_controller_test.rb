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

    test "GET show displays no records message and dash badge when no last record" do
      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_includes @response.body, "Nenhum registro hoje"
      assert_includes @response.body, '<div class="status-badge none" id="statusBadge">'
    end

    test "GET show displays last record status with frequentador name and formatted horario when record exists" do
      # Controller hardcodes user_id=1 for demo — create matching user
      user = User.new(
        id: 1,
        nome_completo: "Demo User",
        username: "demo.user",
        password: "123456"
      )
      user.save!(validate: false)

      punched_at = Time.zone.now

      TimeRecord.create!(
        user: user,
        raw_data: "#{user.id}-#{punched_at.strftime("%d:%m:%Y:%H:%M:%S")}",
        punched_at: punched_at,
        authentication_mode: "biometric",
        punch_type: "entry"
      )

      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_includes @response.body, "Entrada ✅"
      assert_includes @response.body, "Demo User (demo.user)"
      assert_includes @response.body, punched_at.strftime("%d/%m/%Y %H:%M")
    end

    test "GET show displays laranja badge for exit punch type" do
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
        punch_type: "exit"
      )

      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_includes @response.body, "Saída ⬆️"
      assert_includes @response.body, '<div class="status-badge exit" id="statusBadge">'
    end

    test "GET show displays error message when status lookup fails" do
      TimeRecord.singleton_class.send(:alias_method, :original_last_today, :last_today)
      TimeRecord.define_singleton_method(:last_today) { |_user_id| raise StandardError, "boom" }

      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }

      assert_response :ok
      assert_includes @response.body, "Não foi possível carregar o status da última batida."
    ensure
      TimeRecord.singleton_class.send(:alias_method, :last_today, :original_last_today)
    end

    test "GET show contains no duplicate hidden bridge field ids" do
      get "/presenca/IniciarPonto", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_equal 1, @response.body.scan('id="codigoAtivacao"').size
      assert_equal 1, @response.body.scan('id="codigoUnicoMaquina"').size
      assert_equal 1, @response.body.scan('id="digitaisHash"').size
    end
  end
end
