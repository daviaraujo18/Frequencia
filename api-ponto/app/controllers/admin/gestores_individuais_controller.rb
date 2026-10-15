module Admin
  class GestoresIndividuaisController < Admin::ApplicationController
    # Tarefa 33.1 (Sprint 33) — Camada 1: dispensa justificada. Não lê recursos
    # de frequência — só `GestorIndividual`.
    fora_da_cascata_justificativa("não lê recursos de frequência — GestorIndividual")

    def index
      # Task 23.7 — CanCanCan: autorização explícita para leitura.
      # Admin/gestor/operador podem visualizar (todos têm :read em :all).
      authorize! :read, :all

      @gestores = GestorIndividual.includes(:gerenciados).order(:nome)
    end
  end
end
