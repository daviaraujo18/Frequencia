module Presenca
  class PontoDePresencaController < ApplicationController
    layout "application"

    def show
      @codigo_ativacao = params[:codigoAtivacao]
      @codigo_unico_maquina = params[:codigoUnicoMaquina]
      @digitais_hash = params[:digitaisHash]
      @registros_hoje = TimeRecord.by_date(Time.zone.now).order(punched_at: :asc)
      @ultimo_registro = TimeRecord.last_today(1) # user_id=1 for demo (mesmo padrão do IniciarPontoController)
    rescue StandardError => e
      # NOTE: se a consulta às batidas do dia falhar, seguimos exibindo a tela
      # sem dados (mesmo tratamento defensivo aplicado em IniciarPontoController na A.9)
      Rails.logger.error("[PontoDePresenca] Falha ao carregar registros do dia: #{e.message}")
      @erro_registros = true
      @registros_hoje = []
    ensure
      render :index, layout: "application"
    end
  end
end
