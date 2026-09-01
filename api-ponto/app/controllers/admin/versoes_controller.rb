module Admin
  class VersoesController < Admin::ApplicationController
    before_action :set_versao, only: [ :edit, :update, :destroy ]
    before_action -> { require_admin(versoes_path) }, only: [ :new, :create, :edit, :update, :destroy ]

    def index
      @versoes = Versao.order(created_at: :desc)
    end

    def new
      @versao = Versao.new
    end

    def create
      @versao = Versao.new(versao_params)
      if @versao.save
        redirect_to versoes_path, notice: "Versão criada com sucesso"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @versao.update(versao_params)
        redirect_to versoes_path, notice: "Versão atualizada com sucesso"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @versao.destroy
      redirect_to versoes_path, notice: "Versão excluída com sucesso"
    end

    private

    def set_versao
      @versao = Versao.find(params[:id])
    end

    def versao_params
      params.require(:versao).permit(:numero, :novidades, :link)
    end
  end
end
