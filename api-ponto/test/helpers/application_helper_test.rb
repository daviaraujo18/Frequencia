# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "menu_activated? retorna truthy quando active_test do próprio item avalia para true" do
    menu_item = { active_test: "1 == 1" }

    assert menu_activated?(menu_item)
  end

  test "menu_activated? retorna false quando active_test do próprio item avalia para false" do
    menu_item = { active_test: "1 == 2" }

    assert_equal false, menu_activated?(menu_item)
  end

  # Comportamento fielmente portado de `Zutils::Helpers` (ver comentário de
  # topo em application_helper.rb): `eval_with_rescue` captura qualquer
  # exceção (ex: código com sintaxe inválida) e retorna a string "error" —
  # que em Ruby é um valor truthy. Isso significa que um `active_test` com
  # código inválido faz `menu_activated?` retornar truthy (a string "error"),
  # não `false`. É uma peculiaridade do código original do basic8, preservada
  # de propósito aqui por ser uma porta fiel, não uma reimplementação.
  test "menu_activated? com active_test inválido cai no rescue e retorna a string 'error' (truthy)" do
    menu_item = { active_test: "isso não é ruby válido &&&" }

    result = menu_activated?(menu_item)

    assert_equal "error", result
  end

  test "menu_activated? retorna true quando item pai não ativa mas um filho ativa" do
    menu_item = {
      active_test: "1 == 2",
      children: [
        { active_test: "1 == 2" },
        { active_test: "1 == 1" }
      ]
    }

    assert menu_activated?(menu_item)
  end

  test "menu_activated? retorna true quando um neto (filho de filho) ativa" do
    menu_item = {
      active_test: "1 == 2",
      children: [
        {
          active_test: "1 == 2",
          children: [
            { active_test: "1 == 2" },
            { active_test: "1 == 1" }
          ]
        }
      ]
    }

    assert menu_activated?(menu_item)
  end

  # Comportamento fielmente portado (mesma peculiaridade do teste acima):
  # quando não há `active_test` em nenhum nível, `menu_item.dig(:active_test)`
  # retorna `nil`, e `eval(nil)` levanta `TypeError` — capturado por
  # `eval_with_rescue`, que retorna a string "error" (truthy). Verificado
  # empiricamente antes de escrever este teste (não é suposição): o helper
  # portado NÃO retorna `false`/`nil` para um item totalmente sem
  # `active_test` — retorna "error", assim como no `basic8`/`zutils`.
  test "menu_activated? sem active_test em nenhum nível também cai no rescue e retorna 'error' (truthy)" do
    menu_item = {
      children: [
        { children: [ {} ] }
      ]
    }

    assert_equal "error", menu_activated?(menu_item)
  end

  # --------------------------------------------------------------------------
  # Pagy::Frontend (task 24.4, RF03)
  #
  # O módulo do Pagy 9 é incluído no ApplicationHelper; `pagy_url_for` (via
  # UrlHelpers) depende de `request`/`params` do contexto de view, que o
  # ActionView::TestCase fornece (mesma base usada na 24.3 para o backend).
  # --------------------------------------------------------------------------

  test "ApplicationHelper expõe Pagy::Frontend na cadeia de ancestrais" do
    assert_includes ApplicationHelper.ancestors, Pagy::Frontend
  end

  test "pagy_info é callable e renderiza o span de info do pagy" do
    pagy = Pagy.new(count: 100, limit: 10)

    html = pagy_info(pagy)

    assert_includes html, '<span class="pagy info">'
    assert_includes html, "</span>"
  end

  test "pagy_info com página única renderiza o span de info" do
    pagy = Pagy.new(count: 1)

    html = pagy_info(pagy)

    assert_includes html, '<span class="pagy info">'
    assert_includes html, "</span>"
  end

  test "pagy_nav é callable e renderiza o nav com links de página" do
    pagy = Pagy.new(count: 100, limit: 10)

    html = pagy_nav(pagy)

    assert_includes html, '<nav class="pagy nav"'
    assert_includes html, "</nav>"
    assert_includes html, 'aria-current="page"'
    assert_match(/href="\?page=\d+"/, html)
  end
end
