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

  # Importmap helper (não registrado em API mode via hook action_controller_base)
  helper Importmap::ImportmapTagsHelper
end
