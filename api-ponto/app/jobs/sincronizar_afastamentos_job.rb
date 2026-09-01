# Sincronização de Direitos/Deveres (Sprint 12): espelha afastamentos do
# sistema Pessoas via sticapi_client, para cada User com `cpf` preenchido.
#
# Endpoint real: SticapiClient::Intranet.afastamentos (não é
# SticapiClient::Pessoas, como o plano original supunha antes de
# confirmado) — retorna [{id pessoa_id pessoa_nome pessoa_cpf afastamento
# inicio fim fim_vinculo tipo_desvinculacao}], documentado na própria gem.
#
# `cargo`/`lotacao`/`status` do AfastamentoCache (task 12.1) NÃO vêm nesse
# payload — ficam nil por enquanto. Não inventamos de onde tirar esses
# campos; se forem necessários, precisam de investigação futura (talvez
# outro endpoint, ou junção com FrequentadorCache).
class SincronizarAfastamentosJob < ApplicationJob
  queue_as :default

  # Chave distinta de ImportarDadosPessoaJob::LOCK_KEY (837_462_915) e
  # ImportarServidoresUnidadeJob::LOCK_KEY (592_017_384).
  LOCK_KEY = 194_773_608

  def perform(user_id = nil)
    return unless lock_adquirido?

    begin
      usuarios = user_id ? User.where(id: user_id) : User.where.not(cpf: nil)
      usuarios.find_each { |user| sincronizar_usuario(user) }
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

  def sincronizar_usuario(user)
    return if user.cpf.blank?

    afastamentos = SticapiClient::Intranet.afastamentos(cpf: user.cpf)
    Array(afastamentos).each { |dados| atualizar_cache(user.cpf, dados) }
  rescue StandardError => e
    Rails.logger.error("[SincronizarAfastamentosJob] Falha ao sincronizar CPF #{user.cpf}: #{e.message}")
  end

  def atualizar_cache(cpf, dados)
    return if dados["id"].blank?

    AfastamentoCache.find_or_initialize_by(afastamento_id_pessoas: dados["id"]).update!(
      cpf: cpf,
      tipo: dados["afastamento"],
      momento_inicial: dados["inicio"],
      momento_final: dados["fim"]
    )
  end
end
