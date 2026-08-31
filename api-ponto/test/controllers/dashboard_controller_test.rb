require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(nome_completo: "Admin Teste", password: "123456", admin: true)
    post login_path, params: { username: @user.username, password: "123456" }
  end

  test "deve carregar dashboard" do
    get dashboard_path
    assert_response :success
    assert_select ".app-content-header h1", "Dashboard"
  end

  test "deve redirecionar para login se nao autenticado" do
    delete logout_path
    get dashboard_path
    assert_redirected_to login_path
  end

  # Sprint 15 (task 15.1/15.3): KPIs simples de "Fase A" — contagem direta
  # de frequentadores, estações e batidas do dia, sem nenhum cálculo de
  # banco de horas/frequência (isso é Fase B, task 15.2 garante que nenhum
  # KPI dependa disso).
  test "deve exibir contagem real de frequentadores, estacoes e batidas do dia" do
    TimeRecord.delete_all
    FrequentadorCache.delete_all
    EstacaoPonto.delete_all

    FrequentadorCache.create!(cpf: "11111111111", nome: "Frequentador Um", orgao: "Órgão A")
    FrequentadorCache.create!(cpf: "22222222222", nome: "Frequentador Dois", orgao: "Órgão B")

    EstacaoPonto.create!(descricao: "Estação Recepção", cod_ativacao: "estacao-recepcao")

    outro_usuario = User.create!(nome_completo: "Servidor Teste", password: "123456")
    TimeRecord.create!(
      user: outro_usuario,
      raw_data: "{}",
      punched_at: Time.current,
      authentication_mode: "manual",
      punch_type: "entry"
    )

    get dashboard_path
    assert_response :success
    assert_match(%r{<h3>\s*2\s*</h3>\s*<p>Frequentadores</p>}m, response.body)
    assert_match(%r{<h3>\s*1\s*</h3>\s*<p>Estações de Ponto</p>}m, response.body)
    assert_match(%r{<h3>\s*1\s*</h3>\s*<p>Batidas Hoje</p>}m, response.body)
  end

  test "deve carregar dashboard sem erro com base vazia" do
    TimeRecord.delete_all
    FrequentadorCache.delete_all
    EstacaoPonto.delete_all

    get dashboard_path

    assert_response :success
    assert_select ".app-content-header h1", "Dashboard"
    assert_match(%r{<h3>\s*0\s*</h3>\s*<p>Frequentadores</p>}m, response.body)
    assert_match(%r{<h3>\s*0\s*</h3>\s*<p>Estações de Ponto</p>}m, response.body)
    assert_match(%r{<h3>\s*0\s*</h3>\s*<p>Batidas Hoje</p>}m, response.body)
  end
end
