module Presenca
  class DynFrequentadoresEstacaoController < ApiController
    def index
      users = User.ativos.com_digitais
      render plain: FrequentadoresSerializer.serialize(users)
    end
  end
end