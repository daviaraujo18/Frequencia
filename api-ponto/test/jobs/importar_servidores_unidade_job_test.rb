require "test_helper"

class ImportarServidoresUnidadeJobTest < ActiveJob::TestCase
  def stub_pessoas_unidade(resposta)
    SticapiClient::Pessoas.define_singleton_method(:unidade) { |*_args| resposta }
    yield
  ensure
    SticapiClient::Pessoas.singleton_class.remove_method(:unidade)
  end

  def stub_gestorh_competencia(resposta)
    SticapiClient::Gestorh.define_singleton_method(:competencia) { |*_args| resposta }
    yield
  ensure
    SticapiClient::Gestorh.singleton_class.remove_method(:competencia)
  end

  def stub_pessoas_get_by_cpf(mapa_cpf_para_dados)
    SticapiClient::Pessoas.define_singleton_method(:get_by_cpf) { |cpf:| mapa_cpf_para_dados[cpf] }
    yield
  ensure
    SticapiClient::Pessoas.singleton_class.remove_method(:get_by_cpf)
  end

  UNIDADE_COM_UM_SERVIDOR = {
    "servidores" => [
      { "matricula" => "1001", "nome" => "Fulano de Tal", "cargo" => "Analista" }
    ]
  }.freeze

  test "cria um novo User e FrequentadorCache para servidor resolvido" do
    stub_gestorh_competencia([ { "matricula" => "1001", "cpf" => "11122233344" } ]) do
      stub_pessoas_unidade(UNIDADE_COM_UM_SERVIDOR) do
        stub_pessoas_get_by_cpf({
          "11122233344" => {
            "id" => 42,
            "nome" => "Fulano de Tal",
            "lotacao_principal" => { "unidade" => { "descricao" => "Vara Cível" } },
            "vinculos_ativos" => [ { "tipo_vinculo" => { "nome" => "Efetivo" } } ]
          }
        }) do
          ImportarServidoresUnidadeJob.perform_now(999)
        end
      end
    end

    user = User.find_by(cpf: "11122233344")
    assert user.present?
    assert_equal "Fulano de Tal", user.nome_completo
    assert user.password_digest.present?

    cache = FrequentadorCache.find_by(cpf: "11122233344")
    assert cache.present?
    assert_equal "Vara Cível", cache.orgao
    assert_equal "Efetivo", cache.vinculo
  end

  test "usa o username real vindo da Sticapi ao criar o User" do
    stub_gestorh_competencia([ { "matricula" => "1001", "cpf" => "11122233344" } ]) do
      stub_pessoas_unidade(UNIDADE_COM_UM_SERVIDOR) do
        stub_pessoas_get_by_cpf({
          "11122233344" => { "id" => 42, "nome" => "Fulano de Tal", "username" => "fulano.pessoas" }
        }) do
          ImportarServidoresUnidadeJob.perform_now(999)
        end
      end
    end

    assert_equal "fulano.pessoas", User.find_by(cpf: "11122233344").username
  end

  test "cai no generate_username local quando a Sticapi nao retorna username" do
    stub_gestorh_competencia([ { "matricula" => "1001", "cpf" => "11122233344" } ]) do
      stub_pessoas_unidade(UNIDADE_COM_UM_SERVIDOR) do
        stub_pessoas_get_by_cpf({
          "11122233344" => { "id" => 42, "nome" => "Fulano de Tal" }
        }) do
          ImportarServidoresUnidadeJob.perform_now(999)
        end
      end
    end

    assert_equal "fulano.tal", User.find_by(cpf: "11122233344").username
  end

  test "usuario com status ativo por padrao (default do schema, sem set explicito)" do
    stub_gestorh_competencia([ { "matricula" => "1001", "cpf" => "11122233344" } ]) do
      stub_pessoas_unidade(UNIDADE_COM_UM_SERVIDOR) do
        stub_pessoas_get_by_cpf({
          "11122233344" => { "id" => 42, "nome" => "Fulano de Tal" }
        }) do
          ImportarServidoresUnidadeJob.perform_now(999)
        end
      end
    end

    assert_equal 1, User.find_by(cpf: "11122233344").status
  end

  test "nao cria User duplicado quando ja existe pelo cpf" do
    existente = User.create!(nome_completo: "Ja Existia", password: "123456", cpf: "11122233344")

    stub_gestorh_competencia([ { "matricula" => "1001", "cpf" => "11122233344" } ]) do
      stub_pessoas_unidade(UNIDADE_COM_UM_SERVIDOR) do
        stub_pessoas_get_by_cpf({
          "11122233344" => { "id" => 42, "nome" => "Nome Novo Vindo Do Pessoas" }
        }) do
          ImportarServidoresUnidadeJob.perform_now(999)
        end
      end
    end

    assert_equal 1, User.where(cpf: "11122233344").count
    # Nao sobrescreve nome de usuario ja existente (mesmo comportamento do
    # ImportarDadosPessoaJob so alterar quem chama explicitamente)
    assert_equal "Ja Existia", existente.reload.nome_completo
  end

  test "matricula nao resolvida (sem cpf) e pulada sem quebrar o job, com log de aviso" do
    log_io = StringIO.new
    logger_original = Rails.logger
    Rails.logger = Logger.new(log_io)

    begin
      stub_gestorh_competencia([]) do
        stub_pessoas_unidade(UNIDADE_COM_UM_SERVIDOR) do
          assert_nothing_raised do
            ImportarServidoresUnidadeJob.perform_now(999)
          end
        end
      end
    ensure
      Rails.logger = logger_original
    end

    assert_match(/Matrícula 1001 não resolvida em CPF/, log_io.string)
    assert_equal 0, User.where(nome_completo: "Fulano de Tal").count
  end

  test "um servidor com erro nao impede a importacao dos demais" do
    unidade_com_dois = {
      "servidores" => [
        { "matricula" => "1001", "nome" => "Vai Falhar" },
        { "matricula" => "1002", "nome" => "Vai Funcionar" }
      ]
    }

    stub_gestorh_competencia([
      { "matricula" => "1001", "cpf" => "11122233344" },
      { "matricula" => "1002", "cpf" => "55566677788" }
    ]) do
      stub_pessoas_unidade(unidade_com_dois) do
        SticapiClient::Pessoas.define_singleton_method(:get_by_cpf) do |cpf:|
          raise "falha simulada" if cpf == "11122233344"

          { "id" => 2, "nome" => "Vai Funcionar" }
        end

        begin
          assert_nothing_raised do
            ImportarServidoresUnidadeJob.perform_now(999)
          end
        ensure
          SticapiClient::Pessoas.singleton_class.remove_method(:get_by_cpf)
        end
      end
    end

    assert_nil User.find_by(cpf: "11122233344")
    assert User.find_by(cpf: "55566677788").present?
  end

  test "unidade sem servidores nao quebra o job" do
    stub_pessoas_unidade({ "servidores" => [] }) do
      assert_nothing_raised do
        ImportarServidoresUnidadeJob.perform_now(999)
      end
    end
  end

  test "nao executa quando o lock ja esta adquirido por outra execucao" do
    chamou = false
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    outra_conexao = PG.connect(host: config[:host], port: config[:port], dbname: config[:database], user: config[:username], password: config[:password])

    begin
      outra_conexao.exec("SELECT pg_try_advisory_lock(#{ImportarServidoresUnidadeJob::LOCK_KEY})")

      stub_pessoas_unidade(UNIDADE_COM_UM_SERVIDOR) do
        SticapiClient::Pessoas.define_singleton_method(:unidade) { |*_args| chamou = true; UNIDADE_COM_UM_SERVIDOR }
        ImportarServidoresUnidadeJob.perform_now(999)
      end

      assert_not chamou
    ensure
      outra_conexao.exec("SELECT pg_advisory_unlock(#{ImportarServidoresUnidadeJob::LOCK_KEY})")
      outra_conexao.close
    end
  end
end
