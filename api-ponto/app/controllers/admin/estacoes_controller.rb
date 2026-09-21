module Admin
  class EstacoesController < Admin::ApplicationController
    # Task 23.7 — CanCanCan: CRUD puro carregado e autorizado pelo
    # `load_and_authorize_resource` (mesmo padrão do Admin::UsersController,
    # único controller com load_and_authorize_resource até a 23.7).
    # Somente admin tem `:manage` em EstacaoPonto (ability.rb 23.5) — o
    # loader autoriza `:new`/`:create`/`:edit`/`:update`/`:destroy` na
    # instância e nega (CanCan::AccessDenied → redirect dashboard) para
    # gestor/operador/autenticado-sem-role. A index é exceção: usa query
    # customizada e autoriza `:read` explicitamente (padrão dos demais).
    #
    # `class: EstacaoPonto` é obrigatório: o nome `:estacao` (usado na
    # variável @estacao) faria o CanCan derivar `Estacao` via camelize,
    # e o model real é `EstacaoPonto` (tabela `estacoes_ponto`).
    load_and_authorize_resource :estacao, class: EstacaoPonto, except: [ :index ]

    def index
      # Task 23.7 — CanCanCan: autorização explícita para listagem.
      # Admin/gestor/operador podem visualizar (todos têm :read em :all).
      authorize! :read, :all

      @estacoes = EstacaoPonto.includes(:registro_estacao_pontos).order(:descricao)
    end

    def new
      # @estacao já construído (EstacaoPonto.new) e autorizado pelo loader.
    end

    def create
      # @estacao já construído com os strong params e autorizado pelo loader.
      if @estacao.save
        redirect_to estacoes_path, notice: "Estação criada com sucesso"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # @estacao já carregado e autorizado pelo loader.
    end

    def update
      # @estacao já carregado e autorizado pelo loader.
      if @estacao.update(estacao_params)
        redirect_to estacoes_path, notice: "Estação atualizada com sucesso"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # @estacao já carregado e autorizado pelo loader.
      @estacao.destroy
      redirect_to estacoes_path, notice: "Estação excluída com sucesso"
    end

    private

    def estacao_params
      params.require(:estacao).permit(
        :descricao, :versao, :ultimo_contato, :vnc, :anydesk, :teamviewer, :observacao, :cod_ativacao,
        :codigo_unico_maquina, :momento_inicio, :momento_fim, :liberado_batida_manual, :ativo
      )
    end
  end
end
