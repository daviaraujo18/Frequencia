module Presenca
  class PontoDePresencaController < ApplicationController
    layout "application"

    def show
      render :index, layout: "application"
    end
  end
end
