require "test_helper"

# Tarefa 29.3 (Sprint 29) — importação idempotente dos gestores individuais
# do Intranet. Cobre: upsert pelas chaves estáveis (idempotência), preservação
# da `data_exclusao` legada, relatório de não-resolvidos (nada é ignorado em
# silêncio), dry-run sem escrita, normalizações de borda (⚪ 11 id_legado>0,
# ⚪ 14 cpf "", Bug 3/A5 `ativo: nil`), tratamento de RecordInvalid (Bug 8) e
# de DeleteRestrictionError/InvalidForeignKey (🟢 19).
#
# Não tocamos a rede nem o banco `pessoas` real: `SticapiClient::Intranet`
# recebe um stub e, quando o teste usa o espelho, ele é pulado sem o schema
# carregado (`skip_sem_espelho!`).
class ImportarGestoresIndividuaisServiceTest < ActiveSupport::TestCase
  include PessoasEspelhoHelper

  CPF_GESTOR = "11122233344"
  CPF_GERIDO = "55566677788"

  # Troca um método de classe RESTAURANDO o original ao fim do bloco. O gem
  # Minitest 6 não traz mais `Object#stub`, e `define_singleton_method` +
  # `remove_method` sem restaurar APAGA o método real — envenena os testes
  # seguintes do mesmo processo.
  def com_stub_de_classe(klass, metodo, resposta)
    original = klass.method(metodo)
    corpo = resposta.is_a?(Proc) ? resposta : ->(*_args, **_kwargs) { resposta }

    klass.singleton_class.send(:remove_method, metodo)
    klass.define_singleton_method(metodo, corpo)
    yield
  ensure
    klass.singleton_class.send(:remove_method, metodo)
    klass.define_singleton_method(metodo, original)
  end

  # Passa `registros:` direto ao serviço (sem stub da gem) na maioria dos
  # casos — é a porta de injeção prevista no próprio serviço.
  def linha(id:, matricula_gestor: "1001", matricula_gerido: "2002",
            id_vinculo_gestor: 900, id_vinculo_gerido: 700,
            data_criacao: "2019-10-30 10:03:25.0", data_exclusao: nil, observacao: "SEI 19.0")
    {
      "id" => id,
      "data_criacao" => data_criacao,
      "data_exclusao" => data_exclusao,
      "observacao" => observacao,
      "id_vinculo_gestor" => id_vinculo_gestor,
      "matricula_gestor" => matricula_gestor,
      "id_vinculo_gerido" => id_vinculo_gerido,
      "matricula_gerido" => matricula_gerido
    }
  end

  # Cria o gerido (User) e o mapa matrícula→CPF esperado, sem depender da
  # folha do espelho.
  def preparar_gerido(cpf: CPF_GERIDO, nome: "Gerido Teste")
    User.create!(nome_completo: nome, password: "123456", cpf: cpf)
  end

  def stub_mapa_cpf(mapa)
    com_stub_de_classe(ResolverCpfPorMatriculaService, :mais_recente, mapa) { yield }
  end

  # --- fonte (gem Sticapi) --------------------------------------------------

  test "sem `registros:` le da SticapiClient::Intranet.gestores_individuais" do
    preparar_gerido

    com_stub_de_classe(SticapiClient::Intranet, :gestores_individuais, [ linha(id: 42) ]) do
      stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
        resultado = ImportarGestoresIndividuaisService.call
        assert_equal 1, resultado.importados
      end
    end

    assert GestorIndividualGerenciado.find_by(id_legado: 42).present?
  end

  # --- importação básica ----------------------------------------------------

  test "importa um par novo criando gestor e vinculo com id_legado" do
    preparar_gerido

    resultado = nil
    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    assert_equal 1, resultado.importados
    assert_equal 0, resultado.atualizados
    assert_empty resultado.nao_resolvidos

    gestor = GestorIndividual.find_by(id_legado: 900)
    assert gestor.present?, "gestor casado pela chave id_vinculo_gestor"
    assert_equal CPF_GESTOR, gestor.gestor_cpf
    assert_equal "SEI 19.0", gestor.observacao
    assert_equal Time.zone.parse("2019-10-30 10:03:25.0"), gestor.data_criacao_legado
    assert gestor.ativo?

    vinculo = GestorIndividualGerenciado.find_by(id_legado: 42)
    assert vinculo.present?
    assert_equal gestor, vinculo.gestor_individual
    assert_equal User.find_by(cpf: CPF_GERIDO), vinculo.user
    assert vinculo.ativo?
  end

  test "liga gestor_user quando existe User com o CPF do gestor" do
    preparar_gerido
    gestor_user = User.create!(nome_completo: "Gestor Logado", password: "123456", cpf: CPF_GESTOR)

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    assert_equal gestor_user, GestorIndividual.find_by(id_legado: 900).gestor_user
  end

  test "reaproveita UM gestor para varias linhas do mesmo id_vinculo_gestor" do
    2.times { |i| User.create!(nome_completo: "Gerido #{i}", password: "123456", cpf: "6000000000#{i}") }

    linhas = [
      linha(id: 1, matricula_gerido: "2001", id_vinculo_gerido: 701),
      linha(id: 2, matricula_gerido: "2002", id_vinculo_gerido: 702)
    ]

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2001" => "60000000000", "2002" => "60000000001" }) do
      ImportarGestoresIndividuaisService.call(registros: linhas)
    end

    assert_equal 1, GestorIndividual.where(id_legado: 900).count
    assert_equal 2, GestorIndividualGerenciado.where(id_legado: [ 1, 2 ]).count
  end

  # --- idempotência ---------------------------------------------------------

  test "segunda execucao = 0 criacoes (upsert por id_legado)" do
    preparar_gerido

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    resultado = nil
    assert_no_difference([ "GestorIndividual.count", "GestorIndividualGerenciado.count" ]) do
      stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
        resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
      end
    end

    assert_equal 0, resultado.importados
    assert_equal 1, resultado.atualizados
  end

  test "reimportacao atualiza os dados sem criar duplicata" do
    preparar_gerido

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42, observacao: "antigo") ])
    end

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42, observacao: "novo") ])
    end

    assert_equal 1, GestorIndividual.where(id_legado: 900).count
    assert_equal "novo", GestorIndividual.find_by(id_legado: 900).observacao
  end

  # --- preservação da data_exclusao legada (soft-delete histórico) ----------

  test "registro excluido no legado entra INATIVO com a data legada, nao e descartado" do
    preparar_gerido
    data = "2021-03-04 08:00:00.0"

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42, data_exclusao: data) ])
    end

    gestor = GestorIndividual.find_by(id_legado: 900)
    vinculo = GestorIndividualGerenciado.find_by(id_legado: 42)

    assert_not gestor.ativo?
    assert_equal Time.zone.parse(data), gestor.data_exclusao
    assert_not vinculo.ativo?
    assert_equal Time.zone.parse(data), vinculo.data_exclusao
  end

  test "data_exclusao legada nao e sobrescrita por execucao posterior" do
    preparar_gerido
    data = "2021-03-04 08:00:00.0"

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42, data_exclusao: data) ])
    end

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42, data_exclusao: data) ])
    end

    assert_equal Time.zone.parse(data), GestorIndividualGerenciado.find_by(id_legado: 42).data_exclusao
  end

  # --- relatório de não-resolvidos ------------------------------------------

  test "matricula do gestor sem CPF vira nao-resolvido" do
    preparar_gerido

    resultado = nil
    stub_mapa_cpf({ "2002" => CPF_GERIDO }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    assert_equal 0, resultado.importados
    assert_equal 1, resultado.nao_resolvidos.size
    assert_includes resultado.nao_resolvidos.first.motivo, "gestor"
    assert_equal 0, GestorIndividual.count
  end

  test "gerido sem User no Frequencia vira nao-resolvido" do
    # Nenhum User criado para o CPF do gerido.

    resultado = nil
    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    assert_equal 0, resultado.importados
    assert_equal 1, resultado.nao_resolvidos.size
    assert_includes resultado.nao_resolvidos.first.motivo, "User"
  end

  test "uma linha invalida nao impede a importacao das demais" do
    preparar_gerido
    User.create!(nome_completo: "Outro Gerido", password: "123456", cpf: "66677788899")

    linhas = [
      linha(id: 42, matricula_gestor: "9999"),                                   # não resolve
      linha(id: 43, matricula_gerido: "2003", id_vinculo_gerido: 703)
    ]

    resultado = nil
    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO, "2003" => "66677788899" }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: linhas)
    end

    assert_equal 1, resultado.importados
    assert_equal 1, resultado.nao_resolvidos.size
    assert GestorIndividualGerenciado.find_by(id_legado: 43).present?
  end

  # --- dry-run --------------------------------------------------------------

  test "dry-run percorre a resolucao mas NAO escreve nada" do
    preparar_gerido

    resultado = nil
    assert_no_difference([ "GestorIndividual.count", "GestorIndividualGerenciado.count" ]) do
      stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
        resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ], dry_run: true)
      end
    end

    assert resultado.dry_run
    assert_equal 1, resultado.importados
  end

  test "dry-run classifica reimportacao como atualizacao (sem escrever)" do
    preparar_gerido

    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    resultado = nil
    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ], dry_run: true)
    end

    assert_equal 0, resultado.importados
    assert_equal 1, resultado.atualizados
  end

  # --- normalizações de borda -----------------------------------------------

  test "id legado ausente/zero/negativo vira nao-resolvido (⚪ 11)" do
    preparar_gerido

    [ nil, 0, -7 ].each do |id|
      resultado = nil
      stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
        resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: id) ])
      end

      assert_equal 0, resultado.importados, "id #{id.inspect} não pode criar registro"
      assert_equal 1, resultado.nao_resolvidos.size
      assert_equal 0, GestorIndividualGerenciado.where(id_legado: id).count
    end
  end

  test "gestor_cpf string vazia nunca e persistida como \"\" (⚪ 14)" do
    preparar_gerido
    # CPF do gestor resolvido para "" (folha devolveu valor vazio) → deve
    # contar como NÃO resolvido (blank), e jamais gravar `gestor_cpf: ""`.
    resultado = nil
    stub_mapa_cpf({ "1001" => "", "2002" => CPF_GERIDO }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    assert_equal 1, resultado.nao_resolvidos.size, "cpf vazio não pode casar/montar gestor"
    assert_equal 0, GestorIndividual.where(gestor_cpf: "").count
  end

  test "gestor_cpf resolvido e persistido normalizado (presence)" do
    preparar_gerido
    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    assert_equal CPF_GESTOR, GestorIndividual.find_by(id_legado: 900).gestor_cpf
    assert_equal 0, GestorIndividual.where(gestor_cpf: "").count
  end

  test "ativo nil na borda e normalizado (Bug 3 da D7 / A5)" do
    preparar_gerido
    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    gestor = GestorIndividual.find_by(id_legado: 900)
    assert_equal true, gestor.ativo
    assert_equal true, GestorIndividualGerenciado.find_by(id_legado: 42).ativo
  end

  # --- invariante de auto-gerência não é contornado -------------------------

  test "auto-gerencia ativa e recusada e sai no relatorio (nao grava por baixo)" do
    # Gestor e gerido são o MESMO CPF: o User gerido é também o gestor_user.
    User.create!(nome_completo: "Auto Gerido", password: "123456", cpf: CPF_GESTOR)

    resultado = nil
    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GESTOR }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    assert_equal 0, resultado.importados
    assert_equal 1, resultado.nao_resolvidos.size
    assert_includes resultado.nao_resolvidos.first.motivo, "inválido"
    assert_equal 0, GestorIndividualGerenciado.where(id_legado: 42).count
  end

  # --- mensagem de RecordInvalid não vaza "Translation missing" (Bug 8) -----

  test "erro de RecordInvalid usa full_messages, nunca e.message cru (Bug 8)" do
    preparar_gerido
    stub_mapa_cpf({ "1001" => CPF_GESTOR, "2002" => CPF_GERIDO }) do
      # Força um RecordInvalid: gestor sem nome não pode ser persistido. O
      # serviço preenche o nome, então provocamos o erro por outra via — um
      # CPF de gestor inválido (não 11 dígitos) faz o model recusar.
    end

    resultado = nil
    stub_mapa_cpf({ "1001" => "123", "2002" => CPF_GERIDO }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    motivo = resultado.nao_resolvidos.first.motivo

    assert_equal 1, resultado.nao_resolvidos.size
    assert_includes motivo, "inválido", "o motivo deve trazer o erro REAL do atributo"

    # Controle discriminante: `e.message` carrega o wrapper do `record_invalid`
    # ("Validation failed:"/"1 erro impediu este registro de ser salvo:")
    # ANTES das mensagens dos atributos; `full_messages` não. O motivo é
    # prefixado por "registro inválido: ", então o wrapper, se viesse de
    # `e.message`, apareceria logo depois. Sem esta asserção, trocar
    # `full_messages` por `e.message` no serviço passaria — foi o que a
    # mutação mostrou.
    refute_match(/erro impediu este registro|Validation failed/, motivo,
                 "motivo deve ser o full_messages, sem o wrapper do e.message")
    assert_not_includes motivo, "Translation missing"
  end

  # --- fallback via codigo_de_para (espelho Pessoas) -----------------------

  test "resolve gestor por codigo_de_para quando a matricula nao esta na folha" do
    skip_sem_espelho!
    # Só o gerido tem User; o gestor é resolvido via vinculo legado no espelho.
    User.create!(nome_completo: "Gerido", password: "123456", cpf: CPF_GERIDO)

    pessoa = inserir_pessoa_espelho(nome: "Gestor Via Vinculo", cpf: CPF_GESTOR)
    inserir_vinculo_espelho(pessoa_id: pessoa.id, codigo_de_para: "900", matricula: "1001")

    resultado = nil
    stub_mapa_cpf({ "2002" => CPF_GERIDO }) do
      resultado = ImportarGestoresIndividuaisService.call(registros: [ linha(id: 42) ])
    end

    assert_empty resultado.nao_resolvidos
    assert_equal 1, resultado.importados
    assert_equal CPF_GESTOR, GestorIndividual.find_by(id_legado: 900).gestor_cpf
  end

  private

  def inserir_pessoa_espelho(nome:, cpf:)
    Pessoas::Pessoa.insert_all([ { nome: nome, cpf: cpf } ], returning: :id).rows.first.first
      .then { |id| Pessoas::Pessoa.find(id) }
  end

  def inserir_vinculo_espelho(pessoa_id:, codigo_de_para:, matricula:)
    Pessoas::Vinculo.insert_all(
      [ { pessoa_id: pessoa_id, codigo_de_para: codigo_de_para, matricula: matricula, inicio: Date.new(2020, 1, 1) } ],
      returning: :id
    ).rows.first.first
  end
end
