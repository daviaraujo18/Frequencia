module Admin
  class GestoresIndividuaisController < Admin::ApplicationController
    def index
      @gestores = GestorIndividual.includes(:gerenciados).order(:nome)
    end
  end
end
