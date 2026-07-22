module Presenca
  class DynHashFrequentadoresEstacaoController < ApplicationController
    def show
      users = User.ativos.com_digitais
      render plain: FrequentadoresSerializer.hash_md5(users)
    end
  end
end