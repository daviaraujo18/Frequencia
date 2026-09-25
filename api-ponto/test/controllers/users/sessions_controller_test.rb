require "test_helper"

# Task 23.6 — Fluxo Devise (Users::SessionsController).
#
# Cobrem as rotas Devise (/u/sign_in, /u/sign_out) e garantem que:
# - login é por `username` (não email)
# - usuário com `cpf` autentica contra o hash bcrypt do Pessoas2
# - usuário sem `cpf` autentica contra a senha local
# - usuário inativo (status != 1) é bloqueado
# - após login via Devise, `session[:user_id]` fica setado para que o
#   contexto admin (Admin::ApplicationController) reconheça o usuário
class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(nome_completo: "Devise Admin", password: "123456")
  end

  test "deve logar via rota devise (POST /u/sign_in) com username e definir session" do
    post user_session_path, params: { user: { username: @user.username, password: "123456" } }

    assert_redirected_to dashboard_path
    assert_equal @user.id, session[:user_id], "session[:user_id] precisa estar setado para o contexto admin"
    follow_redirect!
    assert_response :success
  end

  test "deve logar via rota devise usando username (nao email)" do
    # Usuário não tem `email` — se o Devise usasse email como auth key,
    # este login falharia. Garante que `authentication_keys = [:username]`
    # está em vigor.
    assert_nil @user.email
    assert_nil @user.cpf

    post user_session_path, params: { user: { username: @user.username, password: "123456" } }

    assert_redirected_to dashboard_path
  end

  test "GET /u/sign_in renderiza a view users/sessions/new (form devise + remember_me)" do
    get new_user_session_path

    assert_response :success
    # Form do Devise (submete para /u/sign_in), não o form_tag do legado
    # (/login) — prova que a 23.8 está servindo a view dedicada.
    assert_select "form[action='/u/sign_in']"
    assert_select "input[name='user[username]']"
    assert_select "input[name='user[password]']"
    # Débito 23.6 resolvido: checkbox de rememberable exposto no form novo.
    assert_select "input[type='checkbox'][name='user[remember_me]']"
    # Link de recuperação de senha (recoverable — view users/passwords/new).
    assert_select "a[href='/u/password/new']", text: "Esqueceu sua senha?"
  end

  test "deve logar via rota devise usuario vindo do pessoas2 (cpf) com a senha real" do
    user_pessoas = User.create!(nome_completo: "Devise Pessoas", password: "senha-local-irrelevante", cpf: "11122233344")
    hash = BCrypt::Password.create("senha-real")
    pessoas_user = Struct.new(:encrypted_password).new(hash)

    original = Pessoas::User.method(:buscar_por_cpf)
    Pessoas::User.define_singleton_method(:buscar_por_cpf) { |*_args, **_kwargs| pessoas_user }
    begin
      post user_session_path, params: { user: { username: user_pessoas.username, password: "senha-real" } }
      assert_redirected_to dashboard_path
      assert_equal user_pessoas.id, session[:user_id]
    ensure
      Pessoas::User.define_singleton_method(:buscar_por_cpf, original)
    end
  end

  test "deve rejeitar via rota devise usuario com cpf e senha errada (Pessoas2)" do
    user_pessoas = User.create!(nome_completo: "Devise Pessoas Errado", password: "senha-local-irrelevante", cpf: "11122233344")
    hash = BCrypt::Password.create("senha-real")
    pessoas_user = Struct.new(:encrypted_password).new(hash)

    original = Pessoas::User.method(:buscar_por_cpf)
    Pessoas::User.define_singleton_method(:buscar_por_cpf) { |*_args, **_kwargs| pessoas_user }
    begin
      post user_session_path, params: { user: { username: user_pessoas.username, password: "senha-errada" } }
      # Falha: Warden recall → re-render da view NOVA de login
      # (users/sessions/new — task 23.8) com flash.now de alert, status
      # configurado via responder.error_status. O form action /u/sign_in
      # prova que o recall usa a view Devise, não a admin/sessions/new.
      assert_response :unprocessable_content
      assert_select ".alert-danger", "Username ou senha inválidos."
      assert_select "form[action='/u/sign_in']"
    ensure
      Pessoas::User.define_singleton_method(:buscar_por_cpf, original)
    end
  end

  test "deve bloquear usuario inativo (status != 1) via rota devise" do
    inativo = User.create!(nome_completo: "Devise Inativo", password: "123456", status: 0)

    post user_session_path, params: { user: { username: inativo.username, password: "123456" } }

    # active_for_authentication? == false → Warden `after_set_user` hook
    # descarta + failure app redireciona para /u/sign_in com alert de inativo.
    assert_redirected_to new_user_session_path
    assert_nil session[:user_id]
  end

  # B2 (bug_report_23_cs) — login via rota Devise com hash do Pessoas2
  # nulo/inválido não pode gerar 500 (`BCrypt::Errors::InvalidHash` em
  # `User#valid_password?`). O guard/rescue no model retorna false → falha
  # limpa (recall 422 com alert), exatamente como senha errada.

  test "B2: login via rota devise com hash pessoas2 nulo falha limpo (sem 500)" do
    user_pessoas = User.create!(nome_completo: "Devise Hash Nulo", password: "senha-local-irrelevante", cpf: "11122233344")

    original = Pessoas::User.method(:buscar_por_cpf)
    Pessoas::User.define_singleton_method(:buscar_por_cpf) { |*_args, **_kwargs| Struct.new(:encrypted_password).new(nil) }
    begin
      post user_session_path, params: { user: { username: user_pessoas.username, password: "123456" } }

      assert_response :unprocessable_content
      assert_select ".alert-danger", "Username ou senha inválidos."
      assert_nil session[:user_id]
    ensure
      Pessoas::User.define_singleton_method(:buscar_por_cpf, original)
    end
  end

  test "B2: login via rota devise com hash pessoas2 corrompido falha limpo (sem 500)" do
    user_pessoas = User.create!(nome_completo: "Devise Hash Corrompido", password: "senha-local-irrelevante", cpf: "11122233344")

    original = Pessoas::User.method(:buscar_por_cpf)
    Pessoas::User.define_singleton_method(:buscar_por_cpf) { |*_args, **_kwargs| Struct.new(:encrypted_password).new("hash-corrompido") }
    begin
      post user_session_path, params: { user: { username: user_pessoas.username, password: "123456" } }

      assert_response :unprocessable_content
      assert_select ".alert-danger", "Username ou senha inválidos."
      assert_nil session[:user_id]
    ensure
      Pessoas::User.define_singleton_method(:buscar_por_cpf, original)
    end
  end

  # Bug 1 (bug_report_23_bug-finder, 2ª rodada) — falha de conexão/infra com
  # o mirror do Pessoas2 durante `Pessoas::User.buscar_por_cpf` não pode
  # gerar 500 em `POST /u/sign_in`. O wrapper `remote_password_hash_by_cpf`
  # envolve a consulta em rescue e devolve falha limpa (recall 422), igual
  # ao contrato de hash ausente/inválido (B2).

  test "Bug 1: login via rota devise falha limpo (sem 500) quando o pessoas2 esta indisponivel" do
    user_pessoas = User.create!(nome_completo: "Devise Pessoas2 Indisponivel", password: "senha-local-irrelevante", cpf: "11122233344")

    original = Pessoas::User.method(:buscar_por_cpf)
    Pessoas::User.define_singleton_method(:buscar_por_cpf) { |*_args, **_kwargs| raise ActiveRecord::ConnectionNotEstablished, "conexao indisponivel" }
    begin
      post user_session_path, params: { user: { username: user_pessoas.username, password: "123456" } }

      assert_response :unprocessable_content
      assert_select ".alert-danger", "Username ou senha inválidos."
      assert_nil session[:user_id]
    ensure
      Pessoas::User.define_singleton_method(:buscar_por_cpf, original)
    end
  end

  # B3 (bug_report_23_cs) — sessão de usuário desativado (status != 1) deve
  # ser revogada no próximo request: `Admin::ApplicationController#current_user`
  # revalida o status e o `require_login` redireciona para o login. Antes da
  # correção, o dashboard continuava 200 com a conta inativa.

  test "B3: usuario desativado (status=0) apos login via devise perde o acesso admin" do
    user = User.create!(nome_completo: "Devise Desativado", password: "123456")

    post user_session_path, params: { user: { username: user.username, password: "123456" } }
    assert_redirected_to dashboard_path
    assert_equal user.id, session[:user_id]

    user.update_column(:status, 0)

    get dashboard_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  test "B3: usuario desativado (status=0) apos login legado (/login) perde o acesso admin" do
    user = User.create!(nome_completo: "Legado Desativado", password: "123456")

    post login_path, params: { username: user.username, password: "123456" }
    assert_equal user.id, session[:user_id]

    user.update_column(:status, 0)

    get dashboard_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  # B4 (bug_report_23_cs) — remember_me inoperante no contexto admin. O
  # cookie `remember_user_token` é emitido no login; após o browser ser
  # reaberto (sessão limpa), o Warden reautentica mas `session[:user_id]`
  # não é sincronizado → o usuário era devolvido ao /login. A correção
  # sincroniza `session[:user_id]` na resolução de `current_user`.

  test "B4: remember_me restaura o acesso admin apos sessao limpa (acesso direto)" do
    user = User.create!(nome_completo: "Devise Remember", password: "123456")

    post user_session_path, params: { user: { username: user.username, password: "123456", remember_me: "1" } }
    assert_redirected_to dashboard_path
    assert cookies["remember_user_token"].present?, "cookie remember_user_token deve ser emitido"

    # Simula browser fechado/reaberto: descarta a sessão do servidor e
    # preserva o cookie remember (como um browser que reabre).
    cookies.delete("_api_ponto_session")

    get dashboard_path
    assert_response :success
    assert_equal user.id, session[:user_id], "session[:user_id] deve ser sincronizado via remember"
  end

  test "B4: remember_me e o fluxo /u/sign_in chegam ao dashboard (sem loop para /login)" do
    user = User.create!(nome_completo: "Devise Remember Chain", password: "123456")

    post user_session_path, params: { user: { username: user.username, password: "123456", remember_me: "1" } }
    assert_redirected_to dashboard_path
    assert cookies["remember_user_token"].present?

    cookies.delete("_api_ponto_session")

    get new_user_session_path
    assert_redirected_to dashboard_path

    follow_redirect!
    assert_response :success
    assert_equal user.id, session[:user_id]
  end

  test "deve fazer logout via rota devise (DELETE /u/sign_out)" do
    post user_session_path, params: { user: { username: @user.username, password: "123456" } }
    follow_redirect!
    assert_response :success

    delete destroy_user_session_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  test "deve fazer logout via /logout (admin) apos login via admin" do
    # Fluxo legado (Admin::SessionsController): session[:user_id] é a fonte
    # de verdade; o logout em /logout (Users::SessionsController#destroy)
    # precisa limpar session[:user_id] mesmo sem usuário no Warden.
    post login_path, params: { username: @user.username, password: "123456" }
    assert_equal @user.id, session[:user_id]

    delete logout_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  # Task 23.10 — Integração Devise × CanCanCan (fechamento da Sprint 23).
  #
  # Os testes acima provam que o login via rota Devise sincroniza
  # `session[:user_id]` (contexto admin reconhece o usuário), mas nenhum
  # exercitava a ESTEIRA completa até a autorização: login Devise (Warden) →
  # `Admin::ApplicationController#current_user` (sessão) → `current_ability`
  # (CanCanCan) → ação do controller admin. Com usuário SEM role o dashboard
  # já era alcançado (baseline de leitura 23.7); aqui validamos os dois
  # extremos da matriz por role via fluxo Devise: gestor (leitura OK,
  # escrita administrativa negada com redirect + alert do rescue_from) e
  # admin via role Rolify (gerencia CRUD).

  test "login via devise de gestor permite leitura e nega escrita administrativa (Devise x CanCan)" do
    gestor = User.create!(nome_completo: "Devise Gestor", password: "123456")
    gestor.add_role(:gestor)

    post user_session_path, params: { user: { username: gestor.username, password: "123456" } }
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success

    assert_no_difference("EstacaoPonto.count") do
      post estacoes_path, params: { estacao: { descricao: "Estacao Via Devise", cod_ativacao: "mx-devise-0001" } }
    end
    assert_redirected_to dashboard_path
    assert flash[:alert].present?, "AccessDenied deve preencher flash alert (rescue_from CanCan::AccessDenied)"
  end

  test "login via devise de admin por role permite criar estacao (Devise x CanCan)" do
    admin = User.create!(nome_completo: "Devise Admin Role", password: "123456")
    admin.add_role(:admin)
    refute admin.admin?, "pre-condicao: admin via role Rolify, coluna boolean false (dupla fonte de verdade da 23.5)"

    post user_session_path, params: { user: { username: admin.username, password: "123456" } }
    assert_redirected_to dashboard_path

    assert_difference("EstacaoPonto.count", 1) do
      post estacoes_path, params: { estacao: { descricao: "Estacao Via Devise Admin", cod_ativacao: "mx-devise-admin-0001" } }
    end
    assert_redirected_to estacoes_path
  end
end
