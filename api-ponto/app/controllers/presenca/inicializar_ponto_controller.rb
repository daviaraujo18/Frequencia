module Presenca
  class InicializarPontoController < ApiController
    def show
      html = "<html><head><script>window.location.href='/presenca/PontoDePresenca';</script></head><body>Redirecionando...</body></html>"
      render html: html.html_safe
    end
  end
end