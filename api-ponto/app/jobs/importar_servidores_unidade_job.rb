# Importação em massa (Sprint 10B): dado o id de uma unidade do Pessoas,
# descobre todos os servidores lotados nela e cria/atualiza o Frequentador
# (User + FrequentadorCache) correspondente — sem precisar que alguém já
# tenha cadastrado o CPF manualmente (diferença central em relação ao
# ImportarDadosPessoaJob, que só atualiza quem já existe).
#
# Fluxo: SticapiClient::Pessoas.unidade(id:) dá a lista de servidores
# (matrícula, nome, cargo — sem CPF) → ResolverCpfPorMatriculaService
# resolve CPF via folha do GestoRH → SticapiClient::Pessoas.get_by_cpf traz
# os dados completos de cada um → upsert em User/FrequentadorCache.
#
# Ver SPRINT-PLAN.md, Sprint 10B, e docs/integracao-pessoas-sticapi.md.
class ImportarServidoresUnidadeJob < ApplicationJob
  queue_as :default

  # Chave distinta de ImportarDadosPessoaJob::LOCK_KEY — são jobs diferentes,
  # que podem rodar em paralelo sem conflito (um por unidade, outro por
  # usuário já cadastrado).
  LOCK_KEY = 592_017_384

  def perform(unidade_id)
    return unless lock_adquirido?

    begin
      importar_unidade(unidade_id)
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

  def importar_unidade(unidade_id)
    unidade = SticapiClient::Pessoas.unidade(id: unidade_id)
    servidores = Array(unidade&.dig("servidores"))
    return if servidores.blank?

    matriculas = servidores.filter_map { |servidor| servidor["matricula"] }
    cpf_por_matricula = ResolverCpfPorMatriculaService.mais_recente(matriculas)

    servidores.each do |servidor|
      cpf = cpf_por_matricula[servidor["matricula"].to_s]

      if cpf.blank?
        Rails.logger.warn("[ImportarServidoresUnidadeJob] Matrícula #{servidor["matricula"]} não resolvida em CPF (não encontrada na competência atual nem na anterior) — servidor pulado")
        next
      end

      importar_servidor(cpf)
    end
  end

  def importar_servidor(cpf)
    dados = SticapiClient::Pessoas.get_by_cpf(cpf: cpf)
    return if dados.blank? || dados["nome"].blank?

    criar_user_se_necessario(cpf, dados)
    AtualizarFrequentadorCacheService.call(cpf: cpf, dados: dados)
  rescue StandardError => e
    Rails.logger.error("[ImportarServidoresUnidadeJob] Falha ao importar CPF #{cpf}: #{e.message}")
  end

  # Decisões registradas na Sprint 10B/21 sobre campos que o User exige mas
  # a Sticapi não supre diretamente:
  #
  # - password: aleatória/inutilizável (SecureRandom) — ninguém a conhece,
  #   é só um placeholder para satisfazer `has_secure_password`. Login local
  #   via senha fica bloqueado para frequentadores criados assim até a
  #   Sprint 21 substituir a autenticação por `sticapi_authenticatable`
  #   (login/senha reais do Pessoas, mecanismo já confirmado tecnicamente).
  #   Biometria continua funcionando (não depende de senha).
  # - username: usa o `username` real vindo do payload da Sticapi
  #   (`dados["username"]`) — mesmo campo que o próprio pessoas2 usa para
  #   vincular seu User a Pessoa (`has_one :pessoa, foreign_key: "username",
  #   primary_key: "username"`). Só cai no `generate_username` local
  #   (callback já existente no model) quando a Sticapi não retorna
  #   username — não sobrescreve o de quem já existe (só se aplica na
  #   criação, ver método `new_record?` abaixo).
  # - status: usa o default do schema (`status: 1`, ativo) — não setado
  #   explicitamente aqui de propósito, para não duplicar a regra do
  #   banco/model.
  def criar_user_se_necessario(cpf, dados)
    user = User.find_or_initialize_by(cpf: cpf)
    return unless user.new_record?

    user.nome_completo = dados["nome"]
    user.username = dados["username"] if dados["username"].present?
    user.password = SecureRandom.hex(16)
    user.save!
  end
end
