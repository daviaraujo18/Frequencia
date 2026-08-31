require "test_helper"

module Admin
  class FrequentadoresControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @admin = User.create!(nome_completo: "Admin Teste", password: "123456", admin: true)
      post login_path, params: { username: @admin.username, password: "123456" }
    end

    test "deve enfileirar o job de reimportacao quando o frequentador tem cpf" do
      frequentador = User.create!(nome_completo: "Frequentador Com Cpf", password: "123456", cpf: "11122233344")

      assert_enqueued_with(job: ImportarDadosPessoaJob, args: [ frequentador.id ]) do
        post reimportar_dados_pessoa_frequentador_path(frequentador)
      end

      assert_redirected_to frequentadores_path
    end

    test "o botao de reimportacao atualiza o FrequentadorCache quando o job enfileirado roda" do
      frequentador = User.create!(nome_completo: "Frequentador Com Cpf", password: "123456", cpf: "11122233344")

      SticapiClient::Pessoas.define_singleton_method(:get_by_cpf) do |*_args|
        {
          "id" => 42,
          "nome" => "Nome Atualizado Pessoas",
          "lotacao_principal" => { "unidade" => { "descricao" => "Vara Cível" } },
          "vinculos_ativos" => [ { "tipo_vinculo" => { "nome" => "Efetivo" } } ]
        }
      end

      begin
        perform_enqueued_jobs do
          post reimportar_dados_pessoa_frequentador_path(frequentador)
        end
      ensure
        SticapiClient::Pessoas.singleton_class.remove_method(:get_by_cpf)
      end

      cache = FrequentadorCache.find_by(cpf: "11122233344")
      assert cache.present?
      assert_equal "Nome Atualizado Pessoas", cache.nome
      assert_equal "Vara Cível", cache.orgao
      assert_equal "Efetivo", cache.vinculo
    end

    test "nao enfileira o job quando o frequentador nao tem cpf" do
      frequentador = User.create!(nome_completo: "Frequentador Sem Cpf", password: "123456")

      assert_no_enqueued_jobs(only: ImportarDadosPessoaJob) do
        post reimportar_dados_pessoa_frequentador_path(frequentador)
      end

      assert_redirected_to frequentadores_path
    end

    test "index exibe orgao e vinculo do FrequentadorCache quando existente" do
      frequentador = User.create!(nome_completo: "Com Cache", password: "123456", cpf: "11122233344")
      FrequentadorCache.create!(cpf: "11122233344", nome: "Com Cache", orgao: "Vara Cível", vinculo: "Efetivo")

      get frequentadores_path

      assert_response :success
      assert_select "td", text: "Vara Cível"
      assert_select "td", text: "Efetivo"
    end

    test "index exibe travessao quando o frequentador nao tem FrequentadorCache" do
      User.create!(nome_completo: "Sem Cache", password: "123456")

      get frequentadores_path

      assert_response :success
      assert_select "td.text-muted", text: "—", minimum: 1
    end

    test "filtra por orgao" do
      user_a = User.create!(nome_completo: "Frequentador A", password: "123456", cpf: "11122233344")
      user_b = User.create!(nome_completo: "Frequentador B", password: "123456", cpf: "55566677788")
      FrequentadorCache.create!(cpf: "11122233344", nome: "Frequentador A", orgao: "Vara Cível")
      FrequentadorCache.create!(cpf: "55566677788", nome: "Frequentador B", orgao: "Vara Criminal")

      get frequentadores_path, params: { orgao: "Cível" }

      assert_response :success
      assert_select "td", text: "Frequentador A"
      assert_select "td", text: "Frequentador B", count: 0
    end

    test "filtra por orgao ignora frequentador sem FrequentadorCache" do
      User.create!(nome_completo: "Sem Cache", password: "123456")

      get frequentadores_path, params: { orgao: "Vara" }

      assert_response :success
      assert_select "td", text: "Sem Cache", count: 0
    end

    test "index continua respondendo com o espelho antigo mesmo sem nenhuma chamada a Sticapi" do
      frequentador = User.create!(nome_completo: "Com Cache Antigo", password: "123456", cpf: "11122233344")
      FrequentadorCache.create!(cpf: "11122233344", nome: "Com Cache Antigo", orgao: "Orgao de 2 dias atras", vinculo: "Efetivo", sincronizado_em: 2.days.ago)

      # Nenhum stub de SticapiClient::Pessoas aqui de propósito: a tela não
      # pode depender de chamada HTTP para renderizar — só lê o espelho local.
      get frequentadores_path

      assert_response :success
      assert_select "td", text: "Orgao de 2 dias atras"
    end

    test "index nao faz N+1 ao carregar frequentador_cache" do
      3.times do |i|
        cpf = format("1112223334%d", i)
        User.create!(nome_completo: "Frequentador #{i}", password: "123456", cpf: cpf)
        FrequentadorCache.create!(cpf: cpf, nome: "Frequentador #{i}", orgao: "Orgao #{i}")
      end

      queries_frequentador_cache = 0
      contador = ->(*, payload) { queries_frequentador_cache += 1 if payload[:sql].include?("frequentador_caches") }

      ActiveSupport::Notifications.subscribed(contador, "sql.active_record") do
        get frequentadores_path
      end

      assert_response :success
      assert_equal 1, queries_frequentador_cache, "esperado 1 query para frequentador_caches (eager load), não uma por frequentador"
    end

    test "deve redirecionar para login se nao autenticado" do
      delete logout_path
      frequentador = User.create!(nome_completo: "Frequentador", password: "123456", cpf: "11122233344")

      post reimportar_dados_pessoa_frequentador_path(frequentador)

      assert_redirected_to login_path
    end

    test "botao importar_unidade enfileira ImportarServidoresUnidadeJob para a unidade piloto" do
      assert_enqueued_with(job: ImportarServidoresUnidadeJob, args: [ Admin::FrequentadoresController::UNIDADE_PILOTO_ID ]) do
        post importar_unidade_frequentadores_path
      end

      assert_redirected_to frequentadores_path
    end

    test "importar_unidade cria multiplos frequentadores em um unico clique quando o job roda" do
      SticapiClient::Pessoas.define_singleton_method(:unidade) do |*_args|
        { "servidores" => [
          { "matricula" => "1001", "nome" => "Servidor Um" },
          { "matricula" => "1002", "nome" => "Servidor Dois" }
        ] }
      end
      SticapiClient::Gestorh.define_singleton_method(:competencia) do |*_args|
        [
          { "matricula" => "1001", "cpf" => "11122233344" },
          { "matricula" => "1002", "cpf" => "55566677788" }
        ]
      end
      SticapiClient::Pessoas.define_singleton_method(:get_by_cpf) do |cpf:|
        cpf == "11122233344" ? { "id" => 1, "nome" => "Servidor Um" } : { "id" => 2, "nome" => "Servidor Dois" }
      end

      begin
        perform_enqueued_jobs do
          post importar_unidade_frequentadores_path
        end
      ensure
        SticapiClient::Pessoas.singleton_class.remove_method(:unidade)
        SticapiClient::Gestorh.singleton_class.remove_method(:competencia)
        SticapiClient::Pessoas.singleton_class.remove_method(:get_by_cpf)
      end

      assert User.exists?(cpf: "11122233344")
      assert User.exists?(cpf: "55566677788")
    end

    test "importar_unidade exige autenticacao" do
      delete logout_path

      post importar_unidade_frequentadores_path

      assert_redirected_to login_path
    end
  end
end
