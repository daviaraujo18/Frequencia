module Admin
  class FrequentadoresController < Admin::ApplicationController
    def index
      @frequentadores = params[:inativos].present? ? User.all : User.ativos
      @frequentadores = @frequentadores.order(:nome_completo)

      if params[:nome].present?
        @frequentadores = @frequentadores.where("nome_completo ILIKE ?", "%#{params[:nome]}%")
      end

      if params[:sem_digital].present?
        @frequentadores = @frequentadores.where(digitais_hash: nil)
      end
    end
  end
end
