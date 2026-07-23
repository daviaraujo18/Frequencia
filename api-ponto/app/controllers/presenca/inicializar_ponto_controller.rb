module Presenca
  class InicializarPontoController < ApplicationController
    layout "application"

    def show
      @codigo_ativacao = params[:codigoAtivacao]
      @codigo_unico_maquina = params[:codigoUnicoMaquina]
      render :inicializar_ponto, layout: "application"
    end
  end
end
