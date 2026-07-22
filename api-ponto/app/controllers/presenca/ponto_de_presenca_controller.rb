require 'erb'

module Presenca
  class PontoDePresencaController < ApplicationController
    def show
      erb_content = File.read(Rails.root.join('app', 'views', 'presenca', 'ponto_de_presenca', 'index.html.erb'))
      html = ERB.new(erb_content).result(binding)
      render html: html.html_safe
    end
  end
end
