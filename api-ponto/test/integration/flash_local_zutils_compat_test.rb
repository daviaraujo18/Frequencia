require "test_helper"

# Task 24.5 (Sprint 24) — RF14: compatibilidade do flash local com a zutils carregada.
#
# A gem zutils 4.0.0 (engine, instalada na task 24.1) entrega uma superfície de
# flash própria no contexto de view:
#
#   * `Zutils::Helpers#bootstrap_flash(options = {})` — incluído no
#     `ActionView::Base` via `config.to_prepare` do engine. Mapeia as chaves do
#     flash para alertas Bootstrap: `notice`/`success` → `alert-success`,
#     `error` → `alert-danger`, `alert` → `alert-warning` (AMARELO) e demais →
#     `alert-info`. Tem efeito colateral: zera `flash[:error]` no final.
#   * Partial `shared/_flash.html.erb` da engine — embrulha `bootstrap_flash`
#     num `<div id="flash_messages" data-controller="toastr">`.
#
# O layout admin (e o application) NÃO adotam nada disso (RF14): renderizam
# `flash[:notice]`/`flash[:alert]` INLINE, com classes locais (`alert-success`
# para notice e `alert-danger` para alert). Esta suíte comprova, com a zutils
# carregada no bundle:
#
#   1. Ação admin REAL com `redirect_to ..., notice:` → o flash renderiza com o
#      markup LOCAL do layout admin, exatamente um alerta, sem artefatos da
#      superfície zutils (sem `#flash_messages`/`toastr`).
#   2. Ação admin REAL que lança `CanCan::AccessDenied` (rescue_from 23.7) →
#      `flash[:alert]` renderiza com `alert-danger` (mapeamento LOCAL), NÃO
#      `alert-warning` (mapeamento da zutils `bootstrap_flash`) — prova da
#      preferência local onde as duas superfícies coexistem para a mesma chave.
#   3. RF14 estrutural: layouts inalterados, nenhum partial `shared/flash*` no
#      app, nenhum helper `bootstrap_flash` adotado.
#   4. Engine zutils ativa (`Zutils::Helpers` no ancestry do `ActionView::Base`)
#      coexiste sem colidir com o flash local.
class FlashLocalZutilsCompatTest < ActionDispatch::IntegrationTest
  # ----------------------------------------------------------------------
  # Helpers (mesmo padrão dos demais arquivos de teste admin)
  # ----------------------------------------------------------------------

  def criar_admin
    User.create!(nome_completo: "Admin Flash Teste", password: "123456", admin: true)
  end

  def criar_gestor
    User.create!(nome_completo: "Gestor Flash Teste", password: "123456").tap do |user|
      user.add_role(:gestor)
    end
  end

  def login_como(user)
    post login_path, params: { username: user.username, password: "123456" }
    assert_response :redirect
    follow_redirect!
  end

  # ----------------------------------------------------------------------
  # 1. Ação admin real com redirect_to ..., notice:
  #    Admin::SessionsController#create (rota POST /login) → redireciona para o
  #    dashboard com `notice: "Login realizado com sucesso"` — exatamente o
  #    exemplo do critério de aceite da 24.5.
  # ----------------------------------------------------------------------

  test "flash notice de acao admin real (login) renderiza com markup local no layout admin" do
    usuario = criar_admin

    # POST /login (Admin::SessionsController#create) redireciona para o dashboard
    # com `notice:` — o flash sobrevive até ser consumido pela próxima
    # renderização. O dashboard do administrador consulta Pessoas::Vinculo
    # (tabela `vinculos` inexistente no banco de teste — padrão da task 8.13),
    # então consumimos o flash numa página admin que renderiza o layout sem
    # tocar Pessoas (regimes_path).
    post login_path, params: { username: usuario.username, password: "123456" }
    assert_redirected_to dashboard_path
    assert_equal "Login realizado com sucesso", flash[:notice]

    get regimes_path
    assert_response :success

    # markup LOCAL do layout admin (RF14): exatamente um alerta, classes locais.
    assert_select "div.alert", 1
    assert_select "div.alert.alert-success", 1
    assert_select "button.btn-close[data-bs-dismiss=alert]", 1
    assert_match(/Login realizado com sucesso/, @response.body)

    # nenhum artefato da superfície de flash da zutils (shared/_flash + toastr).
    assert_no_match(/id="flash_messages"/, @response.body)
    assert_no_match(/data-controller="toastr"/, @response.body)
  end

  # ----------------------------------------------------------------------
  # 2. Ação admin real com flash[:alert]:
  #    gestor tenta `new_estacao_path` → CanCan::AccessDenied → rescue_from
  #    23.7 → `redirect_to dashboard_path, alert: exception.message`.
  #    Com a zutils carregada, o mapeamento local (alert → alert-danger) deve
  #    prevalecer sobre o da zutils `bootstrap_flash` (alert → alert-warning).
  # ----------------------------------------------------------------------

  test "flash alert de acao admin real (CanCan AccessDenied) renderiza alert-danger local, nao alert-warning da zutils" do
    gestor = criar_gestor
    login_como(gestor)

    # gestor não gerencia EstaçãoPonto → AccessDenied → redirect dashboard + alert.
    get new_estacao_path
    assert_redirected_to dashboard_path
    assert flash[:alert].present?, "AccessDenied deve preencher flash alert (rescue_from do Admin::ApplicationController)"

    mensagem = flash[:alert]
    follow_redirect!
    assert_response :success

    # preferência LOCAL: alert → alert-danger. A zutils bootstrap_flash mapearia
    # alert → alert-warning; a página renderizada NÃO pode conter este mapeamento.
    assert_select "div.alert", 1
    assert_select "div.alert.alert-danger", 1
    assert_select "div.alert.alert-warning", 0
    assert_match(/#{Regexp.escape(mensagem)}/, @response.body)

    # sem artefatos da superfície zutils (mesmo com a engine ativa).
    assert_no_match(/id="flash_messages"/, @response.body)
    assert_no_match(/data-controller="toastr"/, @response.body)
  end

  # ----------------------------------------------------------------------
  # 3. RF14 estrutural — nenhuma adoção da superfície de flash da zutils.
  # ----------------------------------------------------------------------

  test "RF14: layouts admin/application inalterados e sem partial shared/flash nem helper bootstrap_flash" do
    admin_layout = File.read(Rails.root.join("app/views/layouts/admin.html.erb"))
    application_layout = File.read(Rails.root.join("app/views/layouts/application.html.erb"))

    # layout admin renderiza flash[:notice]/flash[:alert] inline com classes locais.
    assert_includes admin_layout, "flash[:notice]"
    assert_includes admin_layout, "flash[:alert]"
    assert_includes admin_layout, "alert alert-success"
    assert_includes admin_layout, "alert alert-danger"

    # layout application renderiza os helpers `notice`/`alert`
    # (ActionController::Flash, application_controller.rb) com classes locais.
    assert_includes application_layout, "if notice"
    assert_includes application_layout, "if alert"
    assert_includes application_layout, "alert alert-success"
    assert_includes application_layout, "alert alert-danger"

    [ admin_layout, application_layout ].each do |layout|
      refute_includes layout, "shared/flash", "RF14: layout não pode renderizar partial shared/flash"
      refute_includes layout, "bootstrap_flash", "RF14: layout não pode chamar helper bootstrap_flash"
      refute_includes layout, "toastr", "RF14: layout não pode adotar a superfície toastr da zutils"
    end

    # nenhum partial shared/flash* no app (apenas a engine zutils os define).
    refute File.exist?(Rails.root.join("app/views/shared/_flash.html.erb"))
    refute File.exist?(Rails.root.join("app/views/shared/_flash_only_toastr.html.erb"))

    # helper não adotado no ApplicationHelper (disponível apenas via engine).
    refute ApplicationHelper.method_defined?(:bootstrap_flash)
  end

  # ----------------------------------------------------------------------
  # 4. Coexistência: engine zutils ativa, sem colisão de renderização.
  # ----------------------------------------------------------------------

  test "zutils carregada coexiste: Zutils::Helpers no ancestry do ActionView::Base sem colidir com o flash local" do
    assert_includes ActionView::Base.ancestors, Zutils::Helpers,
                    "engine zutils deve estar ativa (config.to_prepare) e expor seus helpers no contexto de view"

    # A prova renderizada da coexistência está nos testes 1 e 2 desta suíte:
    # páginas admin reais renderizam o flash com o markup LOCAL (alert-success/
    # alert-danger) e sem nenhum artefato da superfície zutils — a engine está
    # carregada, mas a renderização local prevalece porque o layout não a chama.
  end
end
