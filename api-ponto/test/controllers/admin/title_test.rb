require "test_helper"

# Task 26.4 (Sprint 26) — partial `shared/_title` (breadcrumbs + badges de
# roles + box ícone 50×50 + auto-"Novo").
#
# Mesmo padrão das tasks 26.2/26.3: a 26.4 porta o partial EM ISOLAMENTO — o
# layout `admin.html.erb` ainda não compõe os partials `shared/*` (composição
# é a task 26.5). Para atender o critério "renderização em ação admin real",
# o partial é renderizado no `view_context` do controller que processou a
# action real de integração (esteira completa: router → require_login →
# set_configurations → breadcrumbs "Início" → CanCanCan → action). Isso expõe
# o stack real ao partial SEM antecipar a 26.5:
#   - `@app_name` das before_actions (task 26.1);
#   - `breadcrumbs.any?`/`crumb.path` (gem breadcrumbs_on_rails — task 26.6);
#   - `current_user`/roles (sessão, task 23) e ability (23.5);
#   - helpers `resource_icon`/`resource_human_name`/`eval_with_rescue` (26.1);
#   - rotas reais (`new_*_path`, `root_path`, `polymorphic_path`) e o partial
#     `shared/btn_action_links` da gem zutils (engine adiciona seus views ao
#     caminho de lookup).
#
# Comportamento real das views atuais × branches do partial: TODAS as views
# admin hoje executam `content_for :page_title` (ex.: regimes/index.html.erb)
# — mas `view_context` NÃO é memoizado (`action_view/rendering.rb:109`): cada
# chamada devolve instância nova com `view_flow` vazio (o contexto que
# renderizou a view real é descartado após a resposta). Por isso:
#   - `title_html` (contexto novo) já nasce SEM `page_title` — exercita o
#     branch do título (auto-"Novo"/`page_actions`/show), padrão das telas
#     que NÃO setam page_title (scaffolds da Sprint 25);
#   - o branch `page_title` (yield) é coberto por `title_html_com_view_real`:
#     a view real é renderizada e o partial é lido no MESMO view_context —
#     reproduz fielmente a composição de layout da 26.5 (layout renderiza a
#     view que popula o flow, depois renderiza os partials que leem o flow).
#
# Adaptações de teste (documentadas porque o Frequencia admin ainda não tem
# action `show` — os scaffolds da Sprint 25 a criarão):
#   - branch `show` exercitado com a action REAL `regimes#edit` (carrega o
#     objeto autorizado `@regime` via load_and_authorize_resource) + locals
#     `action_name: "show"` no render (local de ERB tem precedência sobre o
#     helper `action_name` delegado ao controller) — cobre `btn_action_links`;
#   - branch de fallback de breadcrumbs vazio exercitado com locals
#     `breadcrumbs: []` — hoje TODO controller admin herda o crumb "Início"
#     do Admin::ApplicationController, então a cadeia nunca está vazia em
#     ação real; o branch é coberto por override local para validar o
#     critério "@app_name → resource_human_name".
#
# Convenção de badges REUTILIZADA da task 26.3 (sem duplicação de decisão):
# TODAS as roles usam `text-bg-primary` (Bootstrap 5.3 — adaptação do
# `bg-primary` do fonte basic8; uma cor só, como no fonte).
module Admin
  class TitleTest < ActionDispatch::IntegrationTest
    # ----------------------------------------------------------------------
    # Helpers (mesmo padrão dos demais arquivos de teste admin)
    # ----------------------------------------------------------------------

    def criar_usuario(nome_completo:)
      User.create!(nome_completo: nome_completo, password: "123456")
    end

    def criar_admin_por_role
      criar_usuario(nome_completo: "Admin Title Teste").tap do |user|
        user.add_role(:admin)
      end
    end

    def criar_usuario_multirroles
      criar_usuario(nome_completo: "Gestor Title Teste").tap do |user|
        user.add_role(:admin)
        user.add_role(:gestor)
      end
    end

    def criar_usuario_sem_roles
      criar_usuario(nome_completo: "Usuário Sem Roles Title Teste")
    end

    def login_como(user)
      post login_path, params: { username: user.username, password: "123456" }
      assert_response :redirect
      follow_redirect!
    end

    # Ação admin REAL (default: regimes_path) + render do partial no view_context
    # do controller que processou. NOTA: `ActionView::Rendering#view_context`
    # (actionview-8.0.5/lib/action_view/rendering.rb:109) NÃO é memoizado —
    # cada chamada devolve instância NOVA, com `view_flow` vazio. Ou seja: o
    # contexto que renderizou a view real é descartado após a resposta, e
    # todo chamado começa limpo (sem content_for residual — nenhum reset
    # necessário; o view_flow só recebe o que ESCRIVEMOS nesta chamada).
    def title_html(caminho = regimes_path, **render_opts)
      get caminho
      assert_response :success
      @controller.view_context.render(partial: "shared/title", **render_opts)
    end

    # Composição real 26.5 (mesmo view_context): o template da view admin é
    # renderizado primeiro (executa o `content_for :page_title` real da view
    # em seu próprio flow) e, no MESMO contexto, o partial do layout é
    # renderizado em seguida — reproduz fielmente como o layout lerá o título
    # quando a 26.5 compuser shared/_title (layout → yield content_for).
    def title_html_com_view_real(caminho = regimes_path, template:)
      get caminho
      assert_response :success
      vc = @controller.view_context
      vc.render(template: template) # view real popula o view_flow (content_for)
      vc.render(partial: "shared/title") # partial lê o flow do MESMO contexto
    end

    def document(html)
      Nokogiri::HTML.fragment(html)
    end

    # ----------------------------------------------------------------------
    # Breadcrumbs (gem breadcrumbs_on_rails — 26.6) + box ícone 50×50 + h1 +
    # auto-"Novo" (index com rota new existente)
    # ----------------------------------------------------------------------

    test "porta breadcrumbs, box icone 50x50, h1 e botao Novo automatico (index com rota new existente)" do
      login_como(criar_admin_por_role)
      html = title_html(regimes_path)
      doc = document(html)

      # Estrutura AdminLTE 4 (app-content-header + breadcrumb do fonte).
      assert doc.at_css("div.app-content-header"), "título dentro de div.app-content-header (AdminLTE 4)"
      ol = doc.at_css("ol.breadcrumb.mb-0.text-muted.bg-transparent")
      assert ol, "breadcrumb com as classes do fonte basic8"

      # Breadcrumbs: cadeia com o crumb 'Início' (gem breadcrumbs_on_rails —
      # task 26.6; add_breadcrumb "Início", :root_path no Admin::ApplicationController).
      crumbs = ol.css("li.breadcrumb-item")
      assert_equal 1, crumbs.count, "admin herda apenas o crumb 'Início'"
      primeiro = crumbs.first
      assert_includes primeiro["class"], "active", "crumb único recebe active (crumb == breadcrumbs.last)"
      assert primeiro.at_css("a.fw-bold[href='#{root_path}']"), "crumb 'Início' linka à raiz (crumb.path :root_path → send)"
      assert_includes primeiro.text, "API Ponto TJPI", "@app_name como texto do crumb inicial (task 26.1)"

      # Box ícone 50×50 com resource_icon (26.1).
      box = doc.at_css("div.text-primary.bg-primary.bg-opacity-10[style='width: 50px; height: 50px;']")
      assert box, "box do ícone com as dimensões 50×50 em linha (fonte basic8)"
      icone = box.at_css("i.fs-3")
      assert icone, "ícone do recurso dentro do box"
      assert_includes icone["class"], "fa-fw fa-cube", "resource_icon(controller_name) → ApplicationRecord.icon (26.1)"

      # h1: resource_human_name; no index o título de ação NÃO é concatenado
      # (fonte basic8: unless action_name == 'index').
      h1 = doc.at_css("h1.m-0.h4")
      assert h1 && h1.text.squish == "Regimes", "h1 com resource_human_name (plural no index)"

      # Auto-"Novo": rota new_regime_path existe → botão "Cadastrar Regime".
      botao = doc.at_css("a.btn.btn-primary.btn-sm[href='#{new_regime_path}']")
      assert botao, "botão Novo aparece quando a rota new_*_path existe"
      assert botao.at_css("i.fa.fa-plus"), "botão Novo com ícone de adição"
      assert_includes botao.text, "Cadastrar", "t('helpers.titles.new') = Cadastrar"
      assert_includes botao.text, "Regime", "recurso singularizado (Regimes → Regime)"
    end

    test "index sem rota new_path nao renderiza o botao Novo" do
      login_como(criar_admin_por_role)
      html = title_html(time_records_path)
      doc = document(html)

      # TimeRecord não tem rota new (resources :time_records, only: [:index]) →
      # eval_with_rescue devolve "error" → botão omitido (critério 26.4).
      assert_nil doc.at_css("a.btn.btn-sm.btn-primary"), "sem rota new_*_path o auto-Novo não aparece"
      assert_nil doc.at_css("a[href='/time_records/new']"), "nenhum link para rota inexistente"
    end

    # ----------------------------------------------------------------------
    # Branch real (composição 26.5): views com content_for :page_title
    # ----------------------------------------------------------------------

    test "view atual com content_for :page_title renderiza o titulo da pagina (yield) sem o bloco icone/acoes" do
      login_como(criar_admin_por_role)

      # Composição real: o MESMO view_context renderiza regimes/index.html.erb
      # — que executa `content_for :page_title, "Gerência de Regimes"` (linha 1
      # da view) — e depois o partial (como o layout fará na 26.5).
      html = title_html_com_view_real(regimes_path, template: "admin/regimes/index")
      doc = document(html)

      assert_includes html, "Gerência de Regimes", "yield :page_title preserva o título real da view"
      assert_nil doc.at_css("h1.m-0.h4"), "view com page_title não renderiza o bloco ícone+h1 do fonte"
      assert_nil doc.at_css("a.btn.btn-sm.btn-primary"), "view com page_title não renderiza o auto-Novo"

      # A linha superior (breadcrumbs + badges + home) continua presente —
      # ela fica fora do bloco condicional do título.
      assert doc.at_css("ol.breadcrumb"), "breadcrumbs permanecem com view de page_title"
      assert doc.at_css("a.bg-light.fw-bold.rounded.px-1"), "atalho home permanece com view de page_title"
    end

    # ----------------------------------------------------------------------
    # Ações: content_for(:page_actions) respeitado (prioridade sobre auto-Novo)
    # ----------------------------------------------------------------------

    test "content_for :page_actions e respeitado e tem prioridade sobre o auto-Novo" do
      login_como(criar_admin_por_role)
      get regimes_path
      assert_response :success

      # view_context novo (action_view/rendering.rb:109): flow vazio — setamos
      # o comportamento real que uma tela customizada (sem page_title) teria.
      vc = @controller.view_context
      vc.content_for(:page_actions) { "<a href='/custom' class='btn btn-custom'>Ação Custom</a>".html_safe }
      html = vc.render(partial: "shared/title")
      doc = document(html)

      assert doc.at_css("a.btn-custom[href='/custom']"),
             "content_for(:page_actions) deve ser renderizado (yield :page_actions)"
      assert_nil doc.at_css("a.btn.btn-sm.btn-primary"),
                 "com page_actions presente o auto-Novo não é renderizado (fonte basic8: elsif)"
    end

    # ----------------------------------------------------------------------
    # Branch `show`: shared/btn_action_links da zutils (labels false, size sm,
    # hide: ['show']) — sem action admin `show` real ainda (scaffolds Sprint 25)
    # ----------------------------------------------------------------------

    test "show renderiza shared/btn_action_links da zutils sem o botao Ver" do
      login_como(criar_admin_por_role)
      regime = Regime.create!(nome: "Jornada Title")

      # Action admin REAL que carrega o objeto autorizado: regimes#edit
      # (load_and_authorize_resource — CanCan autoriza :edit para admin).
      get edit_regime_path(regime)
      assert_response :success

      html = @controller.view_context.render(
        partial: "shared/title",
        locals: { action_name: "show" } # local de ERB > helper delegado (adaptação documentada)
      )
      doc = document(html)

      # h1 com título de ação traduzido + recurso (26.1: helper sempre plural).
      h1 = doc.at_css("h1.m-0.h4")
      assert h1 && h1.text.squish == "Ver Regimes", "h1 = t('helpers.titles.show') + resource_human_name"

      # btn_action_links (zutils): Voltar + Editar + Cadastrar + Apagar; o
      # 'show' é escondido via hide: ['show'].
      assert_equal 3, doc.css("a.btn").count, "3 links de ação (Voltar, Editar, Cadastrar)"
      assert doc.at_css("a.btn.btn-sm.btn-link[href='#{regimes_path}']"),
             "Voltar → polymorphic_path(object.class) (lado esquerdo, btn-link)"
      assert doc.at_css("a.btn.btn-sm.btn-warning[href='#{edit_regime_path(regime)}']"),
             "Editar → edit_polymorphic_path(object)"
      assert doc.at_css("a.btn.btn-sm.btn-primary[href='#{new_regime_path}']"),
             "Cadastrar → new_polymorphic_path(object.class)"

      form = doc.at_css("form.button_to[action='#{regime_path(regime)}']")
      assert form, "Apagar → button_to polimórfico (DELETE)"
      assert form.at_css("input[name='_method'][value='delete']"), "form com _method=delete"
      assert_empty doc.css("i.fa-eye"), "botão Ver escondido (hide: ['show'])"
    end

    # ----------------------------------------------------------------------
    # Badges de roles com a convenção text-bg-* (26.3 — reutilizada, sem
    # duplicação de decisão)
    # ----------------------------------------------------------------------

    test "badges de roles usam a convencao text-bg-primary da task 26.3" do
      login_como(criar_usuario_multirroles)
      html = title_html(regimes_path)
      doc = document(html)

      badges = doc.css("div.d-flex.align-items-center.gap-1 span.badge.text-bg-primary")
      assert_equal 2, badges.count, "uma badge por role (admin + gestor)"
      assert_equal %w[admin gestor], badges.map { |b| b.text.strip }.sort,
                   "badges exibem role.name"
      assert_empty doc.css("span.badge.bg-primary"),
                   "badges não devem usar a classe antiga bg-primary (convenção 26.3 é text-bg-*)"
    end

    test "usuario sem roles renderiza o titulo sem badges e sem quebrar" do
      login_como(criar_usuario_sem_roles)
      html = title_html(regimes_path)
      doc = document(html)

      assert_equal 0, doc.css("span.badge").count, "sem roles nenhuma badge é renderizada"
      assert doc.at_css("h1.m-0.h4"), "título continua renderizando"
      assert doc.at_css("a.bg-light.fw-bold.rounded.px-1"), "atalho home continua presente"
    end

    # ----------------------------------------------------------------------
    # Return early: sessions/dashboard não renderizam o título
    # ----------------------------------------------------------------------

    test "sessions e dashboard nao renderizam o titulo (return early)" do
      login_como(criar_admin_por_role)

      # dashboard — action admin real (controller_name 'dashboard').
      get dashboard_path
      assert_response :success
      assert @controller.view_context.render(partial: "shared/title").blank?,
             "dashboard não deve renderizar o título"

      # sessions — action real de login (controller_name 'sessions'; login page
      # acessível sem sessão — skip_before_action :require_login).
      delete logout_path
      get login_path
      assert_response :success
      assert @controller.view_context.render(partial: "shared/title").blank?,
             "sessions não deve renderizar o título"
    end

    # ----------------------------------------------------------------------
    # Fallback de breadcrumbs vazio (@app_name → resource_human_name)
    # ----------------------------------------------------------------------

    test "breadcrumbs vazios usam fallback @app_name -> resource_human_name" do
      login_como(criar_admin_por_role)

      # Todos os controllers admin herdam o crumb 'Início' (26.6) — a cadeia
      # nunca está vazia em ação real; o branch de fallback é exercitado com
      # locals breadcrumbs: [] (local de ERB sombreia o helper da gem).
      html = title_html(regimes_path, locals: { breadcrumbs: [] })
      doc = document(html)

      ol = doc.at_css("ol.breadcrumb")
      itens = ol.css("li.breadcrumb-item")
      assert_equal 2, itens.count, "fallback: crumb @app_name + crumb ativo do recurso"
      primeiro = itens[0]
      assert primeiro.at_css("a.fw-bold[href='#{root_path}']"), "fallback linka @app_name à raiz"
      assert_includes primeiro.text, "API Ponto TJPI", "@app_name no primeiro crumb"
      assert_includes itens[1]["class"], "active", "segundo crumb é o ativo"
      assert_equal "Regimes", itens[1].text.strip,
                   "recurso atual como crumb ativo (resource_human_name)"
    end
  end
end
