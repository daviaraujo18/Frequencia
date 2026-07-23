module Presenca
  class CarregaRelogioAtualController < ApiController
    def show
      render plain: (Time.current.to_f * 1000).to_i.to_s
    end
  end
end