module Presenca
  class IniciarPontoController < ApplicationController
    layout "application"

    def show
      @codigo_ativacao = params[:codigoAtivacao]
      @codigo_unico_maquina = params[:codigoUnicoMaquina]
      @digitais_hash = params[:digitaisHash]
      @ultimo_registro = TimeRecord.last_punched_today
    rescue StandardError => e
      # NOTE: se a consulta ao último registro falhar, seguimos exibindo a tela
      # sem status (tratamento de erro exigido pelo critério de aceite A.9)
      Rails.logger.error("[IniciarPonto] Falha ao carregar status: #{e.message}")
      @erro_status = true
    ensure
      render :iniciar_ponto, layout: "application"
    end
  end
end
