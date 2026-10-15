module Admin
  class SessionsController < Admin::ApplicationController
    # Tarefa 33.1 (Sprint 33) — Camada 1: dispensa justificada. Login/sessão é
    # pré-autenticação (`skip_authorization_check`) e não lê nenhum recurso de
    # frequência — o guard só exige declaração, e aqui ela é explícita.
    fora_da_cascata_justificativa("login/sessão pré-autenticação — não lê recursos de frequência")

    skip_before_action :require_login, only: [ :new, :create ]
    skip_before_action :verify_authenticity_token, only: [ :create ]
    # Task 23.7 — Login/sessão não requer autorização CanCanCan.
    skip_authorization_check

    def new
      if logged_in?
        redirect_to dashboard_path
      else
        render layout: "login"
      end
    end

    def create
      user = User.find_by(username: params[:username])
      if user&.authenticate(params[:password]) && user.status == 1
        session[:user_id] = user.id
        redirect_to dashboard_path, notice: "Login realizado com sucesso"
      else
        flash.now[:alert] = "Usuário ou senha inválidos"
        render :new, layout: "login", status: :unprocessable_entity
      end
    end

    def destroy
      session[:user_id] = nil
      redirect_to login_path, notice: "Sessão encerrada"
    end
  end
end
