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

  # --- Content negotiation (Sprint R, ajuste pós-R.6) ---

  test "POST SincronizarRegistrosPonto returns plain text 'sincronizado' by default (legacy client compatibility)" do
    registros = "#{@user.id}-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    assert_response :success
    assert_equal "sincronizado", @response.body
    assert_equal 1, TimeRecord.where(raw_data: registros).count
  end

  test "POST SincronizarRegistrosPonto returns plain text 'sincronizado' with 200 even when a record is rejected, without opt-in" do
    registros = "99999-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    assert_response :success
    assert_equal "sincronizado", @response.body
    assert_equal 0, TimeRecord.count
  end

  test "POST SincronizarRegistrosPonto returns rich JSON when Accept header is application/json" do
    registros = "#{@user.id}-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" },
      headers: { "Accept" => "application/json" }
    assert_response :success

    body = JSON.parse(@response.body)
    assert_equal "sincronizado", body["status"]
    assert_equal 1, body["registros_aceitos"].size
  end

  test "POST SincronizarRegistrosPonto saves records and returns nome/foto/horario for confirmacao visual" do
    registros = "#{@user.id}-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001", confirmacaoVisual: "1" }
    assert_response :success
    assert_equal 1, TimeRecord.where(raw_data: registros).count

    body = JSON.parse(@response.body)
    assert_equal "sincronizado", body["status"]
    assert_equal 1, body["registros_aceitos"].size
    assert_equal 0, body["registros_rejeitados"].size

    aceito = body["registros_aceitos"].first
    assert_equal @user.id, aceito["user_id"]
    assert_equal @user.nome_completo, aceito["nome"]
    assert_equal "15/07/2026 11:30:45", aceito["horario"]
    assert_equal false, aceito["foto"]["disponivel"]
  end

  test "POST SincronizarRegistrosPonto handles multiple records" do
    registros = "#{@user.id}-15:07:2026:14:30:45\n#{@user.id}-15:07:2026:14:31:00"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001", confirmacaoVisual: "1" }
    assert_response :success
    assert_equal 2, TimeRecord.count

    body = JSON.parse(@response.body)
    assert_equal 2, body["registros_aceitos"].size
  end

  test "POST SincronizarRegistrosPonto rejects records for non-existent users with clear error and 422" do
    registros = "99999-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001", confirmacaoVisual: "1" }
    assert_response :unprocessable_entity
    assert_equal 0, TimeRecord.count

    body = JSON.parse(@response.body)
    assert_equal "sincronizado", body["status"]
    assert_equal 0, body["registros_aceitos"].size
    assert_equal 1, body["registros_rejeitados"].size
    assert_match(/Usuário não encontrado/, body["registros_rejeitados"].first["erro"])
  end

  test "POST SincronizarRegistrosPonto marks foto as unavailable when user has no photo cadastrada (schema has no foto column)" do
    registros = "#{@user.id}-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001", confirmacaoVisual: "1" }
    assert_response :success

    body = JSON.parse(@response.body)
    foto = body["registros_aceitos"].first["foto"]
    assert_equal false, foto["disponivel"]
    assert_nil foto["url"]
    assert_match(/não cadastrada/, foto["motivo"])
  end

  test "POST SincronizarRegistrosPonto accepts any codAtivacao (PoC)" do
    registros = "1-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "invalid" }
    assert_response :success
    assert_equal "sincronizado", @response.body
  end

  test "POST SincronizarRegistrosPonto handles invalid DES data gracefully (default plain text)" do
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: "invalid-data", codAtivacao: "poc-ativacao-001" }
    # Dado não descriptografável não casa com o formato de linha esperado,
    # cai como registro rejeitado (formato inválido); sem opt-in, o client
    # legado continua recebendo texto puro "sincronizado" com 200.
    assert_response :success
    assert_equal "sincronizado", @response.body
  end

  test "POST SincronizarRegistrosPonto handles invalid DES data gracefully (rich JSON opt-in)" do
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: "invalid-data", codAtivacao: "poc-ativacao-001", confirmacaoVisual: "1" }
    assert_response :unprocessable_entity
    body = JSON.parse(@response.body)
    assert_equal "sincronizado", body["status"]
    assert_equal 1, body["registros_rejeitados"].size
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

  # --- Testes de campo explícito `punch_type` no payload (Task R.4) ---

  test "POST SincronizarRegistrosPonto respects explicit valid punch_type and does not call PunchTypeService" do
    # Sem registro anterior hoje, o fallback do PunchTypeService daria "entry";
    # o valor explícito "exit" deve prevalecer, provando que é a fonte de verdade.
    registros = "#{@user.id}-15:07:2026:14:30:45-exit"
    enc = CryptoDes.encrypt(registros)

    # Stub manual: se PunchTypeService.determine for chamado, a asserção falha
    # explicitamente, provando que o caminho explícito não o invoca.
    original_determine = PunchTypeService.method(:determine)
    PunchTypeService.define_singleton_method(:determine) do |*args|
      flunk "PunchTypeService.determine não deveria ser chamado quando punch_type é explícito e válido"
    end

    begin
      post presenca_ajax_SincronizarRegistrosPonto_url,
        params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    ensure
      PunchTypeService.define_singleton_method(:determine, original_determine)
    end

    assert_response :success

    record = TimeRecord.last
    assert_equal "exit", record.punch_type
    assert_equal true, record.punch_type_explicit
  end

  test "POST SincronizarRegistrosPonto falls back to PunchTypeService when punch_type is absent" do
    registros = "#{@user.id}-15:07:2026:14:30:45"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001" }
    assert_response :success

    record = TimeRecord.last
    assert_equal "entry", record.punch_type
    assert_equal false, record.punch_type_explicit
  end

  test "POST SincronizarRegistrosPonto treats invalid punch_type value as absent (fallback, no 500)" do
    registros = "#{@user.id}-15:07:2026:14:30:45-foo"
    enc = CryptoDes.encrypt(registros)
    post presenca_ajax_SincronizarRegistrosPonto_url,
      params: { registros: enc, codAtivacao: "poc-ativacao-001", confirmacaoVisual: "1" }
    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "sincronizado", body["status"]
    assert_equal 1, body["registros_aceitos"].size

    record = TimeRecord.last
    assert_equal "entry", record.punch_type
    assert_equal false, record.punch_type_explicit
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
        params: { registros: enc, codAtivacao: "poc-ativacao-001", confirmacaoVisual: "1" }
      assert_response :success
      body = JSON.parse(@response.body)
      assert_equal "sincronizado", body["status"]
      assert_equal 1, body["registros_aceitos"].size

      record = TimeRecord.last
      assert_nil record.punch_type
    ensure
      PunchTypeService.define_singleton_method(:determine, &original)
    end
  end
end
