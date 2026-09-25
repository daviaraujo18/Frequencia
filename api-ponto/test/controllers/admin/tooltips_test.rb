require "test_helper"

# Task 26.10 (Sprint 26) — porta do `tooltips()` do basic8 para o entry JS do
# Frequencia (FASE 3 — Bibliotecas JS/UX do layout).
#
# Contexto de runtime: o Frequencia usa importmap (SEM esbuild/npm na runtime).
# O importmap pina "bootstrap" para o bundle UMD `bootstrap.bundle.min.js`
# (config/importmap.rb), que NÃO expõe named exports ES e define o global
# `window.bootstrap` ao ser avaliado pelo entry `application.js` (import
# side-effect). O Stimulus NÃO está no runtime (importmap sem pins de
# stimulus/turbo — os controllers sidebar/theme são inertes), então a porta
# usa o "equivalente compatível com importmap" do critério: módulo ESM puro
# (`app/javascript/src/functions.js`) importado pelo entry, com inicialização
# no top-level (módulos ES são deferred — DOM já parseado).
#
# Como o projeto NÃO tem Capybara/Selenium (risco 🟢 registrado na sprint), a
# validação é ESTRUTURAL + nota de verificação manual/browser pendente no
# iteration_26.md:
#   1. o módulo de tooltips existe e consome `window.bootstrap.Tooltip` (o
#      global exposto pelo pin UMD — sem duplicar o importmap);
#   2. o entry `application.js` importa o módulo APÓS `import "bootstrap"`
#      (ordem garante o global);
#   3. o importmap permanece com UM ÚNICO pin de "bootstrap" (sem duplicação);
#   4. o HTML admin REAL (via `shared/btn_action_links` da zutils no branch
#      `show` do `shared/_title`, task 26.4) contém elementos
#      `[data-bs-toggle="tooltip"]` — o alvo que o `tooltips()` inicializa nas
#      telas da Sprint 25;
#   5. o layout admin serve o entry `application` via `javascript_importmap_tags`
#      (o módulo de tooltips só roda se o entry for carregado).
module Admin
  class TooltipsTest < ActionDispatch::IntegrationTest
    # ----------------------------------------------------------------------
    # Helpers (mesmo padrão dos demais arquivos de teste admin)
    # ----------------------------------------------------------------------

    def criar_usuario(nome_completo:)
      User.create!(nome_completo: nome_completo, password: "123456")
    end

    def criar_admin_por_role
      criar_usuario(nome_completo: "Admin Tooltips Teste").tap do |user|
        user.add_role(:admin)
      end
    end

    def login_como(user)
      post login_path, params: { username: user.username, password: "123456" }
      assert_response :redirect
      follow_redirect!
    end

    def document(html)
      Nokogiri::HTML.fragment(html)
    end

    def fonte_javascript(relativo)
      File.read(Rails.root.join("app/javascript", relativo))
    end

    # ----------------------------------------------------------------------
    # 1. Módulo de tooltips: API `window.bootstrap.Tooltip` + dispose turbo
    # ----------------------------------------------------------------------

    test "functions module exposes tooltips via window.bootstrap and dispose on turbo events" do
      fonte = fonte_javascript("src/functions.js")

      assert_includes fonte, 'querySelectorAll(\'[data-bs-toggle="tooltip"]\')',
                      "tooltips() varre os disparadores data-bs-toggle=tooltip (fonte basic8)"
      assert_includes fonte, "new window.bootstrap.Tooltip",
                      "usa o global exposto pelo bundle UMD pinado no importmap (SEM re-pin)"
      assert_includes fonte, "disposeTooltips",
                      "dispose exportado (dispose() em cada instância)"
      assert_includes fonte, '"turbo:before-cache"',
                      "dispose registrado em turbo:before-cache (fonte basic8)"
      assert_includes fonte, '"turbo:before-visit"',
                      "dispose registrado em turbo:before-visit (fonte basic8)"
      assert_includes fonte, "tooltips()",
                      "inicialização no top-level (equivalente do connect() do Stimulus)"
    end

    # ----------------------------------------------------------------------
    # 2. Entry importa o módulo após o bootstrap (ordem do global)
    # ----------------------------------------------------------------------

    test "entry application.js imports functions after bootstrap" do
      entry = fonte_javascript("application.js")

      assert_includes entry, 'import "src/functions"',
                      "entry importa o módulo de tooltips (specifier bare pinado no importmap)"
      bootstrap_index = entry.index('import "bootstrap"')
      functions_index = entry.index('import "src/functions"')
      assert bootstrap_index && functions_index && bootstrap_index < functions_index,
             "bootstrap (global window.bootstrap) avaliado ANTES do módulo de tooltips"
    end

    # ----------------------------------------------------------------------
    # 3. Importmap: um único pin de bootstrap (sem duplicação) + pin do módulo
    #    local via pin_all_from (padrão nativo importmap)
    # ----------------------------------------------------------------------

    test "importmap keeps single bootstrap pin and pins src module locally" do
      importmap = File.read(Rails.root.join("config", "importmap.rb"))
      functions = fonte_javascript("src/functions.js")

      assert_equal 1, importmap.scan(/pin "bootstrap"/).size,
                   "exatamente um pin de bootstrap no importmap (o UMD existente)"
      assert_includes importmap, "bootstrap.bundle.min.js",
                      "o pin aponta para o bundle UMD (define window.bootstrap global)"
      assert_includes importmap, 'pin_all_from "app/javascript/src", under: "src"',
                      "módulo local pinado via pin_all_from (sem esbuild — padrão importmap)"
      # O módulo não executa NENHUM import (o comentário do cabeçalho cita o
      # `import * as bootstrap` do FONTE — por isso o match é em início de
      # linha de código, não substring do comentário).
      refute functions.match?(/^import .*bootstrap/m),
             "módulo não importa bootstrap (usa o global window.bootstrap)"
      refute functions.match?(/^import /m),
             "módulo não executa nenhum import (zero dependências novas)"
    end

    # ----------------------------------------------------------------------
    # 4. HTML admin real: btn_action_links da zutils gera os disparadores
    #    [data-bs-toggle="tooltip"] (alvo do tooltips() nas telas Sprint 25)
    # ----------------------------------------------------------------------

    test "btn_action_links renders tooltip triggers in real admin html (title show)" do
      login_como(criar_admin_por_role)
      regime = Regime.create!(nome: "Jornada Tooltips")

      # Mesmo padrão da 26.4 (teste show): action admin REAL que carrega o
      # objeto autorizado (regimes#edit — load_and_authorize_resource) +
      # render do partial no view_context com locals action_name: "show"
      # (adaptação documentada na 26.4 — sem action show admin real ainda).
      get edit_regime_path(regime)
      assert_response :success

      html = @controller.view_context.render(
        partial: "shared/title",
        locals: { action_name: "show" }
      )
      doc = document(html)

      disparadores = doc.css('[data-bs-toggle="tooltip"]')
      assert_operator disparadores.count, :>=, 3,
                      "Voltar/Editar/Cadastrar (btn_action_links com hide:['show']) geram data-bs-toggle=tooltip"
      assert disparadores.all? { |el| el["data-bs-title"].present? },
             "todo disparador tem data-bs-title (label do tooltip — zutils)"
      assert_includes html, 'data-bs-title="Voltar"',
                      "tooltip do Voltar apresenta o label pt-BR (RNF03)"
    end

    # ----------------------------------------------------------------------
    # 5. Layout admin serve o entry via importmap (tooltips só rodam se o
    #    entry for carregado)
    # ----------------------------------------------------------------------

    test "admin layout serves the application entry via importmap tags" do
      login_como(criar_admin_por_role)

      get dashboard_path
      assert_response :success
      assert_match(/type="importmap"/, response.body,
                   "layout admin emite as importmap tags (26.5 renderiza javascript_importmap_tags)")
      assert_match(/"application":/, response.body,
                   "o mapa importa o entry application (módulo de tooltips incluído no entry)")
      assert_match(/"src\/functions":/, response.body,
                   "o mapa importa o pin src/functions gerado por pin_all_from (specifier bare do entry resolve)")
    end
  end
end
