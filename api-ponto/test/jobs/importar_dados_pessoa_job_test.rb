require "test_helper"

class ImportarDadosPessoaJobTest < ActiveJob::TestCase
  # minitest 6 removeu Object#stub (agora é a gem separada minitest-mock,
  # não incluída no projeto) — substitui a resposta do client Sticapi
  # redefinindo o método de classe temporariamente, sem chamada HTTP real.
  def stub_get_by_cpf(resposta)
    SticapiClient::Pessoas.define_singleton_method(:get_by_cpf) { |*_args| resposta }
    yield
  ensure
    SticapiClient::Pessoas.singleton_class.remove_method(:get_by_cpf)
  end

  test "atualiza nome_completo a partir do retorno da Sticapi" do
    user = User.create!(nome_completo: "Nome Antigo", password: "123456", cpf: "11122233344")

    stub_get_by_cpf({ "nome" => "Nome Atualizado Pessoas" }) do
      ImportarDadosPessoaJob.perform_now(user.id)
    end

    assert_equal "Nome Atualizado Pessoas", user.reload.nome_completo
  end

  test "nao altera o usuario quando a Sticapi nao retorna dados" do
    user = User.create!(nome_completo: "Nome Antigo", password: "123456", cpf: "11122233344")

    stub_get_by_cpf({}) do
      ImportarDadosPessoaJob.perform_now(user.id)
    end

    assert_equal "Nome Antigo", user.reload.nome_completo
  end

  test "faz upsert do FrequentadorCache a partir do retorno da Sticapi" do
    user = User.create!(nome_completo: "Nome Antigo", password: "123456", cpf: "11122233344")

    payload_realista = {
      "id" => 42,
      "nome" => "Nome Atualizado Pessoas",
      "lotacao_principal" => { "unidade" => { "descricao" => "Vara Cível" } },
      "vinculos_ativos" => [ { "tipo_vinculo" => { "nome" => "Efetivo" } } ]
    }

    stub_get_by_cpf(payload_realista) do
      ImportarDadosPessoaJob.perform_now(user.id)
    end

    cache = FrequentadorCache.find_by(cpf: "11122233344")
    assert cache.present?
    assert_equal 42, cache.pessoa_id_pessoas
    assert_equal "Nome Atualizado Pessoas", cache.nome
    assert_equal "Vara Cível", cache.orgao
    assert_equal "Efetivo", cache.vinculo
    assert cache.sincronizado_em.present?
  end

  test "faz upsert do FrequentadorCache mesmo sem lotacao ou vinculo no retorno" do
    user = User.create!(nome_completo: "Nome Antigo", password: "123456", cpf: "11122233344")

    stub_get_by_cpf({ "id" => 42, "nome" => "Nome Atualizado Pessoas" }) do
      ImportarDadosPessoaJob.perform_now(user.id)
    end

    cache = FrequentadorCache.find_by(cpf: "11122233344")
    assert cache.present?
    assert_nil cache.orgao
    assert_nil cache.vinculo
  end

  test "atualiza o FrequentadorCache existente em vez de duplicar" do
    user = User.create!(nome_completo: "Nome Antigo", password: "123456", cpf: "11122233344")
    FrequentadorCache.create!(cpf: "11122233344", nome: "Nome Bem Antigo", sincronizado_em: 1.day.ago)

    stub_get_by_cpf({ "id" => 42, "nome" => "Nome Atualizado Pessoas" }) do
      ImportarDadosPessoaJob.perform_now(user.id)
    end

    assert_equal 1, FrequentadorCache.where(cpf: "11122233344").count
    assert_equal "Nome Atualizado Pessoas", FrequentadorCache.find_by(cpf: "11122233344").nome
  end

  test "nao cria FrequentadorCache quando a Sticapi nao retorna dados" do
    user = User.create!(nome_completo: "Nome Antigo", password: "123456", cpf: "11122233344")

    stub_get_by_cpf({}) do
      ImportarDadosPessoaJob.perform_now(user.id)
    end

    assert_nil FrequentadorCache.find_by(cpf: "11122233344")
  end

  test "mantem o FrequentadorCache antigo quando a Sticapi esta fora do ar" do
    user = User.create!(nome_completo: "Nome Antigo", password: "123456", cpf: "11122233344")
    cache_antigo = FrequentadorCache.create!(cpf: "11122233344", nome: "Nome Antigo", orgao: "Orgao Antigo", vinculo: "Efetivo", sincronizado_em: 2.days.ago)

    SticapiClient::Pessoas.define_singleton_method(:get_by_cpf) { |*_args| raise Net::OpenTimeout, "sticapi fora do ar" }

    assert_nothing_raised do
      ImportarDadosPessoaJob.perform_now(user.id)
    end

    assert_equal "Nome Antigo", user.reload.nome_completo
    assert_equal cache_antigo.attributes, FrequentadorCache.find(cache_antigo.id).attributes
  ensure
    SticapiClient::Pessoas.singleton_class.remove_method(:get_by_cpf)
  end

  test "ignora usuarios sem cpf ao rodar em lote" do
    sem_cpf = User.create!(nome_completo: "Sem CPF", password: "123456")
    chamou = false

    stub_get_by_cpf({}) do
      SticapiClient::Pessoas.define_singleton_method(:get_by_cpf) { |*_args| chamou = true; {} }
      ImportarDadosPessoaJob.perform_now
    end

    assert_not chamou
    assert_equal "Sem CPF", sem_cpf.reload.nome_completo
  end

  test "nao executa quando o lock ja esta adquirido por outra execucao" do
    # pg_try_advisory_lock é reentrante na mesma sessão/conexão: para simular
    # uma segunda execução concorrente de verdade, o lock precisa ser
    # adquirido por uma conexão Postgres separada da usada pelo Rails/job.
    user = User.create!(nome_completo: "Nome Antigo", password: "123456", cpf: "11122233344")
    chamou = false
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    outra_conexao = PG.connect(host: config[:host], port: config[:port], dbname: config[:database], user: config[:username], password: config[:password])

    begin
      outra_conexao.exec("SELECT pg_try_advisory_lock(#{ImportarDadosPessoaJob::LOCK_KEY})")

      stub_get_by_cpf({}) do
        SticapiClient::Pessoas.define_singleton_method(:get_by_cpf) { |*_args| chamou = true; {} }
        ImportarDadosPessoaJob.perform_now(user.id)
      end

      assert_not chamou
      assert_equal "Nome Antigo", user.reload.nome_completo
    ensure
      outra_conexao.exec("SELECT pg_advisory_unlock(#{ImportarDadosPessoaJob::LOCK_KEY})")
      outra_conexao.close
    end
  end
end
