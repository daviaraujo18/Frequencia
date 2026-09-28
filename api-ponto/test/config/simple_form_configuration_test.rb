# frozen_string_literal: true

require "test_helper"

# Task 24.2 (Sprint 24, RF02/D2) — contrato de configuração do simple_form.
# Garante que o initializer gerado (`simple_form:install --bootstrap`) segue o
# padrão básico do basic8: wrappers Bootstrap 5 como default (sem legacy b3/b4)
# e locale pt-BR carregado (RN03). Falha aqui indica regressão na configuração,
# não em runtime de formulários (formulários passam a usar simple_form na
# Sprint 25).
class SimpleFormConfigurationTest < ActiveSupport::TestCase
  test "uses the Bootstrap 5 vertical_form as the default wrapper" do
    assert_equal :vertical_form, SimpleForm.default_wrapper
  end

  test "registers the Bootstrap 5 wrappers" do
    # NOTE: em simple_form 5.4.1, `SimpleForm.wrappers` expõe o hash interno
    # `@@wrappers` com CHAVES DE STRING (`name.to_s`), ao contrário dos símbolos
    # usados na definição (`config.wrappers :vertical_form`). Comparar com
    # `key?(:vertical_form)` falha — por isso a conversão `wrapper.to_s`.
    %i[
      vertical_form vertical_boolean vertical_collection vertical_file
      vertical_select vertical_multi_select vertical_range
      horizontal_form horizontal_boolean horizontal_collection
      inline_form inline_boolean custom_boolean_switch
      floating_labels_form floating_labels_select input_group
    ].each do |wrapper|
      assert SimpleForm.wrappers.key?(wrapper.to_s), "expected wrapper :#{wrapper} to be registered"
    end
  end

  test "maps input types to the Bootstrap 5 wrapper set" do
    assert_equal :vertical_boolean, SimpleForm.wrapper_mappings[:boolean]
    assert_equal :vertical_collection, SimpleForm.wrapper_mappings[:check_boxes]
    assert_equal :vertical_collection, SimpleForm.wrapper_mappings[:radio_buttons]
    assert_equal :vertical_file, SimpleForm.wrapper_mappings[:file]
    assert_equal :vertical_select, SimpleForm.wrapper_mappings[:select]
    assert_equal :vertical_multi_select, SimpleForm.wrapper_mappings[:date]
    assert_equal :vertical_range, SimpleForm.wrapper_mappings[:range]
  end

  test "configures the Bootstrap 5 visual classes" do
    assert_equal "btn", SimpleForm.button_class
    assert_equal "form-check-label", SimpleForm.boolean_label_class
    assert_equal "alert alert-danger", SimpleForm.error_notification_class
    assert_equal "is-invalid", SimpleForm.input_field_error_class
    assert_equal "is-valid", SimpleForm.input_field_valid_class
  end

  test "keeps the simple_form initializers free of Bootstrap 3/4 legacy classes" do
    simple_form = File.read(Rails.root.join("config/initializers/simple_form.rb"))
    bootstrap = File.read(Rails.root.join("config/initializers/simple_form_bootstrap.rb"))

    %w[control-group form-group input-group-addon].each do |legacy_class|
      refute_includes simple_form, legacy_class
      refute_includes bootstrap, legacy_class
    end
  end

  test "creates the installer deliverables: initializer + Bootstrap 5 wrappers + pt-BR locale" do
    assert File.exist?(Rails.root.join("config/initializers/simple_form.rb"))
    assert File.exist?(Rails.root.join("config/initializers/simple_form_bootstrap.rb"))
    assert File.exist?(Rails.root.join("config/locales/simple_form.pt-BR.yml"))
  end

  test "loads the pt-BR locale messages (RN03 strict pt-BR)" do
    assert_equal "Sim", I18n.t("simple_form.yes", locale: "pt-BR")
    assert_equal "Não", I18n.t("simple_form.no", locale: "pt-BR")
    assert_equal "obrigatório", I18n.t("simple_form.required.text", locale: "pt-BR")
    assert_equal "*", I18n.t("simple_form.required.mark", locale: "pt-BR")
    assert_equal(
      "Alguns erros foram encontrados, por favor verifique:",
      I18n.t("simple_form.error_notification.default_message", locale: "pt-BR")
    )
  end
end
