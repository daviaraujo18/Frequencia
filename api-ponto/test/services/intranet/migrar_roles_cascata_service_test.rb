require "test_helper"

# Tarefa 30.9b (Sprint 30) — migração 1:1 das 2 roles da cascata a partir do
# Intranet legado (ruling D-6 = (i)).
#
# Os testes INJETAM as linhas via `atribuicoes:` — NUNCA tocam a rede nem o
# banco do legado (o serviço nunca é chamado sem injeção para ler do MySQL).
# Cobrem: dry-run sem escrita, idempotência (2ª execução = 0 criações),
# relatório de não-resolvidos, fechamento do mapeamento (só as 2 roles) e a
# inércia sob `:off`/`:shadow`.
class Intranet::MigrarRolesCascataServiceTest < ActiveSupport::TestCase
  # --------------------------------------------------------------- helpers

  def linha(login:, role_legado:)
    { login: login, role_legado: role_legado }
  end

  def criar_user(username:, cpf: nil)
    User.create!(
      nome_completo: "Usuario #{username}",
      password: "123456",
      username: username,
      cpf: cpf
    )
  end

  # Passa `atribuicoes:` direto ao serviço (porta de injeção) — sem rede.
  def migrar(atribuicoes:, dry_run: false)
    Intranet::MigrarRolesCascataService.call(atribuicoes: atribuicoes, dry_run: dry_run)
  end

  # Stub de `Mysql2::Client.new` (método HERDADO de `Class`, não OWN) para
  # simular indisponibilidade do legado SEM tocar a rede. Para métodos herdados
  # o `remove_method` no `ensure` é SEGURO (cai de volta no `Class#new`) — ao
  # contrário dos scopes/`def self.` (ver test/support/class_method_stub_helper.rb).
  def com_mysql_indisponivel
    require "mysql2"
    Mysql2::Client.define_singleton_method(:new) do |*|
      raise Mysql2::Error, "conexao indisponivel (stub de teste)"
    end
    yield
  ensure
    Mysql2::Client.singleton_class.send(:remove_method, :new)
  end

  # A variável de ambiente é estado GLOBAL do processo: restaura o valor
  # anterior no `ensure` para não contaminar os testes seguintes do worker.
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

  # Host mínimo que inclui o concern da cascata para exercitar
  # `restringir_frequencia` fora de um controller (é o ponto que curto-circuita
  # em `:off`/`:shadow`).
  class HostComCascata
    include FrequenciaAuthorization

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end
  end

  # --------------------------------------------------------------- testes

  # 1. Dry-run não escreve (nenhum `add_role`).
  test "dry-run nao escreve: conta a atribuicao projetada e nao toca o user" do
    user = criar_user(username: "usuario.sec.unico")
    rows = [ linha(login: "usuario.sec.unico", role_legado: "presencaVisualizaFrequentadores") ]

    resultado = migrar(atribuicoes: rows, dry_run: true)

    assert_equal 1, resultado.processados
    assert_equal 1, resultado.atribuidos
    assert_equal 0, resultado.sem_alteracao
    refute user.reload.has_role?(:visualiza_frequentadores),
           "dry-run NAO pode atribuir a role"
    assert_equal 0, user.roles.count
  end

  # 2. Idempotência: 2ª execução = 0 criações.
  test "segunda execucao nao cria nenhuma atribuicao nova" do
    user = criar_user(username: "usuario.sec.unico")
    rows = [ linha(login: "usuario.sec.unico", role_legado: "presencaVisualizaFrequentadores") ]

    primeira = migrar(atribuicoes: rows)
    assert_equal 1, primeira.atribuidos
    assert_equal 0, primeira.sem_alteracao
    assert user.reload.has_role?(:visualiza_frequentadores)
    assert_equal 1, user.roles.count

    segunda = migrar(atribuicoes: rows)
    assert_equal 0, segunda.atribuidos, "2a execucao: nenhuma criacao"
    assert_equal 1, segunda.sem_alteracao
    assert_equal 1, user.reload.roles.count, "nenhuma role duplicada"
  end

  # 3. Não-resolvidos vão ao relatório (nada é silenciosamente ignorado).
  test "login legado sem User local vai ao relatorio de nao resolvidos" do
    rows = [ linha(login: "login.sem.user.local", role_legado: "presencaVisualizaFrequentadores") ]

    resultado = migrar(atribuicoes: rows)

    assert_equal 1, resultado.processados
    assert_equal 0, resultado.atribuidos
    assert_equal 1, resultado.nao_resolvidos.size
    assert_equal "login.sem.user.local", resultado.nao_resolvidos.first.login
    assert_match(/sem User local/, resultado.nao_resolvidos.first.motivo)
    assert_equal resultado.processados, resultado.total_contabilizado
  end

  # 4. Só as 2 roles são tocadas — uma 3ª role do legado NÃO vira role local.
  test "role legado fora do escopo nao vira role local" do
    user = criar_user(username: "usuario.sec.unico")
    rows = [ linha(login: "usuario.sec.unico", role_legado: "presencaGerenciaFrequentadores") ]

    resultado = migrar(atribuicoes: rows)

    assert_equal 0, resultado.atribuidos
    assert_equal 1, resultado.nao_resolvidos.size
    assert_equal 0, user.reload.roles.count, "nenhuma role local criada para role fora do escopo"
    refute Role.exists?(name: "presencaGerenciaFrequentadores"),
           "o nome legado nao pode virar role local"
  end

  test "o mapeamento e fechado nas exatamente 2 roles da cascata" do
    assert_equal %w[presencaVisualizaFrequentadores presencaVisualizaFrequentadoresTerceirizados],
                 Intranet::MigrarRolesCascataService::MAPEAMENTO.keys.sort
    assert_equal %i[visualiza_frequentadores visualiza_terceirizados],
                 Intranet::MigrarRolesCascataService::MAPEAMENTO.values.sort
  end

  test "migra as duas roles (frequentadores e terceirizados)" do
    um = criar_user(username: "usuario.sec.unico")
    dois = criar_user(username: "usuario.sec.dois")
    rows = [
      linha(login: "usuario.sec.unico", role_legado: "presencaVisualizaFrequentadores"),
      linha(login: "usuario.sec.dois", role_legado: "presencaVisualizaFrequentadoresTerceirizados")
    ]

    resultado = migrar(atribuicoes: rows)

    assert_equal 2, resultado.atribuidos
    assert um.reload.has_role?(:visualiza_frequentadores)
    assert dois.reload.has_role?(:visualiza_terceirizados)
  end

  # Casamento: fallback por CPF quando o login do legado é o próprio CPF.
  test "casa por CPF quando o login legado e um CPF" do
    cpf = "11122233344"
    user = criar_user(username: "usuario.sec.cpf", cpf: cpf)
    rows = [ linha(login: cpf, role_legado: "presencaVisualizaFrequentadoresTerceirizados") ]

    resultado = migrar(atribuicoes: rows)

    assert_equal 1, resultado.atribuidos
    assert user.reload.has_role?(:visualiza_terceirizados)
  end

  # Casamento case-insensitive (mesmo critério do login do app).
  test "casa o login ignorando a caixa (lower(username))" do
    user = criar_user(username: "usuario.sec.unico")
    rows = [ linha(login: "USUARIO.SEC.UNICO", role_legado: "presencaVisualizaFrequentadores") ]

    resultado = migrar(atribuicoes: rows)

    assert_equal 1, resultado.atribuidos
    assert user.reload.has_role?(:visualiza_frequentadores)
  end

  # O relatório não vaza PII (login).
  test "o resumo nao imprime o login (PII)" do
    rows = [ linha(login: "login.sem.user.local", role_legado: "presencaVisualizaFrequentadores") ]

    resultado = migrar(atribuicoes: rows)

    refute_includes resultado.resumo, "login.sem.user.local"
  end

  # S2: falha de LEITURA do legado != leitura vazia. Sem esta distinção, a rake
  # reportaria "0 processados" com exit 0 e o operador acharia que migrou.
  test "falha de leitura do legado e sinalizada (nao confunde com leitura vazia)" do
    com_mysql_indisponivel do
      # Sem `atribuicoes:` -> exercita o caminho de leitura do legado.
      resultado = Intranet::MigrarRolesCascataService.call

      assert resultado.falha_leitura, "leitura indisponivel deve sinalizar falha_leitura"
      assert_equal 0, resultado.processados
      assert_match(/FALHA DE LEITURA/, resultado.resumo,
                   "o relatorio deve dizer explicitamente que a leitura falhou")
    end
  end

  test "leitura vazia explicita nao e falha de leitura" do
    resultado = Intranet::MigrarRolesCascataService.call(atribuicoes: [])

    refute resultado.falha_leitura, "lista vazia injetada NAO e falha de leitura"
    assert_equal 0, resultado.processados
  end

  # 5. Inerte sob `:off`/`:shadow` — atribuir as roles não altera o
  # comportamento de `restringir_frequencia`, que curto-circuita ANTES de
  # tocar o Pessoas. Discriminador: o stub do Pessoas LEVANTA se for chamado.
  #
  # ⚠️ LIÇÃO 33 (teste NÃO-degenerado, S1 do review da 30.9b): a role migrada
  # aqui é `visualiza_terceirizados` (passo 3), NÃO `visualiza_frequentadores`.
  # A role geral FARIA `frequencia_visao_global?` retornar true e curto-circuitar
  # o `restringir_frequencia` ANTES do guard da linha 47 — o teste passaria
  # mesmo com o guard mutado. Com a role de terceirizados, `frequencia_visao_global?`
  # é false (precondição asserida), então o ÚNICO curto-circuito possível em
  # :off/:shadow é a linha 47; o stub que levanta passa a ser discriminador
  # real (mutar a linha 47 mata o teste).
  test "atribuir as roles e inerte sob :off (restringir_frequencia curto-circuita)" do
    user = criar_user(username: "usuario.sec.unico")
    rows = [ linha(login: "usuario.sec.unico", role_legado: "presencaVisualizaFrequentadoresTerceirizados") ]
    migrar(atribuicoes: rows)
    assert user.reload.has_role?(:visualiza_terceirizados), "pre-condicao: role atribuida"

    host = HostComCascata.new(user)
    # Precondição do DISCRIMINADOR: a role migrada NÃO dá visão global. Sem
    # isso, a queda no `frequencia_visao_global?` (linha 48) mascararia a linha 47.
    refute host.send(:frequencia_visao_global?),
           "a role visualiza_terceirizados NAO pode dar visao global"

    relacao = TimeRecord.all
    stub_que_explode = ->(*) { raise "Pessoas NAO pode ser consultado em :off/:shadow" }

    com_flag(nil) do
      com_metodo_de_classe_stubado(Pessoas::Vinculo, :cpfs_frequentadores_visiveis, stub_que_explode) do
        assert_same relacao, host.send(:restringir_frequencia, relacao)
      end
    end

    com_flag("shadow") do
      com_metodo_de_classe_stubado(Pessoas::Vinculo, :cpfs_frequentadores_visiveis, stub_que_explode) do
        assert_same relacao, host.send(:restringir_frequencia, relacao)
      end
    end
  end
end
