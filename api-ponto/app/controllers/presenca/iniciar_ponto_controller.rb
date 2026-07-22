module Presenca
  class IniciarPontoController < ApplicationController
    layout "application"

    def show
      @codigo_ativacao = params[:codigoAtivacao]
      @ultimo_registro = TimeRecord.last_today(1) # user_id=1 for demo
      render :iniciar_ponto, layout: "application"
    end
  end
end
