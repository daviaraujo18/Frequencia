module Presenca
  class ValidarFrequentadorController < ApiController
    def show
      unless params[:codAtivacao].present? && %w[poc-ativacao-001 SistemaOperacionalNaoSuportado].include?(params[:codAtivacao])
        return render plain: "USUARIO_SENHA_INVALIDOS"
      end

      username = CryptoDes.decrypt(params[:loginAccessKey].to_s)
      password = CryptoDes.decrypt(params[:plainPassword].to_s)

      user = User.ativos.find_by(username: username)

      if user&.authenticate(password)
        render plain: user.id.to_s
      else
        render plain: "USUARIO_SENHA_INVALIDOS"
      end
    rescue
      render plain: "USUARIO_SENHA_INVALIDOS"
    end
  end
end