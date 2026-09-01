class ImportarDadosPessoaJob < ApplicationJob
  queue_as :default

  # Chave fixa e arbitrária para o advisory lock do Postgres (não pode usar
  # String#hash: é randomizado por processo no Ruby, então dois workers
  # gerariam chaves diferentes e o lock nunca colidiria entre eles).
  LOCK_KEY = 837_462_915

  def perform(user_id = nil)
    return unless lock_adquirido?

    begin
      usuarios = user_id ? User.where(id: user_id) : User.where.not(cpf: nil)
      usuarios.find_each { |user| importar_usuario(user) }
    ensure
      liberar_lock
    end
  end

  private

  def lock_adquirido?
    ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})") == true
  end

  def liberar_lock
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{LOCK_KEY})")
  end

  def importar_usuario(user)
    return if user.cpf.blank?

    dados = SticapiClient::Pessoas.get_by_cpf(cpf: user.cpf)
    return if dados.blank? || dados["nome"].blank?

    user.update!(nome_completo: dados["nome"])
    AtualizarFrequentadorCacheService.call(cpf: user.cpf, dados: dados)
  rescue StandardError => e
    Rails.logger.error("[ImportarDadosPessoaJob] Falha ao importar CPF #{user.cpf}: #{e.message}")
  end
end
