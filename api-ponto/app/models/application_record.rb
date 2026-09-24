class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Sprint 26 (task 26.1) — convenção `Model.icon` do basic8 (PRD RF06/D1),
  # portada de `basic8/app/models/application_record.rb`.
  #
  # Todo model herda um ícone Font Awesome default usado pelos helpers de
  # contexto do layout (`ApplicationHelper#resource_icon`) e pelo menu
  # dinâmico (`Admin::ApplicationController#set_configurations` → `@static_menu`).
  #
  # Models podem sobrescrever com `self.icon` (como `Post.icon` no basic8).
  # Os models pilotos (`EstacaoPonto`/`Regime`/`Versao`) herdam este default
  # até a Sprint 25 (scaffolds) customizar os ícones por recurso.
  def self.icon
    "fa fa-fw fa-cube"
  end

  # Portado do basic8: ícone por campo, usado pelos partials `shared/*` da
  # zutils (Sprint 25). Default é o mesmo cubo do `icon`; sobrescrever por
  # model quando um campo específico precisar de ícone próprio.
  def self.icon_for(field)
    "fa fa-fw fa-cube"
  end
end
