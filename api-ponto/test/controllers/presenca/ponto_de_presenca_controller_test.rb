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

    test "GET show extends application layout" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, "Estação Ponto"
      assert_includes @response.body, 'class="main-header'
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
    end

    test "GET show contains digital clock" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, 'id="clockDigital"'
    end

    test "GET show displays no records message when there are no punches today" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, "Nenhum registro hoje"
      assert_includes @response.body, "Status: Fora"
      assert_includes @response.body, "Fora ⚪"
    end

    test "GET show displays a single punch record" do
      punched_at = Time.zone.now.beginning_of_day + 8.hours + 1.minute
      TimeRecord.create!(
        user: @user,
        raw_data: "1-#{punched_at.strftime('%d:%m:%Y:%H:%M:%S')}",
        punched_at: punched_at,
        authentication_mode: "biometric",
        punch_type: "entry"
      )

      get "/presenca/PontoDePresenca"
      assert_includes @response.body, "Entrada ✅"
      assert_includes @response.body, "08:01"
      assert_includes @response.body, "Status: Dentro"
      assert_includes @response.body, "Dentro 🟢"
      assert_includes @response.body, "Demo User (demo.user)"
    end

    test "GET show displays multiple punches ordered chronologically with alternating entry/exit" do
      base = Time.zone.now.beginning_of_day
      entry1 = TimeRecord.create!(
        user: @user,
        raw_data: "1-#{(base + 8.hours + 1.minute).strftime('%d:%m:%Y:%H:%M:%S')}",
        punched_at: base + 8.hours + 1.minute,
        authentication_mode: "biometric",
        punch_type: "entry"
      )
      exit1 = TimeRecord.create!(
        user: @user,
        raw_data: "1-#{(base + 12.hours).strftime('%d:%m:%Y:%H:%M:%S')}",
        punched_at: base + 12.hours,
        authentication_mode: "biometric",
        punch_type: "exit"
      )
      entry2 = TimeRecord.create!(
        user: @user,
        raw_data: "1-#{(base + 13.hours).strftime('%d:%m:%Y:%H:%M:%S')}",
        punched_at: base + 13.hours,
        authentication_mode: "biometric",
        punch_type: "entry"
      )

      get "/presenca/PontoDePresenca"

      assert_response :ok
      body = @response.body
      table_body = body[/<tbody id="batidasTableBody">.*?<\/tbody>/m]
      assert_equal 2, table_body.scan("Entrada ✅").size
      assert_equal 1, table_body.scan("Saída ⬆️").size

      pos_entry1 = body.index(entry1.punched_at.strftime("%H:%M"))
      pos_exit1 = body.index(exit1.punched_at.strftime("%H:%M"))
      pos_entry2 = body.index(entry2.punched_at.strftime("%H:%M"))
      assert pos_entry1 < pos_exit1
      assert pos_exit1 < pos_entry2

      # Última batida do dia é "entry" -> status Dentro
      assert_includes body, "Status: Dentro"
    end

    test "GET show handles punch_type nil gracefully (pre-A.3 integration scenario)" do
      punched_at = Time.zone.now.beginning_of_day + 9.hours
      TimeRecord.create!(
        user: @user,
        raw_data: "1-#{punched_at.strftime('%d:%m:%Y:%H:%M:%S')}",
        punched_at: punched_at,
        authentication_mode: "biometric",
        punch_type: nil
      )

      get "/presenca/PontoDePresenca"
      assert_response :ok
      assert_includes @response.body, "09:00"
      assert_includes @response.body, '<span class="badge-punch none">—</span>'
      # Sem punch_type reconhecido como "entry", o status permanece "Fora"
      assert_includes @response.body, "Status: Fora"
    end

    test "GET show contains login manual button" do
      get "/presenca/PontoDePresenca"
      assert_includes @response.body, 'id="btnLoginManual"'
      assert_includes @response.body, 'Login Manual'
      assert_includes @response.body, 'fas fa-user'
    end
  end
end
