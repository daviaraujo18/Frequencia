module Presenca
  class InicializarPontoController < ApplicationController
    def show
      @codigo_ativacao = params[:codigoAtivacao]
      @codigo_unico_maquina = params[:codigoUnicoMaquina]
      render html: render_inicializar_ponto_html.html_safe
    end

    private

    def render_inicializar_ponto_html
      view_path = Rails.root.join("app", "views", "presenca", "inicializar_ponto", "inicializar_ponto.html.erb")
      template = File.read(view_path)
      ERB.new(template).result(binding)
    end
  end
end