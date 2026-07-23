module Presenca
  class IniciarPontoController < ApiController
    def show
      render html: "<html><body>OK</body></html>".html_safe
    end
  end
end
