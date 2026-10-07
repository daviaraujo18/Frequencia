require "test_helper"

# Tarefa 30.10 (Sprint 30, frente 5) — garante o `User` local dos gestores de
# unidade a partir do Pessoas.
#
# Os testes INJETAM as unidades/gestores via `unidades:` — NUNCA tocam o
# Pessoas real (o serviço só cai no caminho de leitura quando `unidades` é
# omitido, exercitado apenas no teste de falha de leitura, com stub).
#
# Cobrem: DRY_RUN sem escrita, idempotência (2ª execução = 0 criações), criação
# para gestor SEM lotação vigente (o furo), dedup por CPF, relatório sem PII,
# só gestores tocados, contabilidade fechada e falha de leitura sinalizada.
class ImportarGestoresDeUnidadeServiceTest < ActiveSupport::TestCase
  # --------------------------------------------------------------- doubles

  # Pessoa do Pessoas: só o que o serviço/cache leem (cpf, nome, username,
  # id, vinculos_ativos).
  PessoaDouble = Struct.new(:id, :cpf, :nome, :username, :vinculos_ativos, keyword_init: true)

  # Unidade do Pessoas: os 3 pares (id da coluna + associação homônima).
  UnidadeDouble = Struct.new(
    :gestor_id, :gestor,
    :gestor_substituto_id, :gestor_substituto,
    :gestor_excepcional_id, :gestor_excepcional,
    keyword_init: true
  )

  def pessoa(cpf: nil, nome: "Gestor Teste", username: nil, id: 1, vinculos_ativos: [])
    PessoaDouble.new(id: id, cpf: cpf, nome: nome, username: username, vinculos_ativos: vinculos_ativos)
  end

  # Unidade com os gestores informados (os demais ficam nil, como no banco).
  def unidade(gestor: nil, substituto: nil, excepcional: nil)
    UnidadeDouble.new(
      gestor_id: gestor&.id, gestor: gestor,
      gestor_substituto_id: substituto&.id, gestor_substituto: substituto,
      gestor_excepcional_id: excepcional&.id, gestor_excepcional: excepcional
    )
  end

  # Passa `unidades:` direto ao serviço (porta de injeção) — sem tocar o Pessoas.
  def importar(unidades:, dry_run: false)
    ImportarGestoresDeUnidadeService.call(unidades: unidades, dry_run: dry_run)
  end

  # Stub do seam de leitura do Pessoas (`ImportarGestoresDeUnidadeService
  # .unidades_do_pessoas`, um `def self.` OWN) para simular indisponibilidade
  # SEM tocar o banco. Usa o helper capturar/restaurar — NUNCA `remove_method`
  # (lição da chore de stubs destrutivos; ver class_method_stub_helper.rb).
  def com_pessoas_indisponivel
    stub_que_explode = -> { raise ActiveRecord::StatementInvalid, "Pessoas indisponivel (stub de teste)" }
    com_metodo_de_classe_stubado(ImportarGestoresDeUnidadeService, :unidades_do_pessoas, stub_que_explode) do
      yield
    end
  end

  # --------------------------------------------------------------- testes

  # 1. DRY_RUN não escreve: projeta a criação e não toca User/cache.
  test "dry-run nao escreve: projeta a criacao e nao cria User nem cache" do
    p = pessoa(cpf: "11111111111", nome: "Gestor Um", id: 11)

    resultado = importar(unidades: [ unidade(gestor: p) ], dry_run: true)

    assert_equal 1, resultado.processados
    assert_equal 1, resultado.atribuidos
    assert_equal 0, resultado.sem_alteracao
    assert_equal 0, User.where(cpf: "11111111111").count, "dry-run NAO pode criar User"
    assert_equal 0, FrequentadorCache.where(cpf: "11111111111").count, "dry-run NAO pode criar cache"
  end

  # 2. O FURO: gestor SEM lotação vigente ganha User local (o job por lotação
  # nunca o importaria). Discriminador: `vinculos_ativos` vazio.
  test "cria User local para gestor SEM lotacao vigente (o furo)" do
    p = pessoa(cpf: "22222222222", nome: "Gestor Sem Lotacao", id: 22, vinculos_ativos: [])

    resultado = importar(unidades: [ unidade(gestor: p) ])

    assert_equal 1, resultado.atribuidos
    user = User.find_by(cpf: "22222222222")
    assert user.present?, "o gestor sem lotacao precisa ter User local"
    assert_equal "Gestor Sem Lotacao", user.nome_completo
    assert FrequentadorCache.find_by(cpf: "22222222222").present?
  end

  # 3. Idempotência: 2ª execução = 0 criações.
  test "segunda execucao nao cria nenhum User novo" do
    p = pessoa(cpf: "33333333333", nome: "Gestor Idempotente", username: "gestor.idem", id: 33)

    primeira = importar(unidades: [ unidade(gestor: p) ])
    assert_equal 1, primeira.atribuidos
    assert_equal 0, primeira.sem_alteracao

    segunda = importar(unidades: [ unidade(gestor: p) ])
    assert_equal 0, segunda.atribuidos, "2a execucao: nenhuma criacao"
    assert_equal 1, segunda.sem_alteracao
    assert_equal 1, User.where(cpf: "33333333333").count
    assert_equal 1, FrequentadorCache.where(cpf: "33333333333").count
  end

  # 4. NÃO sobrescreve User existente.
  test "nao sobrescreve User existente pelo cpf" do
    existente = User.create!(nome_completo: "Ja Existia", password: "123456", cpf: "44444444444")
    p = pessoa(cpf: "44444444444", nome: "Nome Novo Do Pessoas", id: 44)

    resultado = importar(unidades: [ unidade(gestor: p) ])

    assert_equal 0, resultado.atribuidos
    assert_equal 1, resultado.sem_alteracao
    assert_equal "Ja Existia", existente.reload.nome_completo
    assert_equal 1, User.where(cpf: "44444444444").count
  end

  # 5. Usa o username real do Pessoas.
  test "usa o username real vindo do Pessoas ao criar o User" do
    p = pessoa(cpf: "55555555555", nome: "Fulano Gestor", username: "fulano.gestor", id: 55)

    importar(unidades: [ unidade(gestor: p) ])

    assert_equal "fulano.gestor", User.find_by(cpf: "55555555555").username
  end

  # 6. Dedup por CPF: mesma pessoa (2 ids distintos) em gestor e substituto é
  # UM gestor só.
  test "deduplica por CPF gestores repetidos em associacoes distintas" do
    gestor = pessoa(cpf: "66666666666", nome: "Gestor Repetido", id: 700)
    substituto = pessoa(cpf: "66666666666", nome: "Gestor Repetido", id: 701)

    resultado = importar(unidades: [ unidade(gestor: gestor, substituto: substituto) ])

    assert_equal 1, resultado.processados, "mesmo CPF nao pode contar duas vezes"
    assert_equal 1, resultado.atribuidos
    assert_equal 1, User.where(cpf: "66666666666").count
  end

  # 7. Gestor sem CPF vira não-resolvido, e o relatório NÃO vaza PII.
  test "gestor sem CPF vai ao relatorio e o resumo nao vaza PII" do
    p = pessoa(cpf: nil, nome: "Fulano Sem Cpf", username: "fulano.semcpf", id: 80)

    resultado = importar(unidades: [ unidade(gestor: p) ])

    assert_equal 0, resultado.atribuidos
    assert_equal 1, resultado.nao_resolvidos.size
    assert_match(/sem CPF/, resultado.nao_resolvidos.first.motivo)
    refute_includes resultado.resumo, "Fulano Sem Cpf"
    refute_includes resultado.resumo, "fulano.semcpf"
    assert_match(/1x gestor sem CPF no Pessoas/, resultado.resumo)
  end

  # 8. FK órfã: id de gestor presente mas pessoa ausente no Pessoas.
  test "gestor com vinculo orfao (pessoa ausente) vai ao relatorio" do
    orfa = UnidadeDouble.new(gestor_id: 999, gestor: nil)

    resultado = importar(unidades: [ orfa ])

    assert_equal 1, resultado.processados
    assert_equal 1, resultado.nao_resolvidos.size
    assert_match(/ausente/, resultado.nao_resolvidos.first.motivo)
  end

  # 9. Unidade sem nenhum gestor não gera gestor algum.
  test "unidade sem gestores nao gera processados" do
    resultado = importar(unidades: [ unidade ])

    assert_equal 0, resultado.processados
    assert_equal 0, resultado.nao_resolvidos.size
    assert_equal 0, resultado.atribuidos
  end

  # 10. Só os gestores enumerados são tocados.
  test "somente os gestores enumerados ganham User" do
    p = pessoa(cpf: "77777777777", nome: "Gestor Unico", id: 77)

    resultado = importar(unidades: [ unidade(gestor: p) ])

    assert_equal 1, resultado.atribuidos
    assert User.find_by(cpf: "77777777777").present?
    assert_nil User.find_by(cpf: "88888888888"), "CPF que nao e gestor nao pode ser criado"
  end

  # 11. Contabilidade fechada: todo gestor enumerado vira um destino.
  test "contabilidade fechada entre processados e destinos" do
    ok = pessoa(cpf: "12121212121", nome: "Gestor Ok", id: 121)
    sem_cpf = pessoa(cpf: nil, nome: "Sem Cpf", id: 122)

    resultado = importar(unidades: [ unidade(gestor: ok), unidade(excepcional: sem_cpf) ])

    assert_equal 2, resultado.processados
    assert_equal resultado.processados, resultado.total_contabilizado
  end

  # 12. Erro (colisão de username) é contado e NÃO aborta o lote.
  test "colisao de username vira erro sem abortar os demais gestores" do
    User.create!(nome_completo: "Dono Do Username", password: "123456", username: "colide.aqui")
    colidente = pessoa(cpf: "99999999999", nome: "Colidente", username: "colide.aqui", id: 950)
    bom = pessoa(cpf: "99999999998", nome: "Sem Colisao", username: "sem.colisao", id: 951)

    resultado = importar(unidades: [ unidade(gestor: colidente), unidade(gestor: bom) ])

    assert_equal 1, resultado.erros
    assert_equal 1, resultado.atribuidos
    assert_nil User.find_by(cpf: "99999999999")
    assert User.find_by(cpf: "99999999998").present?
    assert_equal resultado.processados, resultado.total_contabilizado
  end

  # 13. Falha de LEITURA do Pessoas != leitura vazia.
  test "falha de leitura do Pessoas e sinalizada (nao confunde com vazio)" do
    com_pessoas_indisponivel do
      # Sem `unidades:` -> exercita o caminho de leitura do Pessoas.
      resultado = ImportarGestoresDeUnidadeService.call

      assert resultado.falha_leitura, "leitura indisponivel deve sinalizar falha_leitura"
      assert_equal 0, resultado.processados
      assert_match(/FALHA DE LEITURA/, resultado.resumo,
                   "o relatorio deve dizer explicitamente que a leitura falhou")
    end
  end

  test "leitura vazia explicita nao e falha de leitura" do
    resultado = importar(unidades: [])

    refute resultado.falha_leitura, "lista vazia injetada NAO e falha de leitura"
    assert_equal 0, resultado.processados
  end
end
