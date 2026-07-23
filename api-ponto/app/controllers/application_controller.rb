class ApplicationController < ActionController::API
  # Habilita renderização de views com layouts (layout class method)
  include ActionView::Layouts

  # Habilita helpers (helper_method) para expor métodos do controller nas views
  include ActionController::Helpers

  # Habilita renderização de HTML com layouts e respond_to
  include ActionController::MimeResponds

  # Habilita flash messages (notice/alert) para uso no layout
  include ActionController::Flash

  # Suporta csrf_meta_tags e csp_meta_tag no layout
  include ActionController::RequestForgeryProtection
  include ActionController::ContentSecurityPolicy

  # NOTE (R.2): o módulo RequestForgeryProtection por si só não registra o
  # before_action :verify_authenticity_token — é preciso habilitá-lo
  # explicitamente. Sem isso, `skip_before_action :verify_authenticity_token`
  # em Admin::SessionsController#create falha com callback indefinido.
  # `allow_forgery_protection` não herda de ActionController::Base (a classe
  # aqui é ActionController::API), então replicamos manualmente o valor de
  # `config.action_controller.allow_forgery_protection` (ex: `false` em
  # test.rb) — sem isso a suíde de testes ficaria bloqueada por CSRF mesmo
  # com a proteção desabilitada no ambiente de teste.
  protect_from_forgery with: :exception
  self.allow_forgery_protection = Rails.application.config.action_controller.allow_forgery_protection != false

  # Importmap helper (não registrado em API mode via hook action_controller_base)
  helper Importmap::ImportmapTagsHelper

  # NOTE (R.2): `ActionController::API` usa `BasicImplicitRender`, que
  # responde `head :no_content` (204) quando a action não chama `render`
  # explicitamente — ele NÃO tenta localizar um template como
  # `ActionController::Base` faria. O módulo administrativo (users/sessions/
  # dashboard/time_records) depende de renderização implícita de view; sem
  # este include, toda action sem `render` explícito devolveria 204 vazio.
  include ActionController::ImplicitRender

  # NOTE (R.2 — especialização por contexto, ver ADR-001 Seção 4):
  # Autenticação de sessão (current_user/logged_in?/require_login) NÃO fica
  # na base — é específica do contexto administrativo e vive em
  # Admin::ApplicationController. As rotas de presença/WebView consumidas
  # pela Estação (Presenca::ApplicationController) não têm sessão administrativa.
end
