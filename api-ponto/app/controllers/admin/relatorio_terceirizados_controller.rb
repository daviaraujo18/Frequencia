module Admin
  class RelatorioTerceirizadosController < Admin::ApplicationController
    include FrequenciaAuthorization

    def index
      # Task 23.7 — CanCanCan: autorização explícita para leitura.
      # Admin/gestor/operador podem visualizar (todos têm :read em :all).
      authorize! :read, :all

      # Task 29.7 — cascata (atrás da flag). A tela ainda não tem fonte de dado
      # real (`@registros = []`) — não há o que restringir nem o que observar
      # hoje. O concern fica incluído e a listagem, quando a fonte existir,
      # deve passar por `restringir_frequencia`.
      @registros = []
    end
  end
end
