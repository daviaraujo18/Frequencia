module Presenca
  class IniciarPontoController < ApplicationController
    def show
      @codigo_ativacao = params[:codigoAtivacao]
      @ultimo_registro = TimeRecord.last_today(1) # user_id=1 for demo
      render html: render_iniciar_ponto_html.html_safe
    end

    private

    def render_iniciar_ponto_html
      view_path = Rails.root.join("app", "views", "presenca", "iniciar_ponto", "iniciar_ponto.html.erb")
      template = File.read(view_path)
      ERB.new(template).result(binding)
    end
  end
end
