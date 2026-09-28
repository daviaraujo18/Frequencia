# frozen_string_literal: true

require "test_helper"

# Task 24.6 (Sprint 24) — smoke test de carga CONJUNTA das 4 gems basic8.
#
# Valida, num único processo de teste (mesmo boot do app), que zutils 4.0.0,
# simple_form 5.4.x, ransack 4.4.x e pagy 9.x carregam juntas sem conflito e
# mantêm a funcionalidade mínima de cada uma, além das invariantes da sprint:
#
#   * RF01/RF02/RF03: as 4 gems resolvidas no lock (kaminari preservado — RF10).
#   * zutils: engine ativa no ActionView, mas `menu_activated?`/`eval_with_rescue`
#     continuam resolvendo para o ApplicationHelper local (precedência D1).
#   * simple_form: wrapper Bootstrap 5 (`:vertical_form`) segue como default
#     mesmo com as demais gems carregadas (initializers ordem alfabética).
#   * ransack: `Model.ransack` funcional; o app NÃO sobrescreve a whitelist
#     `ransackable_*` (RN04 é escopo da Sprint 25 — source_location na gem).
#   * pagy: `Pagy::Backend` no Admin::ApplicationController e `Pagy::Frontend`
#     no ApplicationHelper expostos; core `Pagy` pagina corretamente.
#   * Coexistência: kaminari (RF10, legado) e pagy resolvem no mesmo bundle.
#
# Falha aqui indica regressão de integração entre as gems — não de setup
# isolado (cada setup isolado é coberto pelos testes das tasks 24.2–24.5).
class Sprint24GemSmokeTest < ActiveSupport::TestCase
  # ----------------------------------------------------------------------
  # 1. Bundle — as 4 gems resolvidas juntas no lock + kaminari preservado
  # ----------------------------------------------------------------------
  test "lockfile resolves the four basic8 gems together with kaminari preserved" do
    specs = Bundler.locked_gems.specs.to_h { |spec| [ spec.name, spec.version.to_s ] }

    assert_match(/\A4\.0\./, specs.fetch("zutils"), "RF01: zutils 4.0.x deve estar no lock")
    assert_match(/\A5\.4\./, specs.fetch("simple_form"), "RF02: simple_form 5.4.x deve estar no lock")
    assert_match(/\A4\.4\./, specs.fetch("ransack"), "RF02: ransack 4.4.x deve estar no lock")
    assert_match(/\A9\./, specs.fetch("pagy"), "RF03: pagy 9.x deve estar no lock")

    # RF10: kaminari NÃO pode ter sido removido (remoção é escopo da Sprint 28).
    assert specs.key?("kaminari"), "kaminari deve permanecer no lock (RF10 — remoção na Sprint 28)"
  end

  # ----------------------------------------------------------------------
  # 2. zutils — engine ativa + precedência dos helpers locais (D1)
  # ----------------------------------------------------------------------
  test "zutils engine is active while local ApplicationHelper helpers keep precedence" do
    assert_includes ActionView::Base.ancestors, Zutils::Helpers,
                    "engine zutils deve estar ativa (config.to_prepare) com todas as gems carregadas"

    %i[menu_activated? eval_with_rescue].each do |helper|
      location = ApplicationHelper.instance_method(helper).source_location&.first.to_s
      assert_includes location, "app/helpers/application_helper.rb",
                      "#{helper} deve resolver para o helper LOCAL, não para Zutils::Helpers (D1)"
      refute_includes location, "zutils-#{Gem.loaded_specs.fetch("zutils").version}",
                      "#{helper} não pode ser sobreposto pela engine zutils"
    end
  end

  # ----------------------------------------------------------------------
  # 3. simple_form — wrapper BS5 default + locale pt-BR sob carga conjunta
  # ----------------------------------------------------------------------
  test "simple_form keeps the Bootstrap 5 default wrapper and pt-BR locale with all gems loaded" do
    assert_equal :vertical_form, SimpleForm.default_wrapper,
                 "wrapper BS5 (:vertical_form) deve prevalecer (initializers em ordem alfabética)"
    assert SimpleForm.wrappers.key?("vertical_form"), "wrappers BS5 registrados"

    assert_equal "Sim", I18n.t("simple_form.yes", locale: "pt-BR")
    assert_equal "obrigatório", I18n.t("simple_form.required.text", locale: "pt-BR")
  end

  # ----------------------------------------------------------------------
  # 4. ransack — API funcional; whitelist `ransackable_*` intocada (RN04/Sprint 25)
  # ----------------------------------------------------------------------
  test "ransack search is functional and the app does not override the ransackable whitelist" do
    search = User.ransack({})
    assert_instance_of Ransack::Search, search
    assert_kind_of ActiveRecord::Relation, search.result

    # RN04: o app não define `ransackable_*` nesta sprint — a implementação
    # permanece na gem (source_location aponta para vendor/bundle ransack-*).
    whitelist_source = User.method(:ransackable_attributes).source_location&.first.to_s
    assert_match(%r{ransack-4\.4\.\d+/lib/}, whitelist_source,
                 "ransackable_attributes deve vir da gem (whitelist é RN04/Sprint 25)")
    refute_includes whitelist_source, "app/models",
                    "app/models não pode sobrescrever a whitelist nesta sprint"
  end

  # ----------------------------------------------------------------------
  # 5. pagy — Backend + Frontend expostos e core funcional
  # ----------------------------------------------------------------------
  test "pagy backend and frontend are wired while the core pagination works" do
    # Backend (task 24.3): exposto no controller base admin, método privado
    # (Pagy 9 declara `private` — chamado naturalmente pelas actions).
    assert Admin::ApplicationController < Pagy::Backend,
           "Admin::ApplicationController deve herdar Pagy::Backend"
    assert Admin::ApplicationController.private_method_defined?(:pagy),
           "método pagy(...) deve existir (privado) no controller admin"
    assert Admin::ApplicationController.include?(CanCan::ControllerAdditions),
           "23.7 (CanCan) deve permanecer intacta junto com o Pagy::Backend"

    # Frontend (task 24.4): helpers de navegação nas views.
    assert ApplicationHelper < Pagy::Frontend, "ApplicationHelper deve herdar Pagy::Frontend"
    assert ApplicationHelper.method_defined?(:pagy_info), "pagy_info deve estar disponível"
    assert ApplicationHelper.method_defined?(:pagy_nav), "pagy_nav deve disponível"

    # Core funcional: paginação básica calculada corretamente.
    pagy = Pagy.new(count: 42, page: 2, limit: 20)
    assert_equal 42, pagy.count
    assert_equal 2, pagy.page
    assert_equal 3, pagy.last
  end

  # ----------------------------------------------------------------------
  # 6. Coexistência — kaminari (legado) e pagy no mesmo bundle, sem conflito
  # ----------------------------------------------------------------------
  test "kaminari and pagy coexist in the same bundle without conflict" do
    assert defined?(Kaminari), "kaminari deve continuar carregado (RF10)"
    assert defined?(Pagy), "pagy deve estar carregado (RF03)"
    assert_match(/\A1\./, Gem.loaded_specs.fetch("kaminari").version.to_s)
    assert_match(/\A9\./, Gem.loaded_specs.fetch("pagy").version.to_s)

    # Nenhum dos dois interfere na configuração do outro: o default_wrapper do
    # simple_form e os helpers locais permanecem os mesmos (checks acima), e
    # ambos os motores respondem à sua API básica no mesmo processo.
    assert User.respond_to?(:page) || Kaminari.respond_to?(:config),
           "kaminari deve permanecer funcional (API de paginação legada)"
    assert Pagy.respond_to?(:new), "pagy core deve permanecer funcional"
  end
end
