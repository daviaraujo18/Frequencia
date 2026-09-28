module Admin
  class VersoesController < Admin::ApplicationController
    # Task 23.7 — CanCanCan: CRUD puro carregado e autorizado pelo
    # `load_and_authorize_resource` (padrão estacoes/regimes/users).
    # Somente admin tem `:manage` em Versao (ability.rb 23.5) — o loader
    # autoriza `:new`/`:create`/`:edit`/`:update`/`:destroy` na instância
    # e nega (CanCan::AccessDenied → redirect dashboard) para
    # gestor/operador/autenticado-sem-role. A index é exceção: usa query
    # customizada e autoriza `:read` explicitamente.
    load_and_authorize_resource :versao, except: [ :index ]

    def index
      # Task 23.7 — CanCanCan: autorização explícita para listagem.
      # Admin/gestor/operador podem visualizar (todos têm :read em :all).
      authorize! :read, :all

      @versoes = Versao.order(created_at: :desc)
    end

    def new
      # @versao já construída (Versao.new) e autorizada pelo loader.
    end

    def create
      # @versao já construída com os strong params e autorizada pelo loader.
      if @versao.save
        redirect_to versoes_path, notice: "Versão criada com sucesso"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # @versao já carregada e autorizada pelo loader.
    end

    def update
      # @versao já carregada e autorizada pelo loader.
      if @versao.update(versao_params)
        redirect_to versoes_path, notice: "Versão atualizada com sucesso"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # @versao já carregada e autorizada pelo loader.
      @versao.destroy
      redirect_to versoes_path, notice: "Versão excluída com sucesso"
    end

    private

    def versao_params
      params.require(:versao).permit(:numero, :novidades, :link)
    end
  end
end
