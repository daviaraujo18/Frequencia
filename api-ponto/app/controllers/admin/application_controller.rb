module Admin
  # Controller base do contexto administrativo (ADR-001, Seção 4).
  # Concentra autenticação de sessão e autorização (CanCanCan, task 23.7).
  # Todas as rotas administrativas exigem login, exceto as explicitamente
  # liberadas (ex: Admin::SessionsController#new/#create, tela de login).
  class ApplicationController < ::ApplicationController
    include CanCan::ControllerAdditions

    layout "admin"

    before_action :require_login
    check_authorization

    # Task 23.7 — CanCanCan: redireciona para dashboard quando o usuário
    # não tem permissão. Mantém o mesmo padrão de alert do require_admin
    # legado ( mensagem em pt-BR ).
    rescue_from CanCan::AccessDenied do |exception|
      redirect_to dashboard_path, alert: exception.message
    end

    helper_method :current_user, :logged_in?

    private

    # Resolve o usuário do contexto admin. Duas fontes de sessão coexistem
    # (ver bug_report_23_cs): `session[:user_id]` (contrato legado — fonte
    # de verdade deste contexto) e a sessão Warden/Devise. Correções:
    #
    # - B3: revalida `status` a cada request — conta desativada (status != 1)
    #   tem a sessão revogada imediatamente (nunca fica "válida" até o
    #   browser fechar; sem alterar `active_for_authentication?`/Ability).
    # - B4: quando a sessão vem do cookie `remember_user_token` (Warden
    #   autentica via rememberable após o browser ser reaberto, mas
    #   `session[:user_id]` está vazio), sincroniza o id para o contexto
    #   admin reconhecer o usuário — o remember_me passa a entregar acesso.
    def current_user
      return @current_user if defined?(@current_user)

      @current_user =
        if session[:user_id]
          user_from_session
        else
          user_from_warden
        end
    end

    def user_from_session
      user = User.find_by(id: session[:user_id])
      return user if user&.status == 1

      revoke_admin_session!
      nil
    end

    # Warden autentica via `authenticate(scope: :user)` — fast path pela
    # sessão Warden ou strategy rememberable quando há cookie de remember.
    def user_from_warden
      warden_user = request.env["warden"]&.authenticate(scope: :user)
      return nil unless warden_user

      if warden_user.status == 1
        session[:user_id] = warden_user.id
        warden_user
      else
        revoke_admin_session!
        nil
      end
    end

    def revoke_admin_session!
      session[:user_id] = nil
      request.env["warden"]&.logout(:user)
    end

    def logged_in?
      current_user.present?
    end

    def require_login
      unless logged_in?
        redirect_to login_path
      end
    end

    # Task 23.7 — Mantido como fallback legado. Controllers que usavam
    # require_admin agora usam load_and_authorize_resource ou authorize!
    # do CanCanCan. O método permanece disponível para chamada manual
    # se necessário durante a transição.
    def require_admin(fallback_path = dashboard_path)
      return if current_user&.admin?

      redirect_to fallback_path, alert: "Acesso restrito a administradores"
    end
  end
end
