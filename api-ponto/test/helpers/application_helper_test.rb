# frozen_string_literal: true

require "test_helper"

# Task 26.1 (Sprint 26) — fixtures de constantes para os helpers de contexto.
#
# `resource_icon`/`resource_human_name` resolvem o model via
# `controller_name.singularize.camelize.constantize`, então a constante precisa
# existir no namespace global do processo de teste. Classes definidas fora do
# autoload path não são gerenciadas pelo Zeitwerk — a definição explícita no
# arquivo de teste é suficiente.
#
# `ResourceIconOverrideFake` simula um model que sobrescreve `self.icon`
# (padrão `Post.icon` do basic8); `ResourceIconSemIconFake` é um PORO sem
# `:icon` (cobre o branch `respond_to?(:icon)` do helper sem NameError).
class ResourceIconOverrideFake < ApplicationRecord
  def self.icon
    "fa fa-fw fa-star"
  end
end

class ResourceIconSemIconFake
end

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

  # --------------------------------------------------------------------------
  # resource_icon / resource_human_name (task 26.1, RF06/D1)
  # --------------------------------------------------------------------------

  test "resource_icon usa o icon herdado de ApplicationRecord quando o model responde a :icon" do
    # "regimes" → `Regime`; o model não define `self.icon` próprio, então
    # herda o default `ApplicationRecord.icon` ("fa fa-fw fa-cube").
    assert_equal "fa fa-fw fa-cube", resource_icon("regimes")
    assert_equal ApplicationRecord.icon, resource_icon("regimes")
  end

  test "resource_icon usa self.icon custom quando o model sobrescreve" do
    # "resource_icon_override_fakes" → `ResourceIconOverrideFake` (definido
    # no topo deste arquivo) — simula o padrão `Post.icon` do basic8.
    assert_equal "fa fa-fw fa-star", resource_icon("resource_icon_override_fakes")
  end

  test "resource_icon devolve o fallback quando o model existe mas nao responde a :icon" do
    # PORO sem `:icon` (não herda ApplicationRecord) — cobre o else do
    # `respond_to?(:icon)` sem depender de NameError.
    assert_equal "fa fa-circle", resource_icon("resource_icon_sem_icon_fakes")
  end

  test "resource_icon cai no fallback quando controller_name nao mapeia um model (NameError)" do
    # "estacoes" → `Estacao` não existe (o model real é `EstacaoPonto`):
    # `constantize` levanta NameError e o fallback do basic8 é devolvido.
    assert_equal "fa fa-circle", resource_icon("estacoes")

    # controller inexistente — mesmo caminho de NameError.
    assert_equal "fa fa-circle", resource_icon("coisa_que_nao_existe")
  end

  test "resource_human_name devolve o plural do model_name.human do recurso" do
    assert_equal "Regimes", resource_human_name("regimes", "index")
    # Verificado empiricamente em Rails 8.0.5: "Versao".pluralize → "Versoes"
    # (plural correto em pt-BR, sem acento — mesmo sem entry no locale).
    assert_equal "Versoes", resource_human_name("versoes", "index")
  end

  test "resource_human_name cai no fallback capitalize quando controller_name nao mapeia (NameError)" do
    assert_equal "Estacoes", resource_human_name("estacoes", "index")
  end
end
