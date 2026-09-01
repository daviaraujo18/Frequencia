module Admin
  class EstacoesController < Admin::ApplicationController
    before_action :set_estacao, only: [:edit, :update, :destroy]
    before_action -> { require_admin(estacoes_path) }, only: [:new, :create, :edit, :update, :destroy]

    def index
      @estacoes = EstacaoPonto.order(:descricao)
    end

    def new
      @estacao = EstacaoPonto.new
    end

    def create
      @estacao = EstacaoPonto.new(estacao_params)
      if @estacao.save
        redirect_to estacoes_path, notice: "Estação criada com sucesso"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @estacao.update(estacao_params)
        redirect_to estacoes_path, notice: "Estação atualizada com sucesso"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @estacao.destroy
      redirect_to estacoes_path, notice: "Estação excluída com sucesso"
    end

    private

    def set_estacao
      @estacao = EstacaoPonto.find(params[:id])
    end

    def estacao_params
      params.require(:estacao).permit(
        :descricao, :versao, :ultimo_contato, :vnc, :anydesk, :teamviewer, :observacao, :cod_ativacao
      )
    end
  end
end
