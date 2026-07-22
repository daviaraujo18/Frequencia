require "test_helper"

class PresencaEndpointsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      nome_completo: "Teste Integração",
      password: "123456"
    )
    @username_enc = CryptoDes.encrypt(@user.username)
    @password_enc = CryptoDes.encrypt("123456")
  end

  test "GET CarregaRelogioAtual returns timestamp in milliseconds" do
    get presenca_CarregaRelogioAtual_url
    assert_response :success
    assert_match(/\A\d+\z/, @response.body)
    assert @response.body.to_i > 1_700_000_000_000
  end

  test "GET ValidarFrequentador returns user ID for valid credentials" do
    get presenca_ValidarFrequentador_url(
      loginAccessKey: @username_enc,
      plainPassword: @password_enc,
      codAtivacao: "poc-ativacao-001"
    )
    assert_response :success
    assert_equal @user.id.to_s, @response.body
  end

  test "GET ValidarFrequentador returns error for wrong password" do
    get presenca_ValidarFrequentador_url(
      loginAccessKey: @username_enc,
      plainPassword: CryptoDes.encrypt("wrong_password"),
      codAtivacao: "poc-ativacao-001"
    )
    assert_response :success
    assert_equal "USUARIO_SENHA_INVALIDOS", @response.body
  end

  test "GET ValidarFrequentador returns error for wrong activation code" do
    get presenca_ValidarFrequentador_url(
      loginAccessKey: @username_enc,
      plainPassword: @password_enc,
      codAtivacao: "wrong-code"
    )
    assert_response :success
    assert_equal "USUARIO_SENHA_INVALIDOS", @response.body
  end

  test "GET ValidarFrequentador returns error for inactive user" do
    @user.update!(status: 0)
    get presenca_ValidarFrequentador_url(
      loginAccessKey: @username_enc,
      plainPassword: @password_enc,
      codAtivacao: "poc-ativacao-001"
    )
    assert_response :success
    assert_equal "USUARIO_SENHA_INVALIDOS", @response.body
  end

  test "GET ValidarFrequentador returns error for invalid DES data" do
    get presenca_ValidarFrequentador_url(
      loginAccessKey: "invalid-des-data",
      plainPassword: @password_enc,
      codAtivacao: "poc-ativacao-001"
    )
    assert_response :success
    assert_equal "USUARIO_SENHA_INVALIDOS", @response.body
  end

  test "GET InicializarPonto returns redirect HTML" do
    get presenca_InicializarPonto_url(
      codigoAtivacao: "poc-ativacao-001",
      codigoUnicoMaquina: "test-machine"
    )
    assert_response :success
    assert_includes @response.body, "PontoDePresenca"
  end

  test "GET InicializarPonto returns error HTML when codigoAtivacao is missing" do
    get presenca_InicializarPonto_url
    assert_response :success
    assert_includes @response.body, "Erro de Ativação"
    assert_includes @response.body, "Código de ativação não informado"
  end

  test "GET DynHashFrequentadoresEstacao returns 32-char uppercase MD5" do
    get presenca_DynHashFrequentadoresEstacao_url
    assert_response :success
    assert_match(/\A[A-F0-9]{32}\z/, @response.body)
  end

  test "GET DynFrequentadoresEstacao returns serialized data with correct format" do
    User.create!(nome_completo: "Digital Test", password: "123456", digitais_hash: "HASH123")
    get presenca_DynFrequentadoresEstacao_url
    assert_response :success
    parts = @response.body.split(";")
    assert_equal 8, parts.size
    assert_equal "false", parts[5]
    assert_equal "N", parts[6]
    assert_equal "0", parts[7]
  end

  test "GET DynFrequentadoresEstacao excludes users without digitais_hash" do
    get presenca_DynFrequentadoresEstacao_url
    refute_includes @response.body, "usuario.teste"
  end

  test "GET DynFrequentadoresEstacao excludes inactive users" do
    User.create!(nome_completo: "Inativo Digital", password: "123456", digitais_hash: "HASH", status: 0)
    get presenca_DynFrequentadoresEstacao_url
    refute_includes @response.body, "inativo.digital"
  end

  test "POST SincronizarRegistrosPonto saves records and returns sincronizado" do
    registros = "#{@user.id}-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    assert_response :success
    assert_equal "sincronizado", @response.body
    assert_equal 1, TimeRecord.where(raw_data: registros).count
  end

  test "POST SincronizarRegistrosPonto handles multiple records" do
    registros = "#{@user.id}-15:07:2026:14:30:45\n#{@user.id}-15:07:2026:14:31:00"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    assert_response :success
    assert_equal 2, TimeRecord.count
  end

  test "POST SincronizarRegistrosPonto ignores records for non-existent users" do
    registros = "99999-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    assert_response :success
    assert_equal "sincronizado", @response.body
    assert_equal 0, TimeRecord.count
  end

  test "POST SincronizarRegistrosPonto accepts any codAtivacao (PoC)" do
    registros = "1-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "invalid" }
    assert_response :success
    assert_equal "sincronizado", @response.body
  end

  test "POST SincronizarRegistrosPonto handles invalid DES data gracefully" do
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: "invalid-data", codAtivacao: "poc-ativacao-001" }
    assert_response :success
    assert_equal "sincronizado", @response.body
  end

  # --- Testes de PunchTypeService integration (Task A.3) ---

  test "POST SincronizarRegistrosPonto assigns punch_type alternating entry/exit" do
    now = Time.zone.now
    # 3 records processed in order: earliest first, then middle, then latest
    line1 = "#{@user.id}-#{(now - 2.hours).strftime("%d:%m:%Y:%H:%M:%S")}"
    line2 = "#{@user.id}-#{(now - 1.hour).strftime("%d:%m:%Y:%H:%M:%S")}"
    line3 = "#{@user.id}-#{now.strftime("%d:%m:%Y:%H:%M:%S")}"
    registros = [line1, line2, line3].join("\n")

    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    assert_response :success

    records = TimeRecord.where(user: @user).order(:punched_at)
    assert_equal 3, records.size
    assert_equal "entry", records[0].punch_type
    assert_equal "exit",  records[1].punch_type
    assert_equal "entry", records[2].punch_type
  end

  test "POST SincronizarRegistrosPonto assigns entry when user has no prior records today" do
    registros = "#{@user.id}-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    assert_response :success

    record = TimeRecord.last
    assert_equal "entry", record.punch_type
  end

  # --- Testes de Navbar e Sidebar (Task A.8) ---

  test "GET PontoDePresenca includes sidebar state persistence JS" do
    get presenca_PontoDePresenca_url
    assert_response :success
    assert_includes @response.body, "localStorage.getItem('sidebar-collapsed')"
    assert_includes @response.body, "localStorage.setItem('sidebar-collapsed'"
  end

  test "GET PontoDePresenca includes bridge function atualizaRelogioLocal" do
    get presenca_PontoDePresenca_url
    assert_response :success
    assert_includes @response.body, "function atualizaRelogioLocal"
  end

  test "GET PontoDePresenca includes bridge function atualizaStatusConexao" do
    get presenca_PontoDePresenca_url
    assert_response :success
    assert_includes @response.body, "function atualizaStatusConexao"
  end

  test "GET PontoDePresenca includes TJPI logo in navbar" do
    get presenca_PontoDePresenca_url
    assert_response :success
    assert_includes @response.body, "TJPI"
  end

  test "GET PontoDePresenca includes version in sidebar footer" do
    get presenca_PontoDePresenca_url
    assert_response :success
    assert_includes @response.body, "v1.0.0"
  end

  test "GET PontoDePresenca includes connection status indicator" do
    get presenca_PontoDePresenca_url
    assert_response :success
    assert_includes @response.body, "status-conexao"
    assert_includes @response.body, "text-success"
  end

  test "GET PontoDePresenca highlights active menu item" do
    get presenca_PontoDePresenca_url
    assert_response :success
    # O JS de highlight está presente
    assert_includes @response.body, "classList.add('active')"
  end

  test "GET PontoDePresenca includes layout-fixed class" do
    get presenca_PontoDePresenca_url
    assert_response :success
    assert_includes @response.body, "layout-fixed"
  end

  test "GET PontoDePresenca includes Inicio link in sidebar" do
    get presenca_PontoDePresenca_url
    assert_response :success
    assert_includes @response.body, "Início"
  end

  test "GET IniciarPonto includes sidebar and navbar components" do
    get presenca_IniciarPonto_url(codigoAtivacao: "test")
    assert_response :success
    assert_includes @response.body, "sidebar-collapsed"
    assert_includes @response.body, "function atualizaRelogioLocal"
  end

  test "GET InicializarPonto includes sidebar and navbar components" do
    get presenca_InicializarPonto_url(codigoAtivacao: "test", codigoUnicoMaquina: "test")
    assert_response :success
    assert_includes @response.body, "sidebar-collapsed"
    assert_includes @response.body, "status-conexao"
  end

  test "POST SincronizarRegistrosPonto nil punch_type does not break sync when service fails" do
    # Simula falha do service substituindo o método temporariamente
    original = PunchTypeService.method(:determine)
    begin
      PunchTypeService.define_singleton_method(:determine) { |*| raise "Falha simulada" }

      registros = "#{@user.id}-15:07:2026:14:30:45"
      enc = CryptoDes.encrypt(registros)
      post presenca_ajax_SincronizarRegistrosPonto_url,
        params: { registros: enc, codAtivacao: "poc-ativacao-001" }
      assert_response :success
      assert_equal "sincronizado", @response.body

      record = TimeRecord.last
      assert_nil record.punch_type
    ensure
      PunchTypeService.define_singleton_method(:determine, &original)
    end
  end
end
