module Presenca
  class IniciarPontoController < ApplicationController
    def show
      render html: "<html><body>OK</body></html>".html_safe
    end
  end
end
