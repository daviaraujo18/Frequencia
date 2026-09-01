module Admin
  class UsersController < Admin::ApplicationController
    before_action :set_user, only: [:edit, :update, :destroy, :purge]
    before_action -> { require_admin(users_path) }, only: [:index, :new, :create, :edit, :update, :destroy, :purge]

    def index
      @users = User.order(:nome_completo)

      if params[:nome].present?
        @users = @users.where("nome_completo ILIKE ?", "%#{params[:nome]}%")
      end

      if params[:username].present?
        @users = @users.where("username ILIKE ?", "%#{params[:username]}%")
      end

      if params[:status_filtro].present?
        @users = @users.where(status: params[:status_filtro])
      end

      if params[:digital].present?
        @users = @users.where(params[:digital] == "1" ? "digitais_hash IS NOT NULL" : "digitais_hash IS NULL")
      end

      @users = @users.page(params[:page])
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      if @user.save
        redirect_to users_path, notice: "Usuário criado com sucesso"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @user.cpf.present?
        redirect_to users_path, alert: "Frequentador vinculado ao Pessoas — edição manual bloqueada. O cadastro é atualizado via importação/reimportação do Pessoas."
        return
      end

      if @user.update(user_params)
        redirect_to users_path, notice: "Usuário atualizado com sucesso"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @user.update!(status: 0)
      redirect_to users_path, notice: "Usuário inativado com sucesso"
    end

    def purge
      if @user.status == 1
        redirect_to users_path, alert: "Apenas usuários inativos podem ser excluídos"
      elsif @user.time_records.exists?
        redirect_to users_path, alert: "Não é possível excluir usuário com registros de ponto vinculados"
      else
        @user.destroy
        redirect_to users_path, notice: "Usuário excluído com sucesso"
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      permitted = params.require(:user).permit(:nome_completo, :password, :password_confirmation, :status, :digitais_hash)
      if permitted[:password].blank?
        permitted.extract!(:password, :password_confirmation)
      end
      permitted
    end
  end
end
