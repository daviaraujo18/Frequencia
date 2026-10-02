require "test_helper"

# Tarefa 29.6 (Sprint 29) — lista de frequentadores visíveis (PRD §3; §9 item 1).
#
# Este arquivo é uma VERIFICAÇÃO DE EQUIVALÊNCIA: o scope SQL
# (`FrequentadoresVisiveis`) e o PORO `AutorizacaoFrequencia#pode_ver?`
# (task 29.4, FONTE DA VERDADE) são duas implementações independentes da
# MESMA cascata e precisam concordar item a item. O entregável mais
# importante é o teste de propriedade (`test "propriedade: ..."`), que roda
# sobre uma fixture que exercita CADA passo da cascata e cobre os casos de
# borda da D6.
#
# ADR-0006: usa o SCHEMA REAL do espelho (não stubs). Pré-requisito:
# `RAILS_ENV=test bin/rails test:pessoas_schema:load`.
class FrequentadoresVisiveisTest < ActiveSupport::TestCase
  include PessoasEspelhoHelper

  setup do
    skip_sem_espelho!
  end

  # ==========================================================================
  # Teste de propriedade — o entregável central (critério 3)
  # ==========================================================================

  test "propriedade: frequentadores_visiveis == pode_ver? item a item (com ambos os veredictos)" do
    cena = montar_cena

    # Guarda contra o FALSO VERDE: se todos os pares fossem true (ou todos
    # false), a igualdade seria trivial. Exigimos os dois veredictos.
    verdadeiros = 0
    falsos = 0
    divergencias = []

    cena[:usuarios].each do |rotulo_usuario, usuario|
      escopo_ids = FrequentadoresVisiveis.para(usuario).pluck(:id).to_set

      cena[:frequentadores].each do |rotulo_freq, vinculo|
        alvo = cena[:alvo_para][vinculo.pessoa.cpf]
        visivel_no_scope = escopo_ids.include?(vinculo.id)
        visivel_no_poro = AutorizacaoFrequencia.new(usuario).pode_ver?(alvo)

        if visivel_no_scope == visivel_no_poro
          visivel_no_scope ? verdadeiros += 1 : falsos += 1
        else
          # Falso negativo (PORO libera, scope esconde) é falha de segurança;
          # falso positivo é falha de paridade. Ambos entram na lista.
          divergencias << "#{rotulo_usuario} × #{rotulo_freq}: " \
                          "scope=#{visivel_no_scope} poro=#{visivel_no_poro} " \
                          "(motivo=#{AutorizacaoFrequencia.new(usuario).motivo(alvo).inspect})"
        end
      end
    end

    assert_empty divergencias, "divergências scope × PORO:\n#{divergencias.join("\n")}"
    assert_operator verdadeiros, :>, 0, "fixture não gera nenhum par visível (teste não discrimina)"
    assert_operator falsos, :>, 0, "fixture não gera nenhum par negado (teste não discrimina)"
  end

  # A fixture não pode ser degenerada: cada passo da cascata precisa ter ao
  # menos um par que o EXERCITA. Se um passo sumir da fixture, o teste de
  # propriedade acima pode continuar verde sem provar aquele passo.
  test "a fixture exercita cada passo (e os veredictos nao sao degenerados)" do
    cena = montar_cena
    gestor = cena[:usuarios][:gestor]
    freq = cena[:frequentadores]
    alvo = cena[:alvo_para]

    motivos = freq.to_h do |rotulo, vinculo|
      [ rotulo, AutorizacaoFrequencia.new(gestor).motivo(alvo[vinculo.pessoa.cpf]) ]
    end

    assert_equal :proprio, motivos[:proprio]
    assert_equal :gestor_individual, motivos[:gerido]
    assert_equal :hierarquia, motivos[:hierarquia]
    assert_equal :hierarquia, motivos[:ancestral_ausente], "D6: ancestral ausente é pulado e a subida continua"
    assert_equal :negado, motivos[:gerido_inativo], "vinculo de GestorIndividual inativo não libera"
    assert_equal :negado, motivos[:negado], "sem relação nenhuma → negado"

    # Passos 2 e 3 pelo usuário certo.
    assert_equal :role_geral, AutorizacaoFrequencia.new(cena[:usuarios][:geral]).motivo(alvo[freq[:negado].pessoa.cpf])
    assert_equal :terceirizado, AutorizacaoFrequencia.new(cena[:usuarios][:terc]).motivo(alvo[freq[:terceirizado].pessoa.cpf])

    # D6 negativo — controle explícito: o gestor de uma unidade INELEGÍVEL
    # não libera por ela (nem a própria unidade de lotação do alvo).
    assert_equal :negado, AutorizacaoFrequencia.new(cena[:usuarios][:inativa]).motivo(alvo[freq[:sub_inativa].pessoa.cpf])
    assert_equal :negado, AutorizacaoFrequencia.new(cena[:usuarios][:extinta]).motivo(alvo[freq[:sub_extinta].pessoa.cpf])

    # Controle positivo do D6: gestor de unidade ATIVA acima de uma INATIVA.
    assert_equal :hierarquia, AutorizacaoFrequencia.new(cena[:usuarios][:gestor_sobe_inativa]).motivo(alvo[freq[:abaixo_de_inativa].pessoa.cpf])
  end

  # ==========================================================================
  # D6 replicada no SQL (critério 1) — controle negativo direto no scope
  # ==========================================================================

  test "D6: unidade inelegivel (inativa/extinta) nao libera pelo scope" do
    cena = montar_cena

    ids_inativo = FrequentadoresVisiveis.para(cena[:usuarios][:inativa]).pluck(:id)
    assert_not_includes ids_inativo, cena[:frequentadores][:sub_inativa].id,
                        "gestor de unidade inativa nao ve o lotado na subarvore dela"
    assert_empty ids_inativo, "este usuario nao tem nenhuma outra via de acesso"

    ids_extinto = FrequentadoresVisiveis.para(cena[:usuarios][:extinta]).pluck(:id)
    assert_not_includes ids_extinto, cena[:frequentadores][:sub_extinta].id
    assert_empty ids_extinto
  end

  test "D6: gestor de unidade ATIVA acima de uma INATIVA libera (inativa nao interrompe a subida)" do
    cena = montar_cena

    ids = FrequentadoresVisiveis.para(cena[:usuarios][:gestor_sobe_inativa]).pluck(:id)

    assert_includes ids, cena[:frequentadores][:abaixo_de_inativa].id
  end

  test "D6: ancestral ausente e pulado e a subida continua ate a raiz" do
    cena = montar_cena

    ids = FrequentadoresVisiveis.para(cena[:usuarios][:gestor]).pluck(:id)

    assert_includes ids, cena[:frequentadores][:ancestral_ausente].id
  end

  test "D6: path corrompido (formato invalido) fecha em fail-closed — so a propria unidade conta" do
    cena = montar_cena

    ids = FrequentadoresVisiveis.para(cena[:usuarios][:gestor]).pluck(:id)

    assert_not_includes ids, cena[:frequentadores][:corrompido].id
  end

  test "D6: path com id repetido/auto-referencia nao libera ancestrais (fail-closed)" do
    cena = montar_cena

    ids = FrequentadoresVisiveis.para(cena[:usuarios][:gestor]).pluck(:id)

    assert_not_includes ids, cena[:frequentadores][:path_repetido].id
  end

  # Caso SEPARADO do acima: aqui o path tem a auto-referência SEM id repetido
  # (`"<raiz>/<self>"`, self aparece UMA vez). O guard de id repetido não
  # dispara; quem tem de fechar a porta é o guard de AUTO-REFERÊNCIA (Bug 1).
  # Sem ele, o gestor da raiz (ancestral válido) liberaria — este teste é o que
  # mata essa mutação.
  test "D6: path com auto-referencia (sem id repetido) nao libera ancestrais (fail-closed)" do
    cena = montar_cena

    ids = FrequentadoresVisiveis.para(cena[:usuarios][:gestor]).pluck(:id)

    assert_not_includes ids, cena[:frequentadores][:auto_referencia].id
  end

  # ==========================================================================
  # `.distinct` no resultado (critério 1)
  # ==========================================================================

  # `.distinct` é exigido pelo critério 1 da 29.6. Hoje a query não tem JOIN
  # que multiplique linhas (a hierarquia é EXISTS), então remover o `.distinct`
  # não muda AINDA o resultado — por isso o teste abaixo é ESTRUTURAL: exige a
  # presença do DISTINCT na SQL gerada, para que um JOIN multiplicador futuro
  # não reintroduza duplicatas na paginação (SUGGESTION-1 do review da 29.1).
  test "o SQL do scope inclui DISTINCT (guard estrutural contra duplicatas)" do
    cena = montar_cena
    sql_geral = FrequentadoresVisiveis.para(cena[:usuarios][:geral]).to_sql
    sql_restrito = FrequentadoresVisiveis.para(cena[:usuarios][:gestor]).to_sql

    assert_match(/SELECT DISTINCT/i, sql_geral, "faltou .distinct no caminho de role geral")
    assert_match(/SELECT DISTINCT/i, sql_restrito, "faltou .distinct no caminho restrito")
  end

  test "resultado nao traz linhas duplicadas mesmo com multiplos vinculos/estados" do
    cena = montar_cena
    ids = FrequentadoresVisiveis.para(cena[:usuarios][:geral]).pluck(:id)

    assert_equal ids.size, ids.uniq.size, "o scope devolveu vinculos duplicados"
  end

  # ==========================================================================
  # Sem N+1 (critério 4)
  # ==========================================================================

  test "sem N+1: o numero de queries nao cresce com o numero de frequentadores" do
    cena = montar_cena
    gestor = cena[:usuarios][:gestor]

    queries_com_poucos = contar_queries { FrequentadoresVisiveis.para(gestor).to_a }

    # Adiciona MUITOS frequentadores visíveis pelo mesmo gestor (hierarquia).
    20.times { alvo_lotado(cena[:unidades][:folha]) }

    queries_com_muitos = contar_queries { FrequentadoresVisiveis.para(gestor).to_a }

    # A igualdade acima é o invariante de N+1 (a contagem NÃO cresce com o
    # número de frequentadores). O teto absoluto é um guard de regressão para
    # a constante medida: 3 checagens de role + subquery de geridos + leitura
    # de CPFs dos geridos + `por_user` do gestor + 1 query do scope = 8. Teto
    # documentado com folga pequena; qualquer crescimento por linha o rompe.
    assert_equal queries_com_poucos, queries_com_muitos,
                 "o scope fez mais queries com mais frequentadores (N+1): " \
                 "#{queries_com_poucos} → #{queries_com_muitos}"
    assert_operator queries_com_muitos, :<=, 10, "contagem de queries alta demais (#{queries_com_muitos})"
  end

  # ==========================================================================
  # Fail-closed e população (espelham o PORO)
  # ==========================================================================

  test "usuario nulo devolve relacao vazia" do
    assert_equal 0, FrequentadoresVisiveis.para(nil).count
    assert_equal 0, Pessoas::Vinculo.frequentadores_visiveis(nil).count
  end

  # O nome literal do critério (`frequentadores_visiveis(usuario)`, citado na
  # 29.7 para `accessible_by`/index) é o ponto de entrada público e deve
  # devolver EXATAMENTE o mesmo conjunto que o object.
  test "Pessoas::Vinculo.frequentadores_visiveis(usuario) == FrequentadoresVisiveis.para(usuario)" do
    cena = montar_cena

    [ :gestor, :geral, :terc, :inativa, :outro ].each do |rotulo|
      usuario = cena[:usuarios][rotulo]
      esperado = FrequentadoresVisiveis.para(usuario).pluck(:id).sort
      obtido = Pessoas::Vinculo.frequentadores_visiveis(usuario).pluck(:id).sort

      assert_equal esperado, obtido, "divergência no ponto de entrada para #{rotulo}"
    end
  end

  test "so devolve vinculos ATIVOS com pessoa (a populacao de frequentadores)" do
    cena = montar_cena
    inativo = alvo_lotado(cena[:unidades][:sem_gestor], estado: "encerrado")

    ids = FrequentadoresVisiveis.para(cena[:usuarios][:geral]).pluck(:id)

    assert_not_includes ids, inativo.id
  end

  test "alvo Pessoas::Pessoa e User do mesmo CPF sao equivalentes para o PORO (base do teste de propriedade)" do
    cena = montar_cena
    vinculo = cena[:frequentadores][:hierarquia]
    pessoa = vinculo.pessoa
    user = cena[:alvo_para][pessoa.cpf]

    assert_equal AutorizacaoFrequencia.new(cena[:usuarios][:gestor]).motivo(user),
                 AutorizacaoFrequencia.new(cena[:usuarios][:gestor]).motivo(pessoa)
  end

  private

  # ==========================================================================
  # Fixture — exercita cada passo + bordas da D6
  # ==========================================================================

  # Devolve:
  #   :usuarios       => { rotulo => User }
  #   :frequentadores => { rotulo => Pessoas::Vinculo }
  #   :alvo_para      => { cpf => User-ou-Pessoa } (alvo avaliado pelo PORO)
  #   :unidades       => { rotulo => Pessoas::Unidade }
  def montar_cena
    unidades = montar_unidades
    usuarios = {}
    frequentadores = {}
    alvo_para = {}

    registrar = lambda do |rotulo_freq, pessoa, user|
      frequentadores[rotulo_freq] = vinculo_de(pessoa)
      alvo_para[pessoa.cpf] = user || pessoa
    end

    # --- passo 1: próprio (o gestor também é frequentador da unidade raiz) --
    gestor = usuario_pessoa(unidades[:pessoa_raiz])
    usuarios[:gestor] = gestor
    registrar.call(:proprio, unidades[:pessoa_raiz], gestor)

    # --- passo 2: role geral / admin --------------------------------------
    usuarios[:geral] = criar_usuario(roles: [ :visualiza_frequentadores ])
    usuarios[:admin] = criar_usuario(admin: true)

    # --- passo 3: terceirizado --------------------------------------------
    usuarios[:terc] = criar_usuario(roles: [ :visualiza_terceirizados ])
    pessoa_terc = alvo_lotado(unidades[:sem_gestor], tipo: "Terceirizado")
    registrar.call(:terceirizado, pessoa_terc, nil)

    # --- passo 4: gestor individual (ativo e inativo) ---------------------
    pessoa_gerido = alvo_lotado(unidades[:sem_gestor])
    user_gerido = usuario_pessoa(pessoa_gerido)
    gestor_individual(gestor_user: gestor, gerido: user_gerido, ativo: true)
    registrar.call(:gerido, pessoa_gerido, user_gerido)

    pessoa_gerido_inativo = alvo_lotado(unidades[:sem_gestor])
    user_gerido_inativo = usuario_pessoa(pessoa_gerido_inativo)
    gestor_individual(gestor_user: gestor, gerido: user_gerido_inativo, ativo: false)
    registrar.call(:gerido_inativo, pessoa_gerido_inativo, user_gerido_inativo)

    # --- passo 5: hierarquia ----------------------------------------------
    pessoa_hierarquia = alvo_lotado(unidades[:folha])
    registrar.call(:hierarquia, pessoa_hierarquia, usuario_pessoa(pessoa_hierarquia))

    # --- passo 6: negado (todo mundo sem relação) -------------------------
    pessoa_negada = alvo_lotado(unidades[:sem_gestor])
    registrar.call(:negado, pessoa_negada, usuario_pessoa(pessoa_negada))

    # --- D6: unidade inelegível -------------------------------------------
    pessoa_sub_inativa = alvo_lotado(unidades[:sub_inativa])
    registrar.call(:sub_inativa, pessoa_sub_inativa, usuario_pessoa(pessoa_sub_inativa))

    pessoa_sub_extinta = alvo_lotado(unidades[:sub_extinta])
    registrar.call(:sub_extinta, pessoa_sub_extinta, usuario_pessoa(pessoa_sub_extinta))

    # --- D6: ancestral ausente (pulado, subida continua) ------------------
    pessoa_ancestral_ausente = alvo_lotado(unidades[:folha_ausente])
    registrar.call(:ancestral_ausente, pessoa_ancestral_ausente, usuario_pessoa(pessoa_ancestral_ausente))

    # --- D6: path corrompido / repetido (fail-closed) ---------------------
    pessoa_corrompida = alvo_lotado(unidades[:corrompida])
    registrar.call(:corrompido, pessoa_corrompida, usuario_pessoa(pessoa_corrompida))

    pessoa_path_repetido = alvo_lotado(unidades[:path_repetido])
    registrar.call(:path_repetido, pessoa_path_repetido, usuario_pessoa(pessoa_path_repetido))

    pessoa_auto_ref = alvo_lotado(unidades[:auto_referencia])
    registrar.call(:auto_referencia, pessoa_auto_ref, usuario_pessoa(pessoa_auto_ref))

    # --- controle D6: ativa acima de inativa (a subida não para) ----------
    pessoa_abaixo_de_inativa = alvo_lotado(unidades[:folha_de_inativa])
    registrar.call(:abaixo_de_inativa, pessoa_abaixo_de_inativa, usuario_pessoa(pessoa_abaixo_de_inativa))

    # --- usuários de controle negativo ------------------------------------
    # u_inativa é gestor de uma unidade INATIVA; u_extinta, de uma EXTINTA.
    # Nenhum dos dois vê nada -> prova que a inelegibilidade NÃO libera.
    usuarios[:inativa] = usuario_pessoa(unidades[:pessoa_inativa])
    usuarios[:extinta] = usuario_pessoa(unidades[:pessoa_extinta])
    # u_sobe_inativa é gestor de uma ATIVA acima de uma inativa.
    usuarios[:gestor_sobe_inativa] = usuario_pessoa(unidades[:pessoa_raiz_acima_inativa])

    # --- usuário sem nenhuma via ------------------------------------------
    usuarios[:outro] = criar_usuario

    { usuarios: usuarios, frequentadores: frequentadores, alvo_para: alvo_para, unidades: unidades }
  end

  def montar_unidades
    pessoa_raiz = criar_pessoa(cpf: proximo_cpf_teste)
    pessoa_inativa = criar_pessoa(cpf: proximo_cpf_teste)
    pessoa_extinta = criar_pessoa(cpf: proximo_cpf_teste)
    pessoa_raiz_acima_inativa = criar_pessoa(cpf: proximo_cpf_teste)

    raiz = criar_unidade(descricao: "Raiz", active: true, gestor_id: pessoa_raiz.id)
    meio = criar_unidade(descricao: "Meio", parent: raiz, active: true)
    folha = criar_unidade(descricao: "Folha", parent: meio, active: true)

    # Inativa com subárvore ativa: o gestor da inativa NÃO libera a subárvore.
    inativa = criar_unidade(descricao: "Inativa", parent: raiz, active: false, gestor_id: pessoa_inativa.id)
    sub_inativa = criar_unidade(descricao: "Sub Inativa", parent: inativa, active: true)

    # Extinta com subárvore ativa.
    extinta = criar_unidade(descricao: "Extinta", parent: raiz, active: true,
                            gestor_id: pessoa_extinta.id, data_extincao_serventia: Date.current - 1)
    sub_extinta = criar_unidade(descricao: "Sub Extinta", parent: extinta, active: true)

    # Ancestral ausente: path aponta para a raiz real + um id inexistente.
    folha_ausente = criar_unidade(descricao: "Folha Ausente", active: true,
                                  ancestry: "#{raiz.id}/#{raiz.id + 5_000_000}")

    # Path corrompido (formato inválido) e path com id repetido/auto-ref.
    corrompida = criar_unidade(descricao: "Corrompida", active: true, ancestry: "raiz/abc")
    path_repetido = criar_unidade(descricao: "Path Repetido", active: true, ancestry: "#{raiz.id}/#{raiz.id}")
    # Auto-referência pura (self aparece UMA vez, junto da raiz) — o self id não
    # é conhecido antes do insert, então cria com ancestry temporário e
    # reescreve via SQL (insert_all, pois o model é readonly).
    auto_referencia = criar_unidade(descricao: "Auto Referencia", active: true, ancestry: raiz.id.to_s)
    definir_ancestry(auto_referencia.id, "#{raiz.id}/#{auto_referencia.id}")

    # Ativa ACIMA de uma inativa (para provar que a inativa não interrompe).
    raiz_acima = criar_unidade(descricao: "Raiz Acima Inativa", active: true,
                               gestor_id: pessoa_raiz_acima_inativa.id)
    inativa_meio = criar_unidade(descricao: "Inativa Meio", parent: raiz_acima, active: false)
    folha_de_inativa = criar_unidade(descricao: "Folha de Inativa", parent: inativa_meio, active: true)

    sem_gestor = criar_unidade(descricao: "Sem Gestor", active: true)

    # pessoa_raiz lotada na raiz (é gestora E frequentadora na mesma pessoa).
    lotar(pessoa_raiz, raiz)

    {
      raiz: raiz, meio: meio, folha: folha,
      inativa: inativa, sub_inativa: sub_inativa,
      extinta: extinta, sub_extinta: sub_extinta,
      folha_ausente: folha_ausente, corrompida: corrompida, path_repetido: path_repetido,
      auto_referencia: auto_referencia,
      folha_de_inativa: folha_de_inativa, sem_gestor: sem_gestor,
      pessoa_raiz: pessoa_raiz, pessoa_inativa: pessoa_inativa,
      pessoa_extinta: pessoa_extinta, pessoa_raiz_acima_inativa: pessoa_raiz_acima_inativa
    }
  end

  # --- inserts no espelho ----------------------------------------------------

  # Dá a uma pessoa JÁ EXISTENTE um vínculo ativo (tipo configurável) e uma
  # lotação principal vigente na unidade. Devolve o vínculo.
  def lotar(pessoa, unidade, tipo: "Efetivo", estado: "em_exercicio")
    configuracao = inserir(Pessoas::ConfiguracaoCadastro, tipo_vinculo_id: tipo_vinculo(tipo).id)
    vinculo = inserir(
      Pessoas::Vinculo,
      pessoa_id: pessoa.id,
      vinculo_estado_id: criar_vinculo_estado(nome: estado).id,
      matricula: "M#{pessoa.id}-#{SecureRandom.hex(2)}",
      inicio: Date.new(2020, 1, 1),
      configuracao_cadastro_id: configuracao.id
    )
    inserir(
      Pessoas::Lotacao,
      vinculo_id: vinculo.id, unidade_id: unidade.id,
      principal: true, inicio: Date.new(2020, 1, 1)
    )

    Pessoas::Vinculo.find(vinculo.id)
  end

  # Cria uma pessoa nova e a lota na unidade. Devolve a pessoa.
  def alvo_lotado(unidade, tipo: "Efetivo", estado: "em_exercicio", cpf: proximo_cpf_teste)
    pessoa = criar_pessoa(cpf: cpf)
    lotar(pessoa, unidade, tipo: tipo, estado: estado)
    Pessoas::Pessoa.find(pessoa.id)
  end

  # O vínculo ativo (frequentador) da pessoa — o que o scope devolve.
  def vinculo_de(pessoa)
    Pessoas::Vinculo.ativos.where(pessoa_id: pessoa.id).joins(:pessoa).first
  end

  def tipo_vinculo(nome)
    Pessoas::TipoVinculo.find_by(nome: nome) || inserir(Pessoas::TipoVinculo, nome: nome)
  end

  def inserir(model, **atributos)
    id = model.insert_all([ atributos ], returning: :id).rows.first.first
    model.find(id)
  end

  # Reescreve o `ancestry` de uma unidade já inserida (o model é readonly; a
  # conexão `pessoas` aceita UPDATE dentro da transação de teste).
  def definir_ancestry(unidade_id, ancestry)
    Pessoas::Unidade.connection.execute(
      "UPDATE unidades SET ancestry = #{Pessoas::Unidade.connection.quote(ancestry)} WHERE id = #{unidade_id.to_i}"
    )
  end

  # --- usuários e gestores ---------------------------------------------------

  def criar_usuario(cpf: nil, admin: false, roles: [])
    user = User.create!(
      nome_completo: "Usuario #{SecureRandom.hex(3)}",
      password: "123456",
      cpf: cpf,
      admin: admin
    )
    roles.each { |role| user.add_role(role) }
    user
  end

  # User local com o CPF da pessoa (ponte CPF ↔ Pessoas).
  def usuario_pessoa(pessoa)
    criar_usuario(cpf: pessoa.cpf)
  end

  def gestor_individual(gerido:, gestor_user: nil, gestor_cpf: nil, ativo: true)
    gestor = GestorIndividual.create!(
      nome: "Gestor Teste",
      gestor_user: gestor_user,
      gestor_cpf: gestor_cpf
    )
    vinculo = GestorIndividualGerenciado.create!(gestor_individual: gestor, user: gerido)
    vinculo.desativar! unless ativo
    vinculo
  end

  # --- infra de medição ------------------------------------------------------

  # Conta queries SQL de DADOS disparadas dentro do bloco (guarda de N+1).
  def contar_queries
    contador = 0
    callback = lambda do |*args|
      payload = args.last
      sql = payload[:sql].to_s
      # Ignora queries de schema/transação — só as de dados entram na conta.
      contador += 1 if payload[:name] != "SCHEMA" && sql !~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    contador
  end

  def proximo_cpf_teste
    PessoasEspelhoHelper.proximo_cpf
  end
end
