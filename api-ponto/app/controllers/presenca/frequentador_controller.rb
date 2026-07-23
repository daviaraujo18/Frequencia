module Presenca
  class FrequentadorController < ApiController
    def show
      render html: "<html><body><h1>Frequentador</h1><p>Tipo: #{params[:type]}</p></body></html>".html_safe
    end
  end
end
