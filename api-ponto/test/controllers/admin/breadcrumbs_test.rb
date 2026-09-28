require "test_helper"

# Task 26.6 (Sprint 26) — gem `breadcrumbs_on_rails` + `add_breadcrumb`.
#
# A 26.6 adiciona a gem do basic8 e o trilho "Início" → root_path no contexto
# ADMIN. Particularidade do Frequencia: a base `ApplicationController` é
# `ActionController::API` (não Base), e o railtie da gem 4.1.0 injeta o concern
# apenas em `ActionController::Base` — por isso o include explícito no base
# (mesmo padrão dos demais módulos: Helpers, Flash, MimeResponds) e o
# `add_breadcrumb` registrado SOMENTE no `Admin::ApplicationController`
# (RNF01/RNF06 — contexto API/presença com a cadeia vazia; ADR-001 Seção 4).
#
# Cobertura do aceite:
#   1. Gem carregada, concern no ancestry e helper_method `breadcrumbs` exposto.
#   2. Ação admin REAL (esteira router → before_action → CanCan → action) →
#      cadeia com 1 crumb: name "Início", path :root_path (padrão basic8).
#   3. Helper `breadcrumbs` disponível nas views admin (`view_context`) — o que
#      o partial `shared/_title` (26.4) consumirá via `breadcrumbs.any?` e
#      `crumb.path`/`crumb.name` (fonte basic8 resolve path Symbol via send).
#   4. Contexto API/presença intocado: endpoint real de presença (sem sessão)
#      → cadeia VAZIA (nenhuma view não-admin renderiza breadcrumbs).
module Admin
  class BreadcrumbsTest < ActionDispatch::IntegrationTest
    # ----------------------------------------------------------------------
    # Helpers (mesmo padrão dos demais arquivos de teste admin)
    # ----------------------------------------------------------------------

    def criar_admin_por_role
      User.create!(nome_completo: "Admin Breadcrumbs Teste", password: "123456").tap do |user|
        user.add_role(:admin)
      end
    end

    def login_como(user)
      post login_path, params: { username: user.username, password: "123456" }
      assert_response :redirect
      follow_redirect!
    end

    # ----------------------------------------------------------------------
    # 1. Gem carregada + concern no ancestry + helper exposto
    # ----------------------------------------------------------------------

    test "gem carregada e concern BreadcrumbsOnRails::ActionController incluido na base" do
      assert defined?(BreadcrumbsOnRails::VERSION), "gem breadcrumbs_on_rails deve estar no bundle"
      assert_includes ApplicationController.ancestors, BreadcrumbsOnRails::ActionController,
                      "include explícito do concern na base (railtie só cobre ActionController::Base)"
      assert ApplicationController._helper_methods.include?(:breadcrumbs),
             "helper_method :breadcrumbs deve estar registrado para as views"
      assert ApplicationController.respond_to?(:add_breadcrumb),
             "add_breadcrumb (método de classe) deve estar disponível na base"
    end

    # ----------------------------------------------------------------------
    # 2. add_breadcrumb em ação admin real
    # ----------------------------------------------------------------------

    test "acao admin real registra breadcrumb Inicio -> root_path" do
      login_como(criar_admin_por_role)

      get estacoes_path
      assert_response :success

      trilho = @controller.send(:breadcrumbs)
      assert_equal 1, trilho.size, "a cadeia deve conter exatamente o crumb Início (26.6)"
      assert_equal "Início", trilho.first.name
      assert_equal :root_path, trilho.first.path,
                   "path é o Symbol :root_path — o _title (26.4) resolve via send (fonte basic8)"
    end

    # ----------------------------------------------------------------------
    # 3. Helper disponível nas views admin (view_context)
    # ----------------------------------------------------------------------

    test "helper breadcrumbs disponivel no view_context admin com any? e crumb resolvivel" do
      login_como(criar_admin_por_role)

      get dashboard_path
      assert_response :success

      view = @controller.view_context
      assert view.respond_to?(:breadcrumbs), "views admin devem expor o helper breadcrumbs"

      trilho = view.breadcrumbs
      assert trilho.any?, "breadcrumbs.any? deve ser true após ação admin (uso do _title)"
      assert_equal "Início", trilho.first.name
      assert_equal root_path, view.send(trilho.first.path),
                   "crumb.path (Symbol) deve resolver para root_path no contexto da view"
    end

    # ----------------------------------------------------------------------
    # 4. Contexto API/presença intocado (RNF01/RNF06)
    # ----------------------------------------------------------------------

    test "contexto presenca mantem cadeia de breadcrumbs vazia (sem sessao admin)" do
      # Endpoint que passa por `Presenca::ApplicationController` — herda o
      # concern (via base) mas NENHUM `add_breadcrumb` é registrado fora do
      # contexto admin: a cadeia precisa ficar vazia no request real.
      get presenca_Frequentador_url
      assert_response :success

      assert_empty @controller.send(:breadcrumbs),
                   "o contexto presença não registra add_breadcrumb — cadeia deve ficar vazia"
      callback_de_breadcrumbs = Presenca::FrequentadorController._process_action_callbacks.any? do |callback|
        callback.filter.is_a?(Proc) && callback.kind == :before &&
          callback.filter.source_location.first.include?("breadcrumbs_on_rails")
      end
      refute callback_de_breadcrumbs,
             "before_action de breadcrumbs NÃO deve existir no contexto presença (só no Admin::ApplicationController)"
    end
  end
end
