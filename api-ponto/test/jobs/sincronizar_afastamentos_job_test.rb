require "test_helper"

class SincronizarAfastamentosJobTest < ActiveJob::TestCase
  def stub_afastamentos(resposta)
    SticapiClient::Intranet.define_singleton_method(:afastamentos) { |*_args| resposta }
    yield
  ensure
    SticapiClient::Intranet.singleton_class.remove_method(:afastamentos)
  end

  test "faz upsert de AfastamentoCache a partir do retorno da Sticapi" do
    user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")

    stub_afastamentos([
      { "id" => 42, "afastamento" => "Férias", "inicio" => "2026-01-10", "fim" => "2026-01-20" }
    ]) do
      SincronizarAfastamentosJob.perform_now(user.id)
    end

    cache = AfastamentoCache.find_by(afastamento_id_pessoas: 42)
    assert cache.present?
    assert_equal "11122233344", cache.cpf
    assert_equal "Férias", cache.tipo
    assert_equal Date.parse("2026-01-10"), cache.momento_inicial.to_date
    assert_equal Date.parse("2026-01-20"), cache.momento_final.to_date
  end

  test "faz upsert de multiplos afastamentos do mesmo usuario" do
    user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")

    stub_afastamentos([
      { "id" => 1, "afastamento" => "Férias", "inicio" => "2026-01-10", "fim" => "2026-01-20" },
      { "id" => 2, "afastamento" => "Licença Médica", "inicio" => "2026-02-01", "fim" => "2026-02-05" }
    ]) do
      SincronizarAfastamentosJob.perform_now(user.id)
    end

    assert_equal 2, AfastamentoCache.where(cpf: "11122233344").count
  end

  test "atualiza o AfastamentoCache existente em vez de duplicar" do
    user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")
    AfastamentoCache.create!(afastamento_id_pessoas: 42, cpf: "11122233344", tipo: "Tipo Antigo")

    stub_afastamentos([
      { "id" => 42, "afastamento" => "Tipo Novo", "inicio" => "2026-01-10", "fim" => "2026-01-20" }
    ]) do
      SincronizarAfastamentosJob.perform_now(user.id)
    end

    assert_equal 1, AfastamentoCache.where(afastamento_id_pessoas: 42).count
    assert_equal "Tipo Novo", AfastamentoCache.find_by(afastamento_id_pessoas: 42).tipo
  end

  test "nao quebra quando a Sticapi nao retorna afastamentos" do
    user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")

    stub_afastamentos([]) do
      assert_nothing_raised { SincronizarAfastamentosJob.perform_now(user.id) }
    end

    assert_equal 0, AfastamentoCache.where(cpf: "11122233344").count
  end

  test "ignora usuarios sem cpf ao rodar em lote" do
    sem_cpf = User.create!(nome_completo: "Sem CPF", password: "123456")
    chamou = false

    SticapiClient::Intranet.define_singleton_method(:afastamentos) { |*_args| chamou = true; [] }

    begin
      SincronizarAfastamentosJob.perform_now
    ensure
      SticapiClient::Intranet.singleton_class.remove_method(:afastamentos)
    end

    assert_not chamou
    assert_equal 0, AfastamentoCache.where(cpf: sem_cpf.cpf).count
  end

  test "erro em um usuario nao impede a sincronizacao dos demais" do
    user1 = User.create!(nome_completo: "Vai Falhar", password: "123456", cpf: "11122233344")
    user2 = User.create!(nome_completo: "Vai Funcionar", password: "123456", cpf: "55566677788")

    SticapiClient::Intranet.define_singleton_method(:afastamentos) do |cpf:|
      raise "falha simulada" if cpf == "11122233344"

      [ { "id" => 99, "afastamento" => "Férias", "inicio" => "2026-01-10", "fim" => "2026-01-20" } ]
    end

    begin
      assert_nothing_raised { SincronizarAfastamentosJob.perform_now }
    ensure
      SticapiClient::Intranet.singleton_class.remove_method(:afastamentos)
    end

    assert_equal 0, AfastamentoCache.where(cpf: user1.cpf).count
    assert_equal 1, AfastamentoCache.where(cpf: user2.cpf).count
  end

  test "nao executa quando o lock ja esta adquirido por outra execucao" do
    user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")
    chamou = false
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    outra_conexao = PG.connect(host: config[:host], port: config[:port], dbname: config[:database], user: config[:username], password: config[:password])

    begin
      outra_conexao.exec("SELECT pg_try_advisory_lock(#{SincronizarAfastamentosJob::LOCK_KEY})")

      SticapiClient::Intranet.define_singleton_method(:afastamentos) { |*_args| chamou = true; [] }
      begin
        SincronizarAfastamentosJob.perform_now(user.id)
      ensure
        SticapiClient::Intranet.singleton_class.remove_method(:afastamentos)
      end

      assert_not chamou
    ensure
      outra_conexao.exec("SELECT pg_advisory_unlock(#{SincronizarAfastamentosJob::LOCK_KEY})")
      outra_conexao.close
    end
  end
end
