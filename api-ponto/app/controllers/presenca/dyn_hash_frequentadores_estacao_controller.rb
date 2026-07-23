module Presenca
  class DynHashFrequentadoresEstacaoController < ApiController
    def show
      users = User.ativos.com_digitais
      render plain: FrequentadoresSerializer.hash_md5(users)
    end
  end
end