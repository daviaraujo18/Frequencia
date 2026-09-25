require "test_helper"

# Task 26.3 (Sprint 26) — partial `shared/_header` (navbar com marca central +
# dropdown de usuário com badges de roles).
#
# Mesmo padrão da task 26.2 (`sidebar_test.rb`): a 26.3 porta o partial EM
# ISOLAMENTO — o layout `admin.html.erb` ainda não compõe os partials
# `shared/*` (composição é a task 26.5). Para atender o critério "teste
# estrutural no HTML admin real", o partial é renderizado no `view_context` do
# controller que processou a action real de integração (esteira completa:
# router → require_login → set_configurations → CanCanCan → action). Isso
# expõe o stack real ao partial SEM antecipar a 26.5:
#   - `@app_icon`/`@app_name` das before_actions (task 26.1);
#   - `current_user` (helper_method do Admin::ApplicationController — fonte de
#     verdade da sessão: `session[:user_id]`/Warden, task 23);
#   - `role.name` das roles Rolify (ability 23.5) e rotas reais
#     (`logout_path` RN06, `root_path`).
#
# Convenção de badges registrada na task e reutilizada na 26.4: TODAS as roles
# usam `text-bg-primary` (Bootstrap 5.3 — adaptação do `bg-primary` do fonte
# basic8; uma cor só, como no fonte). Usuário sem roles → dropdown renderiza
# sem badges, sem quebrar.
module Admin
  class HeaderTest < ActionDispatch::IntegrationTest
    # ----------------------------------------------------------------------
    # Helpers (mesmo padrão dos demais arquivos de teste admin)
    # ----------------------------------------------------------------------

    def criar_usuario(nome_completo:, email: nil)
      User.create!(nome_completo: nome_completo, password: "123456", email: email)
    end

    def criar_admin_por_role
      criar_usuario(nome_completo: "Admin Header Teste").tap do |user|
        user.add_role(:admin)
      end
    end

    def criar_usuario_sem_roles
      criar_usuario(nome_completo: "Usuário Sem Roles Header Teste")
    end

    def criar_usuario_multirroles
      criar_usuario(nome_completo: "Gestor Header Teste", email: "gestor@teste.local").tap do |user|
        user.add_role(:admin)
        user.add_role(:gestor)
      end
    end

    def login_como(user)
      post login_path, params: { username: user.username, password: "123456" }
      assert_response :redirect
      follow_redirect!
    end

    # Ação admin REAL (default: dashboard_path) e render do partial no
    # view_context do controller que processou — o mesmo contexto que a view
    # admin usará quando a 26.5 compuser o layout.
    def header_html(caminho = dashboard_path)
      get caminho
      assert_response :success
      @controller.view_context.render(partial: "shared/header")
    end

    def document(html)
      Nokogiri::HTML.fragment(html)
    end

    # ----------------------------------------------------------------------
    # Estrutura AdminLTE 4 + marca central + toggle sidebar (preserva
    # sidebar_controller.js) + dropdown de tema (sem duplicação)
    # ----------------------------------------------------------------------

    test "porta a estrutura AdminLTE 4 com marca central e toggle da sidebar preservando o controller Stimulus" do
      login_como(criar_admin_por_role)
      html = header_html
      doc = document(html)

      # Header AdminLTE 4 no visual do basic8 (`bg-primary` + dark).
      nav = doc.at_css("nav.app-header.navbar.navbar-expand.bg-primary[data-bs-theme='dark']")
      assert nav, "header deve ser a nav.app-header do AdminLTE 4 com bg-primary/dark (visual basic8)"

      # Toggle da sidebar: AdminLTE nativo + sidebar_controller.js existente
      # (preservado — data-controller + data-action do layout atual, task 24.8).
      toggle = doc.at_css("a.nav-link[data-lte-toggle='sidebar'][data-controller='sidebar'][data-action='click->sidebar#toggle']")
      assert toggle, "toggle deve usar data-lte-toggle (AdminLTE) + data-controller/data-action (sidebar_controller.js)"
      assert_includes toggle["aria-label"], "Alternar menu lateral", "aria-label em pt-BR (RNF03)"

      # Marca central: @app_icon + @app_name via link_to root_path (task 26.1).
      marca = doc.at_css("li.nav-item.flex-grow-1.text-center a.nav-link[href='#{root_path}']")
      assert marca, "marca central deve linkar à raiz (root_path)"
      assert marca.at_css("i.me-2.#{ApplicationRecord.icon.tr(' ', '.')}"),
             "marca deve exibir o ícone de @app_icon (ApplicationRecord.icon)"
      strong = marca.at_css("strong")
      assert strong && strong.text.strip == "API Ponto TJPI", "marca deve exibir @app_name ('API Ponto TJPI')"
    end

    test "dropdown de tema usa o theme_controller sem duplicar markup" do
      login_como(criar_admin_por_role)
      html = header_html
      doc = document(html)

      # Único dropdown de tema no partial (extração limpa — sem duplicação).
      icone_tema = doc.css("[data-theme-target='icon']")
      assert_equal 1, icone_tema.count, "deve haver exatamente 1 ícone de tema (sem markup duplicado)"
      assert icone_tema.first["class"].include?("fas fa-sun")

      # 3 modos: um botão para cada (light/dark/auto).
      botoes = doc.css("button[data-action='theme#pick']").to_h do |b|
        [ b["data-theme-mode-param"], b.text.strip ]
      end
      assert_equal %w[light dark auto].sort, botoes.keys.sort, "dropdown deve oferecer claro/escuro/automático"
      assert_equal "Claro", botoes["light"]
      assert_equal "Escuro", botoes["dark"]
      assert_equal "Automático", botoes["auto"]
      assert_equal 3, doc.css("button[data-action='theme#pick']").count,
                   "exatamente 3 botões de tema (um por modo)"

      # Dropdown menu alinhado à direita com popper estático (fiel ao fonte/layout atual).
      assert doc.at_css("div.dropdown-menu.dropdown-menu-end[data-bs-popper='static']"),
             "menu de tema com dropdown-menu-end e data-bs-popper estático"
    end

    # ----------------------------------------------------------------------
    # Dropdown do usuário: nome/email + badges de roles (convenção text-bg-*)
    # ----------------------------------------------------------------------

    test "dropdown do usuario mostra nome_completo, email e badges de roles (text-bg-primary)" do
      login_como(criar_usuario_multirroles)
      html = header_html
      doc = document(html)

      dropdown = doc.at_css("div.dropdown-menu.dropdown-menu-end.dropdown-menu-lg.p-2")
      assert dropdown, "dropdown do usuário com as classes AdminLTE/Bootstrap do fonte"

      # Nome: current_user.try(:nome_completo) — model User do Frequencia.
      nome = dropdown.at_css("div.fw-semibold.text-sm")
      assert nome && nome.text.strip == "Gestor Header Teste", "dropdown deve exibir nome_completo"

      # Email quando houver.
      email = dropdown.at_css("div.text-muted.small")
      assert email && email.text.strip == "gestor@teste.local", "dropdown deve exibir o email quando presente"

      # Badges de roles: uma por role, com a convenção text-bg-* (Bootstrap 5.3).
      badges = dropdown.css("span.badge.text-bg-primary")
      assert_equal 2, badges.count, "uma badge por role (admin + gestor)"
      names = badges.map { |b| b.text.strip }.sort
      assert_equal %w[admin gestor], names, "badges devem exibir role.name"
      assert_empty dropdown.css("span.badge.bg-primary"),
                   "badges não devem usar a classe antiga bg-primary (convenção é text-bg-*)"
    end

    test "usuario sem roles nem email renderiza o dropdown sem quebrar" do
      login_como(criar_usuario_sem_roles)
      html = header_html
      doc = document(html)

      dropdown = doc.at_css("div.dropdown-menu.dropdown-menu-end.dropdown-menu-lg.p-2")
      assert dropdown, "dropdown do usuário deve existir mesmo sem roles/email"

      # Nome ainda aparece (nome_completo NOT NULL no User).
      nome = dropdown.at_css("div.fw-semibold.text-sm")
      assert nome && nome.text.strip == "Usuário Sem Roles Header Teste"

      # Sem email → linha de email não é renderizada (nada enganoso como
      # "Não autenticado" para usuário logado).
      assert_nil dropdown.at_css("div.text-muted.small"), "sem email a linha não deve aparecer"

      # Sem roles → zero badges, estrutura do dropdown preservada.
      assert_equal 0, dropdown.css("span.badge").count, "sem roles nenhuma badge é renderizada"
      assert dropdown.at_css("div.dropdown-divider"), "divisor do logout preservado"
      assert dropdown.at_css("form.button_to"), "logout ainda presente"
    end

    # ----------------------------------------------------------------------
    # Logout via button_to logout_path (RN06 — delete /logout)
    # ----------------------------------------------------------------------

    test "logout usa button_to logout_path com method delete (RN06)" do
      login_como(criar_admin_por_role)
      html = header_html
      doc = document(html)

      # button_to gera <form action="/logout" method="post"> com input
      # _method=delete (adaptação do destroy_user_session_path do basic8).
      form = doc.at_css("form.button_to[action='#{logout_path}']")
      assert form, "logout deve ser um form button_to apontando para logout_path (RN06)"
      assert_equal "post", form["method"], "button_to usa method post com _method=delete (padrão Rails)"
      method_input = form.at_css("input[name='_method'][value='delete']")
      assert method_input, "form deve carregar _method=delete"

      botao = form.at_css("button[type='submit'].dropdown-item.dropdown-footer")
      assert botao, "botão de logout com as classes dropdown-item/dropdown-footer do fonte"
      assert_includes botao.text, "Sair", "botão deve rotular 'Sair'"
      assert botao.at_css("i.fas.fa-sign-out-alt"), "botão com ícone de saída do fonte"
      assert_equal "Confirmar saída?", botao["data-turbo-confirm"],
                   "turbo_confirm em pt-BR mantido do fonte (RNF03)"
    end
  end
end
