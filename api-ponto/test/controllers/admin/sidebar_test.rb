require "test_helper"

# Task 26.2 (Sprint 26) — partial `shared/_sidebar` (menu dinâmico data-driven).
#
# A 26.2 porta o partial do basic8 EM ISOLAMENTO — o layout `admin.html.erb`
# ainda não compõe os partials `shared/*` (isso é a task 26.5). Para atender o
# critério "HTML renderizado em ação admin real (ex.: estacoes_path)", o partial
# é renderizado no `view_context` do controller que processou a action real de
# integração (esteira completa: router → require_login → set_configurations →
# CanCanCan → action). Isso expõe o stack real ao partial SEM antecipar a 26.5:
# `@static_menu`/`@app_name`/`@app_icon` das before_actions (26.1), `can?` do
# `current_ability` (ability 23.5) e `menu_activated?` do ApplicationHelper
# (zutils — inclui a peculiaridade truthy "error", já coberta na 26.1).
#
# Filtro por role validado contra a ability.rb (fonte de verdade 23.5):
#   - admin (role :admin) → `can :manage, :all` → vê TODO o menu (incl. Usuários).
#   - operador → `can :read, :all` (baseline 23.7) → vê apenas itens de leitura;
#     NÃO vê Usuários (`can?(:manage, User)` é false para operador).
module Admin
  class SidebarTest < ActionDispatch::IntegrationTest
    # ----------------------------------------------------------------------
    # Helpers (mesmo padrão dos demais arquivos de teste admin)
    # ----------------------------------------------------------------------

    def criar_usuario(nome_completo:)
      User.create!(nome_completo: nome_completo, password: "123456")
    end

    # Admin via Rolify ONLY (coluna `admin` permanece false) — exercita a
    # condição `user.has_role?(:admin)` da Ability (padrão da authorization_matrix).
    def criar_admin_por_role
      criar_usuario(nome_completo: "Admin Sidebar Teste").tap do |user|
        user.add_role(:admin)
      end
    end

    def criar_operador
      criar_usuario(nome_completo: "Operador Sidebar Teste").tap do |user|
        user.add_role(:operador)
      end
    end

    def login_como(user)
      post login_path, params: { username: user.username, password: "123456" }
      assert_response :redirect
      follow_redirect!
    end

    def trocar_usuario(user)
      delete logout_path
      post login_path, params: { username: user.username, password: "123456" }
      follow_redirect!
    end

    # Ação admin REAL (default: estacoes_path) e render do partial no
    # view_context do controller que processou — o mesmo contexto que a view
    # admin usará quando a 26.5 compuser o layout.
    def sidebar_html(caminho = estacoes_path)
      get caminho
      assert_response :success
      @controller.view_context.render(partial: "shared/sidebar")
    end

    def document(html)
      Nokogiri::HTML.fragment(html)
    end

    # ----------------------------------------------------------------------
    # Estrutura AdminLTE 4 (porta do basic8)
    # ----------------------------------------------------------------------

    test "porta a estrutura AdminLTE 4 com marca, 3 niveis e atributos preservados" do
      login_como(criar_admin_por_role)
      html = sidebar_html
      doc = document(html)

      # Estrutura AdminLTE 4: app-sidebar + data-enable-persistence preservado.
      aside = doc.at_css("aside.app-sidebar.bg-body-secondary.shadow[data-enable-persistence='true']")
      assert aside, "aside deve ter classes AdminLTE 4 e data-enable-persistence preservado"

      # Marca: @app_icon (ApplicationRecord.icon) + @app_name linkando à raiz.
      brand = doc.at_css("div.sidebar-brand a.brand-link[href='/']")
      assert brand, "sidebar-brand deve linkar à raiz com a classe brand-link"
      assert_includes html, ApplicationRecord.icon, "marca deve exibir @app_icon"
      assert_includes html, "API Ponto TJPI", "marca deve exibir @app_name"

      # sidebar-wrapper > nav > ul treeview AdminLTE.
      assert doc.at_css("div.sidebar-wrapper nav.mt-2 ul.nav.sidebar-menu.flex-column[data-lte-toggle='treeview']"),
             "menu treeview AdminLTE 4 com data-lte-toggle"

      # 3 níveis de profundidade: Presença → (Estação de Ponto/Relatório
      # Mensal) → netos.
      assert_equal 3, doc.css("ul.nav-treeview").count,
                   "deve haver 3 submenus treeview (Presença, Estação de Ponto, Relatório Mensal)"

      # Nível 3 (neto): "Explorar Estações"/"Explorar Versões" dentro do
      # treeview de "Estação de Ponto".
      estacao_ponto = doc.css("a.nav-link").find { |a| a.at_css("p")&.text&.strip == "Estação de Ponto" }
      assert estacao_ponto, "header de seção 'Estação de Ponto' deve existir"
      assert estacao_ponto.parent.at_css("ul.nav-treeview a[href='/estacoes']"),
             "neto 'Explorar Estações' dentro do treeview de Estação de Ponto"
      assert estacao_ponto.parent.at_css("ul.nav-treeview a[href='/versoes']"),
             "neto 'Explorar Versões' dentro do treeview de Estação de Ponto"
    end

    test "usa a convencao de icones fa-* sem reintroduzir bi-*" do
      login_como(criar_admin_por_role)
      html = sidebar_html
      doc = document(html)

      assert doc.at_css("i.nav-icon.fas.fa-gauge"), "Dashboard deve ter ícone FA"
      assert_equal 3, doc.css("i.nav-arrow.fas.fa-chevron-right").count,
                   "setas dos treeviews na convenção FA (uma por header de seção)"
      assert_nil doc.at_css("[class*='bi-']"), "partial não deve reintroduzir ícones bi-*"
    end

    # ----------------------------------------------------------------------
    # Navegação real (@static_menu da 26.1) e links mortos
    # ----------------------------------------------------------------------

    test "renderiza toda a navegacao real do @static_menu sem links mortos" do
      login_como(criar_admin_por_role)
      html = sidebar_html
      doc = document(html)

      hrefs = doc.css("a").filter_map { |a| a["href"] }
      [
        dashboard_path, time_records_path, users_path, frequentadores_path,
        estacoes_path, versoes_path, relatorio_terceirizados_path,
        frequencia_por_orgao_path, parcial_path, frequencia_path, regimes_path,
        direitos_deveres_path, gestores_individuais_path
      ].each do |rota|
        assert_includes hrefs, rota, "navegação real deve incluir #{rota}"
      end

      # Nenhum item-folha com href="#" (links mortos como o "Inicializar
      # Estação" do layout inline): todo <a href="#"> é header de seção com
      # <ul class="nav nav-treeview"> imediatamente após.
      dead_links = doc.css('a[href="#"]').reject { |a| a.next_element&.name == "ul" }
      assert_empty dead_links, "todo a[href='#'] deve ter ul treeview filho (header de seção)"
      assert_equal 3, doc.css('a[href="#"]').count,
                   "os únicos href='#' são os 3 headers de seção (Presença, Estação de Ponto, Relatório Mensal)"
    end

    # ----------------------------------------------------------------------
    # menu_activated? aplicado (active/menu-open)
    # ----------------------------------------------------------------------

    test "menu_activated? aplica active/menu-open na tela ativa (estacoes_path)" do
      login_como(criar_admin_por_role)
      html = sidebar_html(estacoes_path)
      doc = document(html)

      # Neto ativo: Explorar Estações (active_test "controller_name == 'estacoes'").
      explorar = doc.at_css("a[href='/estacoes']")
      assert explorar
      assert_includes explorar["class"], "active", "neto da tela ativa deve ter classe active"

      # Pai Estação de Ponto e avô Presença ganham menu-open (o pai também
      # recebe active porque menu_activated? avalia o próprio item).
      abertos = doc.css("li.nav-item.menu-open").to_h do |li|
        [ li.at_css("a.nav-link > p")&.text&.strip, li ]
      end
      assert abertos.key?("Presença"), "avô da tela ativa deve estar menu-open"
      assert abertos.key?("Estação de Ponto"), "pai da tela ativa deve estar menu-open"
      assert_includes abertos["Estação de Ponto"].at_css("a.nav-link")["class"], "active",
                      "pai da tela ativa também recebe active (menu_activated? no próprio item)"

      # Tela não ativa não recebe active indevidamente.
      dashboard_link = doc.at_css("a[href='#{dashboard_path}']")
      assert dashboard_link
      assert_not_includes dashboard_link["class"], "active", "Dashboard não deve estar ativo em estacoes"
    end

    test "menu_activated? marca Dashboard ativo em dashboard_path" do
      login_como(criar_admin_por_role)
      html = sidebar_html(dashboard_path)
      doc = document(html)

      dashboard_link = doc.at_css("a[href='#{dashboard_path}']")
      assert dashboard_link
      assert_includes dashboard_link["class"], "active", "Dashboard deve estar ativo na tela dashboard"
      assert_nil doc.at_css("li.nav-item.menu-open"), "nenhum treeview deve abrir em dashboard"
    end

    # ----------------------------------------------------------------------
    # Filtro por permissão em TODOS os níveis (ability 23.5)
    # ----------------------------------------------------------------------

    test "filtra o menu por permissao: admin ve tudo (incl. Usuarios), operador ve apenas leitura" do
      login_como(criar_admin_por_role)

      html_admin = sidebar_html
      assert_includes html_admin, "Usuários", "admin (manage em User) deve ver o item Usuários"
      assert_includes html_admin, "Dashboard"
      assert_includes html_admin, "Registros de Ponto"
      assert_includes html_admin, "Presença"

      trocar_usuario(criar_operador)

      html_operador = sidebar_html
      # Operador tem baseline `can :read, :all` (23.7): itens de leitura aparecem.
      assert_includes html_operador, "Dashboard"
      assert_includes html_operador, "Registros de Ponto"
      assert_includes html_operador, "Presença"
      assert_includes html_operador, "Explorar Estações"

      # `can?(:manage, User)` é false para operador → item filtrado.
      assert_not_includes html_operador, "Usuários",
                          "operador não gerencia User — item não deve aparecer no menu"

      # O filtro não quebra a estrutura: operador ainda recebe treeviews válidos.
      doc_operador = document(html_operador)
      assert_equal 3, doc_operador.css("ul.nav-treeview").count
      assert_empty doc_operador.css('a[href="#"]').reject { |a| a.next_element&.name == "ul" }
    end
  end
end
