require "test_helper"

module Presenca
  class PontoDePresencaControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.new(
        id: 1,
        nome_completo: "Demo User",
        username: "demo.user",
        password: "123456"
      )
      @user.save!(validate: false)
    end

    test "GET show returns 200" do
      get "/presenca/PontoDePresenca"
      assert_response :ok
    end

    test "GET show uses kiosk layout (visual da Estação real, sem AdminLTE)" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, "Estação Ponto"
      assert_includes @response.body, "598 - STIC- COORDENAÇÃO DE SOFT"
      refute_includes @response.body, 'class="main-header'
      # O cabeçalho "ESTAÇÃO PONTO DE PRESENÇA / TRIBUNAL DE JUSTIÇA DO PIAUÍ"
      # é renderizado nativamente pelo JavaFX (imagem topo.png, fora do
      # WebView) — não deve ser duplicado no HTML desta página.
      refute_includes @response.body, "ESTAÇÃO PONTO DE PRESENÇA"
    end

    test "GET show contains hidden bridge fields without duplicate ids" do
      get "/presenca/PontoDePresenca", params: { codigoAtivacao: "poc-ativacao-001" }
      assert_equal 1, @response.body.scan('id="codigoAtivacao"').size
      assert_equal 1, @response.body.scan('id="codigoUnicoMaquina"').size
      assert_equal 1, @response.body.scan('id="digitaisHash"').size
      assert_includes @response.body, 'value="poc-ativacao-001"'
    end

    test "GET show contains bridge functions" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, "function sincronizaPonto"
      assert_includes @response.body, "function process"
      assert_includes @response.body, "function atualizaRelogioLocal"
      assert_includes @response.body, "function aguardarDigital"
      assert_includes @response.body, "function removeLoading"
      assert_includes @response.body, "window.changeMensagemStatus"
    end

    test "GET show contains digital clock" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, 'id="clockDigital"'
    end

    test "GET show contains waiting message" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, "Coloque a digital no leitor."
    end

    test "GET show contains login manual form always visible (no toggle button)" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, 'id="loginManualForm"'
      assert_includes @response.body, 'name="accessKey"'
      assert_includes @response.body, 'name="plainPassword"'
      assert_includes @response.body, 'Registrar'
      refute_includes @response.body, 'id="btnLoginManual"'
    end

    test "GET show submit handler is inline onsubmit, not jQuery" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, 'onsubmit="registrarPontoManual(); return false;"'
      refute_includes @response.body, "jQuery("
    end

    test "GET show does not crash when there are punches today (data still loaded, just not rendered in this layout)" do
      punched_at = Time.zone.now.beginning_of_day + 8.hours + 1.minute
      TimeRecord.create!(
        user: @user,
        raw_data: "1-#{punched_at.strftime('%d:%m:%Y:%H:%M:%S')}",
        punched_at: punched_at,
        authentication_mode: "biometric",
        punch_type: "entry"
      )

      get "/presenca/PontoDePresenca"
      assert_response :ok
    end
  end
end
