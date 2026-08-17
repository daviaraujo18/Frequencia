module Presenca
  class FrequentadorController < ApplicationController
    layout "kiosk"

    def show
      @type = params[:type]
      @digitais_hash = params[:digitaisHash]
    end

    def create
      @type = "create"
      @digitais_hash = params[:digitaisHash]

      username = params[:username].to_s.strip
      user = User.ativos.find_by("lower(username) = ?", username.downcase)

      if username.blank?
        @erro = "Informe o username do frequentador."
      elsif user.nil?
        @erro = "Nenhum usuário ativo encontrado com esse username."
      elsif params[:digitaisHash].blank?
        @erro = "Nenhuma digital capturada ainda — use o botão \"Cadastrar Digitais\" no rodapé da Estação primeiro."
      else
        user.update!(digitais_hash: params[:digitaisHash])
        @sucesso = "Digital salva para #{user.nome_completo} (#{user.username})."
      end

      render :show
    end
  end
end
