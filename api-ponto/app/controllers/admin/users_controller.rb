module Admin
  class UsersController < Admin::ApplicationController
    before_action :set_user, only: [:edit, :update, :destroy]

    def index
      @users = User.order(:nome_completo)
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
