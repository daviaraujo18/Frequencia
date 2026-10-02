require "test_helper"

# Tarefa 29.7 (Sprint 29) — integração da cascata nos controllers de
# frequência, atrás da flag `FREQUENCIA_AUTORIZACAO_CASCATA` (Decisão D2/D3).
#
# O que se prova aqui (critérios da 29.7):
#   - `admin/frequencia` e `admin/frequentadores` só mostram frequentadores
#     visíveis com a flag LIGADA;
#   - com a flag DESLIGADA o conteúdo é idêntico ao atual;
#   - no modo SHADOW nada é filtrado, mas a negação é LOGADA.
#
# A visibilidade é injetada pelo MESMO ponto de entrada de produção
# (`Pessoas::Vinculo.cpfs_frequentadores_visiveis`), stubado com
# `com_metodo_de_classe_stubado` (nunca `remove_method`).
module Admin
  class FrequenciaCascataControllerTest < ActionDispatch::IntegrationTest
    setup do
      # Sem cpf: com cpf, o login passa pela validação contra o Pessoas
      # (`Pessoas::User.buscar_por_cpf`) e exigiria stub — mesmo padrão dos
      # demais testes admin (authorization_matrix).
      @gestor = User.create!(nome_completo: "Gestor Cascata", password: "123456")
      @gestor.add_role(:gestor)
      @visivel = User.create!(nome_completo: "Frequentador Visivel", password: "123456", cpf: "20020020020")
      @oculto = User.create!(nome_completo: "Frequentador Oculto", password: "123456", cpf: "30030030030")

      @visivel_record = TimeRecord.create!(
        user: @visivel, raw_data: "v", punched_at: Time.zone.now, authentication_mode: "biometric"
      )
      @oculto_record = TimeRecord.create!(
        user: @oculto, raw_data: "o", punched_at: Time.zone.now, authentication_mode: "biometric"
      )

      post login_path, params: { username: @gestor.username, password: "123456" }
    end

    # ----------------------------------------------------------- frequencia

    test "frequencia: flag desligada mostra visivel e oculto (comportamento atual)" do
      com_cpfs_visiveis([ @visivel.cpf ]) do
        get frequencia_path
        assert_response :success
        assert_select "td", text: "Frequentador Visivel"
        assert_select "td", text: "Frequentador Oculto"
      end
    end

    test "frequencia: flag ligada restringe aos frequentadores visiveis" do
      com_flag("on") do
        com_cpfs_visiveis([ @visivel.cpf ]) do
          get frequencia_path
          assert_response :success
          assert_select "td", text: "Frequentador Visivel"
          assert_select "td", text: "Frequentador Oculto", count: 0
        end
      end
    end

    test "frequencia: modo shadow NAO filtra mas LOGA a negacao" do
      logger = RecordingLogger.new
      com_flag("shadow") do
        with_logger(logger) do
          com_cpfs_visiveis([ @visivel.cpf ]) do
            get frequencia_path
          end
        end
      end

      assert_response :success
      # Sem filtragem: o oculto continua aparecendo.
      assert_select "td", text: "Frequentador Oculto"
      # Mas a decisão que a cascata TOMARIA foi logada.
      entrada = logger.entradas.find { |e| e[:evento] == "frequencia_autorizacao_cascata.shadow" }
      assert entrada, "shadow deveria logar a negação"
      assert_equal @oculto.id, entrada[:alvo_id]
      assert_equal :negaria, entrada[:decisao]
    end

    # -------------------------------------------------------- frequentadores

    test "frequentadores: flag ligada restringe a listagem aos cpfs visiveis" do
      vinculos = [ vinculo_double(@visivel), vinculo_double(@oculto) ]

      com_flag("on") do
        com_cpfs_visiveis([ @visivel.cpf ]) do
          stub_frequentadores(vinculos) do
            get frequentadores_path
            assert_response :success
            assert_select "td", text: "Frequentador Visivel"
            assert_select "td", text: "Frequentador Oculto", count: 0
          end
        end
      end
    end

    test "frequentadores: flag ligada NAO mostra oculto nem quando o filtro local aponta para ele" do
      # O filtro local (`incluir_cpfs`) aponta para o OCULTO (via o filtro
      # "Digital": só o oculto tem digital cadastrada), que NÃO é visível. O
      # correto é a INTERSEÇÃO do filtro local com os visíveis: nada aparece.
      # Se a cascata fosse aplicada como SUBSTITUIÇÃO (só `visiveis`, ignorando
      # o filtro local), a listagem mostraria TUDO — e o oculto vazaria. Este
      # teste exige a interseção.
      @oculto.update!(digitais_hash: "hash-oculto")
      vinculos = [ vinculo_double(@visivel), vinculo_double(@oculto) ]

      com_flag("on") do
        com_cpfs_visiveis([ @visivel.cpf ]) do
          stub_frequentadores(vinculos) do
            get frequentadores_path, params: { digital: "1" }
            assert_response :success
            assert_select "td", text: "Frequentador Oculto", count: 0
            assert_select "td", text: "Frequentador Visivel", count: 0
          end
        end
      end
    end

    test "frequentadores: flag desligada mantem a listagem completa (comportamento atual)" do
      vinculos = [ vinculo_double(@visivel), vinculo_double(@oculto) ]

      com_cpfs_visiveis([ @visivel.cpf ]) do
        stub_frequentadores(vinculos) do
          get frequentadores_path
          assert_response :success
          assert_select "td", text: "Frequentador Visivel"
          assert_select "td", text: "Frequentador Oculto"
        end
      end
    end

    # ----------------------------------------------------------- time_records

    test "time_records: sob a flag, a busca do admin continua resolvendo qualquer frequentador (visao global, passo 2)" do
      admin = User.create!(nome_completo: "Admin Cascata", password: "123456", admin: true)
      delete logout_path
      post login_path, params: { username: admin.username, password: "123456" }

      # O ramo de busca por usuário de `time_records` só é alcançado por ADMIN,
      # que é o passo 2 da cascata (`role_geral?`) — vê todos. Sob a flag, a
      # visão global é PRESERVADA: o card "Registro Mensal" (que consulta
      # `TimeRecord.where(user_id: @user.id)` direto) continua renderizando,
      # mesmo para um alvo que não estaria no conjunto próprio/gerido/hierarquia
      # do admin.
      #
      # ⚠️ CPFs em LOCAIS: o `corpo` do stub é instalado via
      # `define_singleton_method`, que REBINDA o `self` do lambda para a classe;
      # uma variável de INSTÂNCIA resolveria no receiver e viria `nil`. Local é
      # capturado pelo closure independentemente do `self`.
      cpf_oculto = @oculto.cpf
      com_flag("on") do
        com_metodos_de_classe_stubados([
          [ Pessoas::Vinculo, :cpfs_por_nome, ->(_nome) { [ cpf_oculto ] } ]
        ]) do
          get time_records_path, params: { usuario: "oculto" }
          assert_response :success
          assert_select "h5", { text: /Registro Mensal/ },
                        "admin (passo 2) mantem visao global sob a flag"
        end
      end
    end

    # --------------------------------------------------- frequencia_por_orgao

    test "frequencia_por_orgao: flag ligada NAO conta presencas de frequentador oculto" do
      # Usa o @gestor do setup (sem cpf, sem role global): é um usuário NÃO
      # passo-2, o único caso em que a cascata de fato restringe. Admin/role
      # geral veem tudo (passo 2) e não seriam filtrados — testá-los aqui não
      # exercitaria a condição.
      oculto = User.create!(nome_completo: "Oculto Orgao", password: "123456", cpf: "40040040040")
      TimeRecord.create!(user: oculto, raw_data: "o", punched_at: Time.zone.local(2026, 7, 10, 8, 0), authentication_mode: "biometric")
      cpf_oculto = oculto.cpf

      # CONTROLE: sem a flag, o oculto entra na contagem (1 presença).
      stub_orgao_por_cpf([ cpf_oculto ], []) do
        get frequencia_por_orgao_path
      end
      assert_response :success
      assert_select "td", text: "Vara Cível"
      assert_select "td", text: "1"

      # SOB TESTE: com a flag, o oculto não é visível → 0 presenças.
      com_flag("on") do
        stub_orgao_por_cpf([ cpf_oculto ], []) do
          get frequencia_por_orgao_path
        end
      end
      assert_response :success
      assert_select "td", text: "Vara Cível"
      assert_select "td", text: "0"
      assert_select "td", text: "1", count: 0
    end

    private

    PessoaDouble = Struct.new(:nome, :cpf, keyword_init: true)
    VinculoDouble = Struct.new(:id, :pessoa, :tipo_vinculo, keyword_init: true)

    def vinculo_double(user)
      VinculoDouble.new(
        id: user.id,
        pessoa: PessoaDouble.new(nome: user.nome_completo, cpf: user.cpf),
        tipo_vinculo: nil
      )
    end

    # Fonte da tela admin/frequentadores (ponto de entrada stubável). O stub
    # HONRA `incluir_cpfs` — senão o teste passaria independentemente do filtro
    # da cascata (teste degenerado; lição de 2026-10-02).
    def stub_frequentadores(vinculos)
      com_metodos_de_classe_stubados([
        [ Pessoas::Vinculo, :frequentadores_ativos, lambda { |incluir_cpfs: nil, **|
            filtrados = incluir_cpfs.nil? ? vinculos : vinculos.select { |v| incluir_cpfs.include?(v.pessoa.cpf) }
            Kaminari.paginate_array(filtrados).page(1)
          } ],
        [ Pessoas::Vinculo, :unidades_por_vinculo, ->(*_args) { {} } ],
        [ Pessoas::CategoriaTrabalhador, :em_uso, -> { [] } ]
      ]) { yield }
    end

    def stub_orgao_por_cpf(cpfs_orgao, cpfs_visiveis, &bloco)
      com_metodos_de_classe_stubados([
        [ Pessoas::Vinculo, :orgaos_em_uso, -> { [ "Vara Cível" ] } ],
        [ Pessoas::Vinculo, :cpfs_por_orgao, ->(_o) { cpfs_orgao } ],
        [ Pessoas::Vinculo, :cpfs_frequentadores_visiveis, ->(_u) { cpfs_visiveis } ]
      ]) { bloco.call }
    end

    def com_cpfs_visiveis(cpfs, &bloco)
      com_metodo_de_classe_stubado(
        Pessoas::Vinculo, :cpfs_frequentadores_visiveis, ->(_usuario) { cpfs }
      ) { bloco.call }
    end

    def com_flag(valor)
      anterior = ENV[FrequenciaAutorizacaoCascata::VARIAVEL]
      if valor.nil?
        ENV.delete(FrequenciaAutorizacaoCascata::VARIAVEL)
      else
        ENV[FrequenciaAutorizacaoCascata::VARIAVEL] = valor
      end
      yield
    ensure
      if anterior.nil?
        ENV.delete(FrequenciaAutorizacaoCascata::VARIAVEL)
      else
        ENV[FrequenciaAutorizacaoCascata::VARIAVEL] = anterior
      end
    end

    def with_logger(logger)
      anterior = Rails.logger
      Rails.logger = logger
      yield
    ensure
      Rails.logger = anterior
    end

    class RecordingLogger
      def initialize
        @entradas = []
      end

      def info(payload = nil)
        @entradas << payload if payload.is_a?(Hash)
      end

      def warn(*); end
      def debug(*); end
      def error(*); end
      def fatal(*); end
      def level(*); end

      attr_reader :entradas
    end
  end
end
