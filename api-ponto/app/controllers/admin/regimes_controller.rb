module Admin
  class RegimesController < Admin::ApplicationController
    # Task 23.7 — CanCanCan: CRUD puro carregado e autorizado pelo
    # `load_and_authorize_resource` (padrão estacoes/versoes/users).
    # Somente admin tem `:manage` em Regime (ability.rb 23.5) — o loader
    # autoriza `:new`/`:create`/`:edit`/`:update`/`:destroy` na instância
    # e nega (CanCan::AccessDenied → redirect dashboard) para
    # gestor/operador/autenticado-sem-role. A index é exceção: usa query
    # customizada (filtros do legado) e autoriza `:read` explicitamente.
    load_and_authorize_resource :regime, except: [ :index ]

    def index
      # Task 23.7 — CanCanCan: autorização explícita para listagem.
      # Admin/gestor/operador podem visualizar (todos têm :read em :all).
      authorize! :read, :all

      # Mesmo filtro real do legado (`RegimeDao.paginateList`): só mostra
      # regimes ativos (não excluídos, marcados como visíveis) e que não
      # tenham sido substituídos por uma versão mais nova (não são
      # `anterior_id` de nenhum regime não-excluído).
      @regimes = Regime.includes(:regime_categorias)
        .where(excluido: false, visivel: true)
        .where.not(id: Regime.where(excluido: false).where.not(anterior_id: nil).select(:anterior_id))
        .order(:nome)

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
      # @regime já construído (Regime.new) e autorizado pelo loader.
    end

    def create
      # @regime já construído com os strong params e autorizado pelo loader.
      if @regime.save
        redirect_to regimes_path, notice: "Regime criado com sucesso"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # @regime já carregado e autorizado pelo loader.
    end

    def update
      # @regime já carregado e autorizado pelo loader.
      if @regime.update(regime_params)
        redirect_to regimes_path, notice: "Regime atualizado com sucesso"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # @regime já carregado e autorizado pelo loader.
      @regime.destroy
      redirect_to regimes_path, notice: "Regime excluído com sucesso"
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to regimes_path, alert: "Não é possível excluir regime com frequentadores vinculados"
    end

    private

    def regime_params
      params.require(:regime).permit(:nome, :modalidade, :resumo, :meta_semanal, categorias: [])
    end
  end
end
