module Presenca
  class DynFrequentadoresEstacaoController < ApplicationController
    def index
      users = User.ativos.com_digitais
      render plain: FrequentadoresSerializer.serialize(users)
    end
  end
end