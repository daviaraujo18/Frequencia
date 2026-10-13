require "test_helper"

# Sprint 31, task 31.1 — fila persistente de recálculo por evento (PRD §5.2).
# Cobre: constantes (7 tipos, 3 adiados), validações, IDEMPOTÊNCIA do
# `enfileirar!` (incluindo a corrida tratada no banco) e o meta-teste que
# prova que NENHUM código de produção cria tarefa de tipo adiado.
class TarefaRecalculoTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------- constantes

  test "TIPOS_ENTIDADE cobre exatamente os 7 tipos do PRD 5.2" do
    esperados = %w[
      FERIADO DIAEXCEPCIONAL DIREITO VINCULAR_DESVINCULAR
      REGISTRO_FREQUENCIA REGISTRO_ESTACAO RECALCULAR_TODOS
    ]
    assert_equal esperados.sort, TarefaRecalculo::TIPOS_ENTIDADE.sort
    assert_equal 7, TarefaRecalculo::TIPOS_ENTIDADE.size
  end

  test "TIPOS_ADIADOS isola exatamente os 3 tipos sem domínio" do
    assert_equal %w[DIREITO DIAEXCEPCIONAL FERIADO].sort, TarefaRecalculo::TIPOS_ADIADOS.sort
  end

  test "TIPOS_ADIADOS e um subconjunto de TIPOS_ENTIDADE" do
    assert_empty TarefaRecalculo::TIPOS_ADIADOS - TarefaRecalculo::TIPOS_ENTIDADE
  end

  test "STATUSES cobre pendente, processada e erro" do
    assert_equal %w[erro pendente processada].sort, TarefaRecalculo::STATUSES.sort
  end

  # ------------------------------------------------------------- validacoes

  test "valido com tipo_entidade, referencia e status pendente" do
    tarefa = TarefaRecalculo.new(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "user-1|2026-10-13")
    assert tarefa.valid?
    assert_equal "pendente", tarefa.status
    assert_equal({}, tarefa.payload)
    assert_nil tarefa.processada_em
  end

  test "invalido sem referencia" do
    tarefa = TarefaRecalculo.new(tipo_entidade: "REGISTRO_FREQUENCIA")
    assert_not tarefa.valid?
    assert tarefa.errors.of_kind?(:referencia, :blank)
  end

  test "invalido com tipo_entidade fora de TIPOS_ENTIDADE" do
    tarefa = TarefaRecalculo.new(tipo_entidade: "INEXISTENTE", referencia: "x")
    assert_not tarefa.valid?
    assert tarefa.errors.of_kind?(:tipo_entidade, :inclusion)
  end

  test "invalido com status fora de STATUSES" do
    tarefa = TarefaRecalculo.new(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "x", status: "quebrado")
    assert_not tarefa.valid?
    assert tarefa.errors.of_kind?(:status, :inclusion)
  end

  # ------------------------------------------------------------- enfileirar!

  test "enfileirar! cria a tarefa pendente com o payload informado" do
    tarefa = TarefaRecalculo.enfileirar!(
      tipo_entidade: "REGISTRO_FREQUENCIA",
      referencia: "user-1|2026-10-13",
      payload: { "user_id" => 1, "data" => "2026-10-13" }
    )

    assert tarefa.persisted?
    assert tarefa.pendente?
    assert_equal({ "user_id" => 1, "data" => "2026-10-13" }, tarefa.payload)
    assert_equal 1, TarefaRecalculo.count
  end

  test "idempotencia: 2 enfileirar! da mesma referencia pendente = 1 linha" do
    primeira = TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "user-1|2026-10-13")
    segunda = TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "user-1|2026-10-13")

    assert_equal primeira.id, segunda.id
    assert_equal 1, TarefaRecalculo.count
  end

  test "idempotencia: nao sobrescreve o payload da tarefa pendente existente" do
    TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "r", payload: { "v" => 1 })
    TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "r", payload: { "v" => 2 })

    assert_equal 1, TarefaRecalculo.count
    assert_equal({ "v" => 1 }, TarefaRecalculo.first.payload)
  end

  test "referencias distintas criam 2 linhas" do
    TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "user-1|2026-10-13")
    TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "user-2|2026-10-13")

    assert_equal 2, TarefaRecalculo.count
  end

  test "mesma referencia com tipos distintos cria 2 linhas" do
    TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "7")
    TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_ESTACAO", referencia: "7")

    assert_equal 2, TarefaRecalculo.count
  end

  test "referencia e coagida a string (id inteiro e string casam)" do
    primeira = TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: 7)
    segunda = TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "7")

    assert_equal primeira.id, segunda.id
    assert_equal "7", primeira.referencia
    assert_equal 1, TarefaRecalculo.count
  end

  test "reenfileirar apos processada cria uma linha NOVA (a antiga nao e mais pendente)" do
    antiga = TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "r")
    antiga.update!(status: TarefaRecalculo::STATUS_PROCESSADA, processada_em: Time.current)

    nova = TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "r")

    assert_not_equal antiga.id, nova.id
    assert_equal 2, TarefaRecalculo.count
    assert_equal 1, TarefaRecalculo.pendentes.count
  end

  test "enfileirar! de tipo adiado e aceito pelo model (adiado e decisao do despacho, nao da fila)" do
    tarefa = TarefaRecalculo.enfileirar!(tipo_entidade: "FERIADO", referencia: "feriado-1")

    assert tarefa.persisted?
    assert_includes TarefaRecalculo::TIPOS_ADIADOS, tarefa.tipo_entidade
  end

  test "enfileirar! de tipo inexistente levanta erro de uso (nao e engolido pela idempotencia)" do
    assert_raises(ActiveRecord::RecordInvalid) do
      TarefaRecalculo.enfileirar!(tipo_entidade: "INEXISTENTE", referencia: "r")
    end
    assert_equal 0, TarefaRecalculo.count
  end

  # ----------------------------------------------------- corrida (banco/rescue)

  test "corrida: RecordNotUnique concorrente devolve a tarefa pendente existente" do
    # Simula a corrida: o create! insere a linha concorrente e SÓ DEPOIS falha,
    # como aconteceria se outro `enfileirar!` tivesse commitado entre o SELECT
    # inicial e o INSERT — o índice único parcial garantiu a unicidade.
    corpo = lambda do |**kwargs|
      TarefaRecalculo.new(**kwargs).save!
      raise ActiveRecord::RecordNotUnique, "corrida simulada"
    end

    resultado = nil
    com_metodo_de_classe_stubado(TarefaRecalculo, :create!, corpo) do
      resultado = TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "corrida")
    end

    assert resultado.persisted?
    assert resultado.pendente?
    assert_equal 1, TarefaRecalculo.count
  end

  test "corrida: RecordInvalid de unicidade devolve a tarefa pendente existente" do
    # Variante em que a linha concorrente já era visível à validação de
    # unicidade (o outro INSERT commitou antes dela rodar) ⇒ RecordInvalid
    # com o erro `:referencia taken` em vez de RecordNotUnique.
    corpo = lambda do |**kwargs|
      TarefaRecalculo.new(**kwargs).save!
      duplicada = TarefaRecalculo.new(**kwargs)
      duplicada.valid? # popula o erro `:referencia taken` antes de levantar
      raise ActiveRecord::RecordInvalid, duplicada
    end

    resultado = nil
    com_metodo_de_classe_stubado(TarefaRecalculo, :create!, corpo) do
      resultado = TarefaRecalculo.enfileirar!(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "corrida-2")
    end

    assert resultado.persisted?
    assert_equal 1, TarefaRecalculo.count
  end

  # --------------------------------------------------------------- meta-teste

  # Prova, por varredura do código de produção, que NENHUM arquivo sob `app/`
  # (fora do próprio model) chama `enfileirar!` com um tipo adiado. Se uma
  # task futura adicionar um produtor de `FERIADO`/`DIAEXCEPCIONAL`/`DIREITO`
  # sem cumprir o pré-requisito (o model de domínio correspondente), este
  # teste falha. O requisito é de 31.1: os tipos adiados NÃO têm produtor.
  test "nenhum codigo de producao enfileira tipo adiado" do
    model_path = Rails.root.join("app/models/tarefa_recalculo.rb").to_s
    arquivos = Dir.glob(Rails.root.join("app/**/*.rb")).map(&:to_s) - [ model_path ]

    adiados_entre_aspas = TarefaRecalculo::TIPOS_ADIADOS.flat_map do |tipo|
      [ %("#{tipo}"), %('#{tipo}') ]
    end

    achados = arquivos.flat_map do |arquivo|
      conteudo = File.read(arquivo)
      next [] unless conteudo.include?("enfileirar!")

      adiados_entre_aspas.select { |literal| conteudo.include?(literal) }.map { |literal| "#{arquivo}: #{literal}" }
    end

    assert_empty achados,
                 "Tipos adiados nao podem ter produtor nesta task, mas foram encontrados: #{achados.join(', ')}"
  end
end
