module Admin
  class GestoresIndividuaisController < Admin::ApplicationController
    def index
      @gestores = []
    end
  end
end
