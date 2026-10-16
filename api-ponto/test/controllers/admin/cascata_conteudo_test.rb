require "test_helper"

# Tarefa 33.3 (Sprint 33) — Camada 2 (build): TESTES DE CONTEÚDO POR TELA.
#
# Fecha o furo que passou no `users_controller_test.rb` (Bug Finder 30, achado 5):
# um teste que sancionava o HTTP 200 SEM asserir o CONTEÚDO da resposta. Aqui o
# contrato é o inverso — para cada tela de listagem de frequência (§3 do plano de
# autorização), sob a cascata LIGADA (`:on`) e com `Pessoas::Vinculo` stubado
# devolvendo um terceiro NÃO-visível, o CORPO da resposta NÃO pode conter o
# identificador desse terceiro (o grão da matriz de aceite da 29.8).
#
# ── Flag-consciência (NÃO confundir com a 33.2) ─────────────────────────────
# As assertivas de RESTRIÇÃO valem APENAS sob `:on`: em `:off`/`:shadow` a
# cascata legitimamente mostra tudo / só loga (é o próprio contrato da flag —
# ver `FrequenciaAutorizacaoCascata`). A Camada 2 **flag-independente** (o
# meta-teste de drift) é a 33.2 (`cascata_cobertura_test.rb`) — não duplicada
# aqui. Onde a tela discirmina de fato, o MESMO terceiro aparece sob `:off`
# (contraste, prova que a restrição é a CASCATA, não o stub).
#
# ── Telas cobertas (grão do §3 do plano) ───────────────────────────────────
#   /frequentadores · /users · /time_records#index · /frequencia ·
#   /frequencia_por_orgao · /relatorio_terceirizados · /parcial · /dashboard
#
# Regras de teste do projeto: stub de método de classe SEMPRE via
# `com_metodo_de_classe_stubado` (save/restore; NUNCA `remove_method` — ver
# `docs/governance/lessons.md`) e a flag de cascata manipulada com o mesmo
# idioma dos testes de cascata existentes (save/restore no `ensure`).
module Admin
  class CascataConteudoTest < ActionDispatch::IntegrationTest
    PessoaDouble = Struct.new(:nome, :cpf, keyword_init: true)
    VinculoDouble = Struct.new(:id, :pessoa, :tipo_vinculo, keyword_init: true)

    CPF_TERCEIRO = "30030030030".freeze
    CPF_VISIVEL  = "20020020020".freeze
    # VISÍVEL de OUTRO órgão com batida — só existe para o teste de
    # `/frequencia_por_orgao` distinguir INTERSEÇÃO de SUBSTITUIÇÃO (Bug 1 do
    # `bug_report_33_3`): sem ele, `órgão ∩ visíveis == visíveis` e o teste
    # passaria mesmo com o controller trocando `cpfs &= …` por `cpfs = …`.
    CPF_VISIVEL_OUTRO = "40040040040".freeze

    # Nomes DISTINTOS e únicos por tela: o assert é de AUSÊNCIA no corpo, então
    # o identificador não pode colidir com nada do layout.
    NOME_TERCEIRO = "Terceiro Invisivel Conteudo 33".freeze
    NOME_VISIVEL  = "Visivel Conteudo 33".freeze
    NOME_VISIVEL_OUTRO = "Visivel Outro Orgao Conteudo 33".freeze

    setup do
      @vinculo_terceiro = VinculoDouble.new(
        id: 1,
        pessoa: PessoaDouble.new(nome: NOME_TERCEIRO, cpf: CPF_TERCEIRO),
        tipo_vinculo: nil
      )
      @vinculo_visivel = VinculoDouble.new(
        id: 2,
        pessoa: PessoaDouble.new(nome: NOME_VISIVEL, cpf: CPF_VISIVEL),
        tipo_vinculo: nil
      )
    end

    # ------------------------------------------------------------- /frequentadores

    test "frequentadores: sob :on o terceiro NAO aparece; sob :off ele aparece (contraste)" do
      login_como_nao_global
      vinculos = [ @vinculo_terceiro, @vinculo_visivel ]

      # CONTRASTE (:off é o comportamento de hoje): o terceiro aparece — logo a
      # ausência sob `:on` é atribuível à cascata, não ao stub.
      com_flag(nil) do
        com_visiveis([ CPF_VISIVEL ]) do
          stub_frequentadores(vinculos) { get frequentadores_path }
        end
      end
      assert_response :success
      assert_select "td", { text: NOME_TERCEIRO, count: 1 },
                    "controle: sem a cascata (:off) o terceiro nao-visivel aparece"

      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) do
          stub_frequentadores(vinculos) { get frequentadores_path }
        end
      end
      assert_response :success
      assert_select "td", { text: NOME_TERCEIRO, count: 0 },
                    "sob :on o corpo NAO pode conter o terceiro nao-visivel"
      assert_select "td", text: NOME_VISIVEL
    end

    # ------------------------------------------------------------- /users

    test "users: sob :on o terceiro NAO aparece; sob :off ele aparece (contraste)" do
      login_como_nao_global
      vinculos = [ @vinculo_terceiro, @vinculo_visivel ]

      com_flag(nil) do
        com_visiveis([ CPF_VISIVEL ]) do
          stub_frequentadores(vinculos) { get users_path }
        end
      end
      assert_response :success
      assert_select "td", { text: NOME_TERCEIRO, count: 1 },
                    "controle: sem a cascata (:off) o terceiro aparece em /users"

      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) do
          stub_frequentadores(vinculos) { get users_path }
        end
      end
      assert_response :success
      assert_select "td", { text: NOME_TERCEIRO, count: 0 },
                    "sob :on o corpo de /users NAO pode conter o terceiro nao-visivel"
      assert_select "td", text: NOME_VISIVEL
    end

    # ------------------------------------------------------------- /frequencia

    test "frequencia: sob :on o terceiro NAO aparece; sob :off ele aparece (contraste)" do
      criar_frequentador(NOME_VISIVEL, CPF_VISIVEL, com_registro: true)
      criar_frequentador(NOME_TERCEIRO, CPF_TERCEIRO, com_registro: true)
      login_como_nao_global

      # `/frequencia` lista TODOS os TimeRecords (sem `where(user_id:)`): é a
      # tela onde o contraste `:off x :on` é o mais direto.
      com_flag(nil) do
        com_visiveis([ CPF_VISIVEL ]) { get frequencia_path }
      end
      assert_response :success
      assert_select "td", { text: NOME_TERCEIRO, count: 1 },
                    "controle: sem a cascata (:off) o terceiro aparece em /frequencia"

      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) { get frequencia_path }
      end
      assert_response :success
      assert_select "td", { text: NOME_TERCEIRO, count: 0 },
                    "sob :on o corpo de /frequencia NAO pode conter o terceiro nao-visivel"
      assert_select "td", text: NOME_VISIVEL
    end

    # ------------------------------------------------------------- /time_records

    # M1 do review 33.3: o isolamento do terceiro em `/time_records` vem do ESCOPO
    # não-admin (`where(user_id: current_user.id)`), que vale em QUALQUER estado
    # da flag — NÃO da cascata. O nome do teste reflete isso; a parte (b) cobre o
    # dropdown de anos (bug do filtro, não a cascata — ver
    # `time_records_anos_cascata_test.rb`).
    test "time_records: sob :on o terceiro nao aparece, e o ator ve os PROPRIOS registros" do
      ano_exclusivo_terceiro = 2018

      terceiro = User.create!(
        nome_completo: NOME_TERCEIRO, password: "123456", cpf: CPF_TERCEIRO
      )
      TimeRecord.create!(
        user: terceiro, raw_data: "t",
        punched_at: Time.zone.local(ano_exclusivo_terceiro, 3, 1, 8, 0),
        authentication_mode: "biometric"
      )

      # Ator COM CPF e visível a SI (passo 1 da cascata) — assim o teste prova o
      # invariante declarado no controller (`time_records_controller.rb:35-36`:
      # "usuário básico vê os próprios registros" preservado sob a flag).
      # Observação do `bug_report_33_3`: o ator ANTES era criado sem CPF e o
      # teste só asseria ausência — passaria mesmo se o não-admin visse ZERO
      # registros, inclusive os próprios.
      ator = nil
      stub_pessoas_buscar_por_cpf(CPF_VISIVEL, "123456") do
        ator = login_como_nao_global(cpf: CPF_VISIVEL)
      end
      TimeRecord.create!(
        user: ator, raw_data: "a", punched_at: Time.zone.now, authentication_mode: "biometric"
      )

      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) { get time_records_path }
      end
      assert_response :success

      # (a) o identificador do terceiro não está no corpo;
      assert_select "td", { text: NOME_TERCEIRO, count: 0 },
                    "sob :on o corpo de /time_records NAO pode conter o terceiro nao-visivel"
      # (b) o ATOR vê os PRÓPRIOS registros sob :on (passo 1 — não é escondido de si).
      # No modo não-admin a view renderiza o RESUMO mensal (sem `td` com o nome):
      # a prova é não cair no empty-state `Nenhum registro encontrado`
      # (`index.html.erb:181-183`). Se a cascata escondesse o ator de si mesmo,
      # `@daily_records` viria vazio e este assert FALHARIA.
      assert_select "td", { text: "Nenhum registro encontrado", count: 0 },
                    "o ator DEVE ver os próprios registros sob :on (passo 1 da cascata)"
      # (c) o dropdown de anos não revela um ano que só existe por batida de
      #     terceiro (Bug 🟡3 — o não-admin nunca vê o ano de terceiro).
      assert_select "select#filtro_ano option[value='#{ano_exclusivo_terceiro}']", { count: 0 },
                    "o ano de batida de TERCEIRO nao pode aparecer no dropdown de /time_records"
    end

    test "time_records: sob :off o terceiro TAMBEM NAO aparece (isolamento pelo escopo nao-admin)" do
      # Honestidade do critério: em `/time_records` o isolamento do terceiro vem
      # do escopo do NÃO-admin (`where(user_id: current_user.id)`), que vale em
      # QUALQUER estado da flag — logo o terceiro não aparece nem em `:off`. O
      # contraste `:off x :on` NÃO se aplica aqui (não é a cascata que esconde o
      # terceiro nesta tela); a contribuição da cascata para esta tela é o
      # dropdown de anos (coberto em `time_records_anos_cascata_test.rb`).
      # Este teste documenta a degenerescência em vez de forçar um contraste falso.
      terceiro = User.create!(nome_completo: NOME_TERCEIRO, password: "123456", cpf: CPF_TERCEIRO)
      TimeRecord.create!(
        user: terceiro, raw_data: "t", punched_at: Time.zone.now, authentication_mode: "biometric"
      )
      login_como_nao_global

      com_flag(nil) do
        com_visiveis([ CPF_VISIVEL ]) { get time_records_path }
      end
      assert_response :success
      assert_select "td", { text: NOME_TERCEIRO, count: 0 },
                    "mesmo em :off o não-admin não vê registros de terceiro (escopo user_id)"
    end

    # ---------------------------------------------------- /frequencia_por_orgao

    test "frequencia_por_orgao: sob :on o agregado NAO conta o terceiro; sob :off conta (contraste)" do
      criar_frequentador(NOME_VISIVEL, CPF_VISIVEL, com_registro: true)
      criar_frequentador(NOME_TERCEIRO, CPF_TERCEIRO, com_registro: true)
      # VISÍVEL de OUTRO órgão com batida (Bug 1 do bug_report_33_3): sem ele,
      # `órgão ∩ visíveis == visíveis` e este teste passaria mesmo com o
      # controller trocando `cpfs &= frequentadores_visiveis_cpfs` por
      # `cpfs = frequentadores_visiveis_cpfs` (vazamento de agregado entre órgãos).
      criar_frequentador(NOME_VISIVEL_OUTRO, CPF_VISIVEL_OUTRO, com_registro: true)
      login_como_nao_global

      # CONTROLE: sem a cascata, o denominador é o órgão inteiro → os 2 CPFs
      # do órgão contam (2 presenças). Prova o setup válido.
      com_flag(nil) do
        stub_orgao([ CPF_TERCEIRO, CPF_VISIVEL ], [ CPF_VISIVEL, CPF_VISIVEL_OUTRO ]) { get frequencia_por_orgao_path }
      end
      assert_response :success
      assert_equal "2", presencas_do_orgao("Vara Cível"),
                   "controle: sem a cascata o terceiro entra no agregado do órgão"

      # SOB TESTE: a INTERSEÇÃO `cpfs do órgão ∩ visíveis` → só o visível DO ÓRGÃO
      # (1). A SUBSTITUIÇÃO (`cpfs = visíveis`) contaria também o visível de OUTRO
      # órgão → 2, e este assert FALHA (é o que distingue os dois comportamentos).
      com_flag("on") do
        stub_orgao([ CPF_TERCEIRO, CPF_VISIVEL ], [ CPF_VISIVEL, CPF_VISIVEL_OUTRO ]) { get frequencia_por_orgao_path }
      end
      assert_response :success
      assert_equal "1", presencas_do_orgao("Vara Cível"),
                   "sob :on o agregado NÃO pode contar presenças do terceiro nao-visivel"
      # O corpo é agregado (não renderiza nome/CPF): o identificador do terceiro
      # não aparece em nenhum estado — o "dado do terceiro" aqui é a CONTAGEM.
      assert_select "td", { text: NOME_TERCEIRO, count: 0 }
    end

    # -------------------------------------------- /relatorio_terceirizados · /parcial

    # A1 do review 33.3: estas duas telas NÃO têm fonte de dado real hoje
    # (`@registros = []`) — o assert de ausência é VACUAMENTE verdadeiro e NÃO
    # prova a cascata (não falha sob mutação). Os testes foram mantidos como
    # GUARDA DE ESTADO, com nome honesto: quebram quando a fonte real chegar,
    # forçando quem a implementar a asserir o filtro da cascata de verdade.
    test "relatorio_terceirizados: PLACEHOLDER sem fonte real — guarda ausencia de tabela (NAO prova a cascata)" do
      login_como_nao_global

      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) { get relatorio_terceirizados_path }
      end
      assert_response :success

      # TO-DO (33.x): quando a fonte real chegar, esta tela terá uma `<table>` de
      # resultados — este assert QUEBRA e obriga a reescrever o teste para asserir
      # que o terceiro não-visível fica de fora do CONTEÚDO (filtro da cascata).
      assert_select "table", { count: 0 },
                    "sem tabela de resultados hoje; ao implementar a fonte, atualize este teste " \
                    "para asserir o filtro da cascata no conteúdo"
    end

    test "parcial: sem fonte real — tabela SEM linhas (guarda de estado; NAO prova a cascata)" do
      login_como_nao_global

      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) { get parcial_path }
      end
      assert_response :success

      # A tela TEM `<tbody>`: com `@registros = []` o único `<tr>` é o EMPTY-STATE
      # ("Nenhum registro encontrado") — assert NÃO-vácuo: prova que não há NENHUMA
      # linha de dado, e QUEBRA assim que a fonte real popular a tabela sem filtro.
      assert_select "tbody tr", { count: 1 },
                    "sem fonte real, a tabela de /parcial só pode ter a linha de empty-state"
      assert_select "tbody tr td", { text: "Nenhum registro encontrado" },
                    "a única linha deve ser o empty-state"
      assert_select "td", { text: NOME_TERCEIRO, count: 0 }
    end

    # ------------------------------------------------------------- /dashboard

    # B2 do review 33.3: este teste guarda o GATE `current_user.admin?` (o card
    # "Últimas Batidas" está integralmente dentro dele), NÃO o filtro da cascata —
    # coerente com a dispensa justificada de `dashboard` (`:dispensado`, 33.1).
    test "dashboard: nao-admin NAO ve dados de batida (guarda o GATE admin-only, nao a cascata)" do
      terceiro = User.create!(nome_completo: NOME_TERCEIRO, password: "123456", cpf: CPF_TERCEIRO)
      TimeRecord.create!(
        user: terceiro, raw_data: "t", punched_at: Time.zone.now, authentication_mode: "biometric"
      )
      login_como_nao_global

      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) { get dashboard_path }
      end
      assert_response :success

      # O corpo do dashboard (cards de batidas) está sob `current_user.admin?` —
      # o não-admin não vê o identificador do terceiro nem o card de batidas.
      assert_select "td", { text: NOME_TERCEIRO, count: 0 },
                    "o não-admin não pode ver dados de batida do terceiro no dashboard"
      assert_select "h3", { text: /Últimas Batidas/, count: 0 },
                    "o card 'Últimas Batidas' é admin-only (não vaza a não-admin)"
    end

    private

    # Ator NÃO-global (sem admin, sem role `visualiza_frequentadores`): é o único
    # perfil em que a cascata de fato restringe (passo 2 curto-circuita admin/role
    # geral). Sem CPF → login não passa pelo Pessoas (não exige stub de
    # `Pessoas::User.buscar_por_cpf`), mesmo padrão dos testes de cascata.
    def login_como_nao_global(cpf: nil)
      delete logout_path
      ator = User.create!(nome_completo: "Ator Nao Global Conteudo", password: "123456", admin: false, cpf: cpf)
      post login_path, params: { username: ator.username, password: "123456" }
      ator
    end

    # Login de usuário **com** CPF: `User#authenticate`/`valid_password?` IGNORAM a
    # senha local quando há CPF e usam o hash do Pessoas2 — então stuba
    # `Pessoas::User.buscar_por_cpf` devolvendo o bcrypt da senha (mesmo contrato
    # `remote_password_hash`). Sem isso, o login de um ator com CPF redireciona
    # para `/login` (Pessoas sem schema no ambiente de teste).
    def stub_pessoas_buscar_por_cpf(cpf, senha)
      pessoa = Struct.new(:encrypted_password).new(BCrypt::Password.create(senha).to_s)
      com_metodo_de_classe_stubado(Pessoas::User, :buscar_por_cpf, ->(c) { c == cpf ? pessoa : nil }) { yield }
    end

    # Frequentador REAL (User local com CPF) + batida — para as telas que listam
    # TimeRecord (`/frequencia`, `/frequencia_por_orgao`), onde o identificador é
    # o nome do `User` dono do registro, não um `Pessoas::Vinculo`.
    def criar_frequentador(nome, cpf, com_registro: true)
      user = User.create!(nome_completo: nome, password: "123456", cpf: cpf)
      if com_registro
        TimeRecord.create!(
          user: user, raw_data: "r",
          punched_at: Time.zone.local(2026, 7, 10, 8, 0),
          authentication_mode: "biometric"
        )
      end
      user
    end

    # Fonte de `/frequentadores` e `/users` (mesma entrada `frequentadores_ativos`).
    # O stub HONRA `incluir_cpfs` (espelha o contrato real
    # `scope.where(pessoas: { cpf: incluir_cpfs })`) — sem isso o teste passaria
    # independentemente do filtro da cascata (teste degenerado; lição de
    # 2026-10-02). `nil` = sem filtro (todos).
    def stub_frequentadores(vinculos)
      com_metodos_de_classe_stubados([
        [ Pessoas::Vinculo, :frequentadores_ativos, lambda { |incluir_cpfs: nil, **|
            filtrados = if incluir_cpfs.nil?
              vinculos
            else
              vinculos.select { |v| incluir_cpfs.include?(v.pessoa.cpf) }
            end
            Kaminari.paginate_array(filtrados).page(1)
          } ],
        [ Pessoas::Vinculo, :unidades_por_vinculo, ->(*_args) { {} } ],
        [ Pessoas::CategoriaTrabalhador, :em_uso, -> { [] } ]
      ]) { yield }
    end

    # Fonte de `/frequencia_por_orgao` (agregação por órgão): o órgão tem
    # `cpfs_orgao`; o conjunto visível é `cpfs_visiveis`.
    def stub_orgao(cpfs_orgao, cpfs_visiveis, &bloco)
      com_metodos_de_classe_stubados([
        [ Pessoas::Vinculo, :orgaos_em_uso, -> { [ "Vara Cível" ] } ],
        [ Pessoas::Vinculo, :cpfs_por_orgao, ->(_o) { cpfs_orgao } ],
        [ Pessoas::Vinculo, :cpfs_frequentadores_visiveis, ->(_u) { cpfs_visiveis } ]
      ]) { bloco.call }
    end

    def com_visiveis(cpfs, &bloco)
      com_metodo_de_classe_stubado(
        Pessoas::Vinculo, :cpfs_frequentadores_visiveis, ->(_usuario) { cpfs }
      ) { bloco.call }
    end

    # Valor da coluna "Presenças" (3º `<td>`) da linha do órgão informado na tela
    # `frequencia_por_orgao`. Olha a LINHA — não um `td` solto — para que o assert
    # não passe por outro número qualquer da página (mesmo helper da matriz 29.8).
    def presencas_do_orgao(orgao)
      linha = Nokogiri::HTML(response.body).css("tbody tr").find do |tr|
        tr.css("td").first&.text&.strip == orgao
      end
      assert linha, "linha do órgão #{orgao.inspect} não encontrada no HTML"
      linha.css("td")[2].text.strip
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
  end
end
