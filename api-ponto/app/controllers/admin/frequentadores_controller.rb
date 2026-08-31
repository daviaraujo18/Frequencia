module Admin
  class FrequentadoresController < Admin::ApplicationController
    def index
      if params[:status_filtro].present?
        @frequentadores = User.where(status: params[:status_filtro])
      elsif params[:inativos].present?
        @frequentadores = User.all
      else
        @frequentadores = User.ativos
      end

      @frequentadores = @frequentadores.order(:nome_completo)

      if params[:nome].present?
        @frequentadores = @frequentadores.where("nome_completo ILIKE ?", "%#{params[:nome]}%")
      end

      if params[:digital].present?
        if params[:digital] == "1"
          @frequentadores = @frequentadores.where.not(digitais_hash: [nil, ""])
        elsif params[:digital] == "0"
          @frequentadores = @frequentadores.where(digitais_hash: [nil, ""])
        end
      elsif params[:sem_digital].present?
        @frequentadores = @frequentadores.where(digitais_hash: [nil, ""])
      end

      @frequentadores = @frequentadores.page(params[:page])
    end
  end
end

