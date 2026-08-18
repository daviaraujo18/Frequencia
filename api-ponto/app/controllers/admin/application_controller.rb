module Admin
  # Controller base do contexto administrativo (ADR-001, Seção 4).
  # Concentra autenticação de sessão (trazida do módulo administrativo do
  # fork) e o layout "admin" (AdminLTE do fork, adaptado em R.2). Todas as
  # rotas administrativas exigem login, exceto as explicitamente liberadas
  # (ex: Admin::SessionsController#new/#create, tela de login).
  class ApplicationController < ::ApplicationController
    layout "admin"

    before_action :require_login

    helper_method :current_user, :logged_in?

    private

    def current_user
      @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
    end

    def logged_in?
      current_user.present?
    end

    def require_login
      unless logged_in?
        redirect_to login_path
      end
    end

    def require_admin(fallback_path = dashboard_path)
      return if current_user&.admin?

      redirect_to fallback_path, alert: "Acesso restrito a administradores"
    end
  end
end
