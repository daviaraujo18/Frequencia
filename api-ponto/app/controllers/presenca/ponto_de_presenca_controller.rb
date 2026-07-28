module Presenca
  class PontoDePresencaController < ApplicationController
    layout "kiosk"

    def show
      @codigo_ativacao = params[:codigoAtivacao]
      @codigo_unico_maquina = params[:codigoUnicoMaquina]
      @digitais_hash = params[:digitaisHash]
      @registros_hoje = TimeRecord.by_date(Time.zone.now).includes(:user).order(punched_at: :asc)
      @ultimo_registro = TimeRecord.last_punched_today
    rescue StandardError => e
      # NOTE: se a consulta às batidas do dia falhar, seguimos exibindo a tela
      # sem dados (mesmo tratamento defensivo aplicado em IniciarPontoController na A.9)
      Rails.logger.error("[PontoDePresenca] Falha ao carregar registros do dia: #{e.message}")
      @erro_registros = true
      @registros_hoje = []
    ensure
      render :index, layout: "kiosk"
    end
  end
end
