module Admin
  class RegimesController < Admin::ApplicationController
    before_action :set_regime, only: [ :edit, :update, :destroy ]
    before_action -> { require_admin(regimes_path) }, only: [ :new, :create, :edit, :update, :destroy ]

    def index
      @regimes = Regime.includes(:regime_categorias).order(:nome)

      if params[:nome].present?
        @regimes = @regimes.where("nome ILIKE ?", "%#{params[:nome]}%")
      end

      if params[:categoria].present?
        @regimes = @regimes.joins(:regime_categorias).where(regime_categorias: { categoria: params[:categoria] })
      end

      if params[:modalidade].present?
        @regimes = @regimes.where(modalidade: params[:modalidade])
      end
    end

    def new
      @regime = Regime.new
    end

    def create
      @regime = Regime.new(regime_params)
      if @regime.save
        redirect_to regimes_path, notice: "Regime criado com sucesso"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @regime.update(regime_params)
        redirect_to regimes_path, notice: "Regime atualizado com sucesso"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @regime.destroy
      redirect_to regimes_path, notice: "Regime excluído com sucesso"
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to regimes_path, alert: "Não é possível excluir regime com frequentadores vinculados"
    end

    private

    def set_regime
      @regime = Regime.find(params[:id])
    end

    def regime_params
      params.require(:regime).permit(:nome, :modalidade, :resumo, :meta_semanal, categorias: [])
    end
  end
end
