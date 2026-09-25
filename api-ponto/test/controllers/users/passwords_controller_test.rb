require "test_helper"

# Task 23.8 — Views Devise de recuperação de senha (Users::PasswordsController).
#
# Cobrem as rotas recoverable (/u/password/new, /u/password/edit) e as
# renderizações das views novas (app/views/users/passwords/*) no layout
# "login". B1 (bug_report_23_cs): ActionMailer NÃO está montado nesta
# aplicação (config/application.rb não requer o railtie) — o disparo do
# e-mail falha com `NameError: uninitialized constant Devise::Mailer`. O
# controller degrada com redirect + flash de aviso (nunca 500) e o fluxo
# de token (`reset_password_by_token` — PATCH) permanece funcional. O teste
# de envio MOCKADO que mascara a rota quebrada foi substituído por teste do
# comportamento real (sem stub).
class Users::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(nome_completo: "Devise Passwords",
                         password: "123456",
                         email: "devise.passwords@tjpi.jus.br")
  end

  test "GET /u/password/new renderiza a view users/passwords/new" do
    get new_user_password_path

    assert_response :success
    assert_select "form[action='/u/password']"
    assert_select "input[name='user[email]']"
    assert_select "h3", "API Ponto TJPI"
    assert_select "a[href='/u/sign_in']", text: "Entrar"
  end

  test "GET /u/password/edit com token renderiza a view users/passwords/edit" do
    get edit_user_password_path, params: { reset_password_token: "token-para-edit" }

    assert_response :success
    assert_select "form[action='/u/password']"
    assert_select "input[name='user[reset_password_token]'][value='token-para-edit']"
    assert_select "input[type='password'][name='user[password]']"
    assert_select "input[type='password'][name='user[password_confirmation]']"
    assert_select "h3", "API Ponto TJPI"
  end

  test "POST /u/password com email desconhecido redireciona com mensagem genérica (paranoid, sem envio)" do
    # Bug 2 (bug_report_23_bug-finder, 2ª rodada): `config.paranoid = true`
    # elimina a enumeração de contas — email desconhecido não re-renderiza
    # mais o form com 422/erro "não encontrado"; responde com o MESMO tipo
    # de resposta (redirect) do email conhecido (ver teste abaixo).
    assert_no_difference -> { User.count } do
      post user_password_path, params: { user: { email: "nao.existe@tjpi.jus.br" } }
    end

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]
  end

  test "POST /u/password com email conhecido sem ActionMailer degrada limpo (redirect + notice genérico, sem 500)" do
    # B1 (bug_report_23_cs): SEM stub — o fluxo real gera o token e tenta
    # disparar `Devise::Mailer` (inexistente). Antes da correção, este teste
    # falhava com NameError (HTTP 500 real na rota pública); o controller
    # agora converte a falha em redirect com flash de aviso.
    #
    # Bug 9 (bug_report_23_bug-finder-r3): o flash exposto ao usuário final
    # é o MESMO (:notice, :send_paranoid_instructions) usado no caminho de
    # email desconhecido — nunca `:alert, :mail_unavailable` (isso reabria a
    # enumeração de contas por conteúdo/cor/ícone do flash, mesmo com status
    # HTTP idêntico). O erro real continua sendo logado internamente via
    # `Rails.logger.error` para o administrador perceber a falha do mailer.
    post user_password_path, params: { user: { email: @user.email } }

    assert_redirected_to new_user_session_path
    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), flash[:notice]
    assert_nil flash[:alert]
  end

  test "POST /u/password com email conhecido e desconhecido retornam o mesmo status HTTP e flash (Bug 2 e Bug 9)" do
    # Bug 2 (bug_report_23_bug-finder, 2ª rodada): antes da correção, email
    # conhecido → 302 e email desconhecido → 422 (enumeração de contas via
    # diferença de status). Com `config.paranoid = true`, ambos os casos
    # respondem com o MESMO status HTTP e tipo de resposta (redirect; 303
    # `see_other`, conforme `config.responder.redirect_status` do projeto).
    #
    # Bug 9 (bug_report_23_bug-finder-r3): a correção do Bug 2 só igualou o
    # status HTTP — o CONTEÚDO/TIPO do flash continuava diferente (`:alert`
    # vermelho para email conhecido vs. `:notice` verde para desconhecido),
    # reabrindo a enumeração por outro canal. Este teste usa `reset!` para
    # isolar as sessões entre as duas requisições — testes que reusam a
    # mesma sessão mascaram essa diferença (lacuna diagnosticada no
    # relatório da 3ª rodada do Bug Finder).
    post user_password_path, params: { user: { email: @user.email } }
    known_status = response.status
    known_notice = flash[:notice]
    known_alert = flash[:alert]

    reset!

    post user_password_path, params: { user: { email: "nao.existe@tjpi.jus.br" } }
    unknown_status = response.status
    unknown_notice = flash[:notice]
    unknown_alert = flash[:alert]

    assert_equal known_status, unknown_status
    assert response.redirect?, "resposta deve ser um redirect"

    assert_nil known_alert, "email conhecido não deve expor flash[:alert]"
    assert_nil unknown_alert, "email desconhecido não deve expor flash[:alert]"
    assert_equal known_notice, unknown_notice, "flash[:notice] deve ser idêntico (texto) entre email conhecido e desconhecido"
    assert_equal I18n.t("devise.passwords.send_paranoid_instructions"), known_notice
  end

  test "PATCH /u/password com token invalido re-renderiza edit com erro" do
    patch user_password_path, params: {
      user: {
        reset_password_token: "token-invalido",
        password: "nova-senha",
        password_confirmation: "nova-senha"
      }
    }

    assert_response :unprocessable_content
    assert_select "form[action='/u/password']"
    assert_select "input[name='user[reset_password_token]']"
    assert_select ".alert-danger"
  end
end
