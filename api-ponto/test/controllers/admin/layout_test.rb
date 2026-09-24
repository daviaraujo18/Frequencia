require "test_helper"

# Task 26.5 (Sprint 26) — composição do layout `admin.html.erb` a partir dos
# partials `shared/*` + remoção do JS inline duplicado da sidebar.
#
# Diferente das tasks 26.2/26.3/26.4 (partials testados EM ISOLAMENTO via
# `view_context`), esta task testa a COMPOSIÇÃO REAL: `get` numa action admin
# renderiza o layout `admin.html.erb` inteiro (header/sidebar/title/footer via
# partials + flash local + head dinâmico), e o corpo HTML da RESPOSTA é
# verificado com Nokogiri (documento completo — inclui o <head>).
#
# Cobertura por critério de aceite da 26.5:
#   - composição `shared/*` (header/sidebar/title/footer) — sem os blocos
#     inline equivalentes do layout antigo;
#   - JS inline duplicado da sidebar REMOVIDO — persistência via
#     `sidebar_controller.js` (Stimulus — data-controller/data-action no toggle)
#     + AdminLTE nativo (`data-enable-persistence` no aside do partial 26.2);
#   - flash local PRESERVADO (RF14): `flash[:notice]`→alert-success e
#     `flash[:alert]`→alert-danger no layout (sem `shared/flash*`/zutils);
#   - título dinâmico: `@app_name` + sufixo (`content_for?(:page_title)` ou
#     fallback `resource_human_name`) — sem "API Ponto TJPI" hardcoded;
#   - favicon presente (`/icon.png` + `/icon.svg` — padrão basic8, portados);
#   - meta `theme-color` alinhada à paleta `$primary: #2563eb` (26.8);
#   - menu (sidebar via `@static_menu` com filtro `can?`) e badges `text-bg-*`.
#
# Cenários de flash REAIS (sem stub): `EstacoesController#create` redireciona
# com `notice` (admin — Estação criada com sucesso) e o `rescue_from
# CanCan::AccessDenied` do Admin::ApplicationController redireciona com `alert`
# (usuário autenticado sem permissão de escrita — baseline read 23.7).
#
# Decisão registrada na Linha do Tempo da 26.5: o fallback do título via
# `resource_human_name` (telas SEM `content_for :page_title`) NÃO é exercitado
# com action admin real hoje — TODAS as views admin atuais setam `page_title`.
# O fallback é coberto indiretamente pela task 26.4 (`resource_human_name` e
# branches do `_title`) e será exercido pelos scaffolds da Sprint 25.
module Admin
  class LayoutTest < ActionDispatch::IntegrationTest
    # ----------------------------------------------------------------------
    # Helpers (mesmo padrão dos demais arquivos de teste admin)
    # ----------------------------------------------------------------------

    def criar_usuario(nome_completo:, email: nil)
      User.create!(nome_completo: nome_completo, password: "123456", email: email)
    end

    def criar_admin_por_role
      criar_usuario(nome_completo: "Admin Layout Teste").tap do |user|
        user.add_role(:admin)
      end
    end

    def criar_usuario_multirroles
      criar_usuario(nome_completo: "Gestor Layout Teste").tap do |user|
        user.add_role(:admin)
        user.add_role(:gestor)
      end
    end

    def criar_usuario_sem_roles
      criar_usuario(nome_completo: "Operador Layout Teste")
    end

    def login_como(user)
      post login_path, params: { username: user.username, password: "123456" }
      assert_response :redirect
      follow_redirect!
    end

    # GET admin real + documento Nokogiri completo (inclui o <head>).
    def get_document(caminho)
      get caminho
      assert_response :success
      Nokogiri::HTML(response.body)
    end

    def document
      Nokogiri::HTML(response.body)
    end

    # ----------------------------------------------------------------------
    # Composição: layout renderiza shared/_header, _sidebar, _footer e _title
    # (quando aplicável) — blocos inline equivalentes removidos
    # ----------------------------------------------------------------------

    test "compoe shared/header, shared/sidebar, shared/footer e shared/title sem os blocos inline antigos" do
      login_como(criar_admin_por_role)
      doc = get_document(estacoes_path)

      # Header — partial da 26.3 (bg-primary/dark, marca central com @app_icon).
      header = doc.at_css("nav.app-header.navbar.navbar-expand.bg-primary[data-bs-theme='dark']")
      assert header, "header deve vir do partial shared/_header (visual basic8)"
      assert header.at_css("i.me-2.fa.fa-fw.fa-cube"), "marca central com @app_icon (ApplicationRecord.icon)"
      assert header.at_css("strong"), "marca central com @app_name"
      assert_nil doc.at_css("nav.app-header.navbar.navbar-expand.bg-body"),
                 "bloco inline antigo do header (bg-body) não deve permanecer no layout"

      # Sidebar — partial da 26.2 (data-enable-persistence do AdminLTE nativo).
      aside = doc.at_css("aside.app-sidebar.bg-body-secondary.shadow[data-enable-persistence='true']")
      assert aside, "sidebar deve vir do partial shared/_sidebar com persistência AdminLTE nativa"
      assert aside.at_css("div.sidebar-brand"), "brand da sidebar com sidebar-brand do partial"
      assert_nil doc.at_css("aside.app-sidebar.bg-body-secondary.shadow[data-bs-theme='dark']"),
                 "bloco inline antigo do aside (data-bs-theme=dark) não deve permanecer (decisão 26.5/26.8)"

      # Footer — partial criado na 26.5 (app-footer com @app_name).
      footer = doc.at_css("footer.app-footer.d-none.d-sm-block")
      assert footer, "footer deve vir do partial shared/_footer"
      assert footer.at_css("div.float-end strong"), "footer com @app_name no bloco direito"
      assert_includes footer.text, "Tribunal de Justiça do Piauí", "footer preserva a identidade TJPI (adaptação 26.5)"

      # Título — partial da 26.4 (estacoes NÃO é dashboard/sessions → renderiza).
      assert doc.at_css("div.app-content-header"), "shared/_title deve renderizar para estacoes"
      assert doc.at_css("ol.breadcrumb"), "breadcrumbs do _title presentes"

      assert doc.at_css("div.app-wrapper"), "estrutura app-wrapper do AdminLTE"
    end

    test "dashboard nao renderiza shared/title (return early) mas compoe header/sidebar/footer" do
      login_como(criar_admin_por_role)
      doc = get_document(dashboard_path)

      assert_nil doc.at_css("div.app-content-header"), "dashboard NÃO deve renderizar o título (return early do _title)"
      assert doc.at_css("nav.app-header"), "header presente no dashboard"
      assert doc.at_css("aside.app-sidebar"), "sidebar presente no dashboard"
      assert doc.at_css("footer.app-footer"), "footer presente no dashboard"
    end

    # ----------------------------------------------------------------------
    # Título dinâmico: @app_name + sufixo (content_for :page_title) — sem
    # "API Ponto TJPI" hardcoded como título único
    # ----------------------------------------------------------------------

    test "titulo dinamico usa @app_name + content_for :page_title da view" do
      login_como(criar_admin_por_role)

      doc = get_document(estacoes_path)
      assert_equal "API Ponto TJPI | Gerência de Estações de Ponto", doc.at_css("title").text,
                   "<title> = @app_name + page_title real da view (estacoes/index)"

      doc = get_document(dashboard_path)
      assert_equal "API Ponto TJPI | Dashboard", doc.at_css("title").text,
                   "<title> = @app_name + page_title real da view (dashboard/index)"
    end

    test "titulo nao fica hardcoded como API Ponto TJPI unico" do
      login_como(criar_admin_por_role)
      doc = get_document(dashboard_path)

      title = doc.at_css("title").text
      refute_equal "API Ponto TJPI", title, "título não pode ser o hardcoded antigo"
      assert_includes title, "|", "título deve ter separador @app_name | sufixo"
    end

    # ----------------------------------------------------------------------
    # Flash local PRESERVADO (RF14): notice→alert-success, alert→alert-danger
    # ----------------------------------------------------------------------

    test "flash notice real (create admin) renderiza alert-success no layout" do
      login_como(criar_admin_por_role)

      # EstacoesController#create → redirect estacoes_path com notice (RF14).
      post estacoes_path, params: { estacao: { descricao: "Estação Layout Teste", cod_ativacao: "LAYOUT-TESTE-001" } }
      assert_response :redirect
      follow_redirect!
      assert_response :success

      doc = document
      alert = doc.at_css("div.alert.alert-success.alert-dismissible.fade.show[role='alert']")
      assert alert, "flash[:notice] deve renderizar alert-success no layout (RF14)"
      assert_includes alert.text, "Estação criada com sucesso", "texto do flash notice preservado"
      assert alert.at_css("button.btn-close[data-bs-dismiss='alert']"), "botão de fechar presente (dismissible)"
      assert_nil doc.at_css("div.alert.alert-danger"), "sem alert não deve renderizar alert-danger"
    end

    test "flash alert real (AccessDenied) renderiza alert-danger no layout" do
      login_como(criar_usuario_sem_roles)

      # Usuário sem role tem baseline `can :read, :all` (23.7) — sem create em
      # EstacaoPonto → load_and_authorize_resource nega → rescue_from
      # CanCan::AccessDenied → redirect dashboard com alert.
      post estacoes_path, params: { estacao: { descricao: "Estação Negada", cod_ativacao: "NEGADA-001" } }
      assert_response :redirect
      follow_redirect!
      assert_response :success

      doc = document
      alert = doc.at_css("div.alert.alert-danger.alert-dismissible.fade.show[role='alert']")
      assert alert, "flash[:alert] deve renderizar alert-danger no layout (RF14)"
      refute_empty alert.text.squish, "mensagem do AccessDenied não vazia"
      assert alert.at_css("button.btn-close[data-bs-dismiss='alert']"), "botão de fechar presente (dismissible)"
      assert_nil doc.at_css("div.alert.alert-success"), "sem notice não deve renderizar alert-success"
    end

    # ----------------------------------------------------------------------
    # Favicon (padrão basic8: /icon.png + /icon.svg) + theme-color #2563eb
    # ----------------------------------------------------------------------

    test "favicon presente no padrao basic8 (icon.png + icon.svg)" do
      login_como(criar_admin_por_role)
      doc = get_document(dashboard_path)

      assert doc.at_css("link[rel='icon'][href='/icon.png'][type='image/png']"),
             "favicon png (port do basic8 public/icon.png)"
      assert doc.at_css("link[rel='icon'][href='/icon.svg'][type='image/svg+xml']"),
             "favicon svg (port do basic8 public/icon.svg)"
      assert doc.at_css("link[rel='apple-touch-icon'][href='/icon.png']"),
             "apple-touch-icon do padrão basic8"
    end

    test "meta theme-color sincronizada com a paleta primary #2563eb (26.8)" do
      login_como(criar_admin_por_role)
      doc = get_document(dashboard_path)

      light = doc.at_css("meta[name='theme-color'][media='(prefers-color-scheme: light)']")
      assert light && light["content"] == "#2563eb",
             "theme-color light deve ser #2563eb (paleta $primary da 26.8)"
      dark = doc.at_css("meta[name='theme-color'][media='(prefers-color-scheme: dark)']")
      assert dark && dark["content"] == "#1a1a1a",
             "theme-color dark mantém o tom escuro do Frequencia"
    end

    # ----------------------------------------------------------------------
    # JS inline duplicado da sidebar REMOVIDO — persistência preservada via
    # sidebar_controller.js (Stimulus) + AdminLTE nativo
    # ----------------------------------------------------------------------

    test "JS inline duplicado da sidebar removido e persistencia preservada" do
      login_como(criar_admin_por_role)
      doc = get_document(estacoes_path)

      # O bloco <script> inline antigo (chave "admin-sidebar-collapsed" +
      # DOMContentLoaded) não existe mais no HTML servido.
      refute_includes response.body, "admin-sidebar-collapsed",
                      "script inline antigo da sidebar removido (persistência não fica no layout)"
      refute_includes response.body, "DOMContentLoaded",
                      "nenhum script inline com DOMContentLoaded no layout admin"

      # Persistência e toggle continuam cobertos fora do layout:
      #   - sidebar_controller.js (Stimulus, task 24.8) conectado ao MESMO
      #     botão [data-lte-toggle="sidebar"] (header partial da 26.3);
      #   - AdminLTE nativo com data-enable-persistence="true" (aside do
      #     partial _sidebar da 26.2 — STORAGE_KEY 'lte.sidebar.state').
      toggle = doc.at_css("a.nav-link[data-lte-toggle='sidebar'][data-controller='sidebar'][data-action='click->sidebar#toggle']")
      assert toggle, "toggle preserva o sidebar_controller.js (Stimulus) no header partial"
      assert doc.at_css("aside[data-enable-persistence='true']"),
             "persistência do colapso preservada via AdminLTE nativo (partial _sidebar)"
    end

    # ----------------------------------------------------------------------
    # Menu (sidebar data-driven via @static_menu) + badges text-bg-*
    # ----------------------------------------------------------------------

    test "menu da sidebar renderiza a navegacao data-driven com destaque ativo" do
      login_como(criar_admin_por_role)
      doc = get_document(estacoes_path)

      menu = doc.at_css("ul.nav.sidebar-menu.flex-column[data-lte-toggle='treeview'][data-accordion='false']")
      assert menu, "menu AdminLTE 4 com treeview do partial _sidebar"

      # Navegação real (26.1 — @static_menu): Dashboard, Registros de Ponto,
      # Usuários (admin), Presença (grupo com children).
      assert menu.at_css("a[href='#{dashboard_path}']"), "item Dashboard"
      assert menu.at_css("a[href='#{time_records_path}']"), "item Registros de Ponto"
      assert menu.at_css("a[href='#{users_path}']"), "item Usuários visível para admin (can? manage User)"
      assert menu.at_css("a[href='#{estacoes_path}']"), "item Explorar Estações (neto do grupo Presença)"

      # Destaque da tela ativa: estacoes ativo (menu_activated? 26.2).
      link_ativo = menu.at_css("a.nav-link.active[href='#{estacoes_path}']")
      assert link_ativo, "link da tela atual com classe active"
    end

    test "badges de roles usam a convencao text-bg-primary (header + title)" do
      login_como(criar_usuario_multirroles)
      doc = get_document(estacoes_path)

      # Badges do _header (dropdown do usuário) e do _title (linha superior) —
      # convenção text-bg-* da 26.3 reutilizada, sem bg-primary antigo.
      badges = doc.css("span.badge.text-bg-primary")
      assert badges.size >= 2, "badges text-bg-primary presentes (header + title)"
      names = badges.map { |b| b.text.strip }.uniq.sort
      assert_equal %w[admin gestor], names, "badges exibem role.name"
      assert_empty doc.css("span.badge.bg-primary"),
                   "nenhuma badge com a classe antiga bg-primary (convenção 26.3 é text-bg-*)"
    end
  end
end
