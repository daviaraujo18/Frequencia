require "test_helper"

# Task 31.5 — testes do handler de `VINCULAR_DESVINCULAR` (dias do período do
# vínculo).
#
# O motor de cálculo (`CalculoDiarioService.calcular`/`ConsolidacaoMensalService.consolidar`)
# é stubbado via `class_method_stub_helper` (capturar/restaurar o método REAL —
# NUNCA `remove_method`, lição da Sprint 29). Assim o teste prova a REGRA do
# handler (quais dias, quantas consolidações, recorte de futuro, mês
# finalizado, payload inválido, isolamento de erro) sem depender do motor — que
# tem suíte própria (sem regressão).
#
# `ConsolidacaoMensalService.finalizado?` roda REAL em quase todos os testes
# (sem `RegistroMensalFrequencia` criado ele devolve `false`), e é exercitado
# de verdade no teste de mês finalizado.
class VincularDesvincularHandlerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def tarefa_para(user_id:, inicial:, final: :ausente)
    payload = { "user_id" => user_id, "momento_inicial" => inicial }
    # `:ausente` = chave NÃO presente no payload (período aberto). Qualquer
    # outro valor (inclusive nil) é enviado como veio.
    payload["momento_final"] = (final == :ausente ? nil : final) unless final == :ausente
    TarefaRecalculo.new(
      tipo_entidade: "VINCULAR_DESVINCULAR",
      referencia: "r",
      payload: payload
    )
  end

  # Roda o handler capturando a sequência de chamadas calcular/consolidar.
  def executar(tarefa)
    chamadas = []
    calcular = ->(user, data) { chamadas << [ :calcular, user.id, data ] }
    consolidar = ->(user, ano, mes, **) { chamadas << [ :consolidar, user.id, ano, mes ] }

    com_metodos_de_classe_stubados([
      [ CalculoDiarioService, :calcular, calcular ],
      [ ConsolidacaoMensalService, :consolidar, consolidar ]
    ]) do
      VincularDesvincularHandler.call(tarefa)
    end

    chamadas
  end

  test "periodo com dias conhecidos: recalcula EXATAMENTE os dias e consolida 1x por mes distinto" do
    # 2026-09-28 .. 2026-10-02 = 3 dias de setembro (28,29,30) + 2 de outubro (1,2).
    tarefa = tarefa_para(user_id: @user.id, inicial: "2026-09-28", final: "2026-10-02")

    chamadas = executar(tarefa)

    assert_equal [
      [ :calcular, @user.id, Date.new(2026, 9, 28) ],
      [ :calcular, @user.id, Date.new(2026, 9, 29) ],
      [ :calcular, @user.id, Date.new(2026, 9, 30) ],
      [ :consolidar, @user.id, 2026, 9 ],
      [ :calcular, @user.id, Date.new(2026, 10, 1) ],
      [ :calcular, @user.id, Date.new(2026, 10, 2) ],
      [ :consolidar, @user.id, 2026, 10 ]
    ], chamadas

    # Dias fora do período NÃO são tocados.
    dias = chamadas.select { |c| c.first == :calcular }.map(&:last)
    assert_not_includes dias, Date.new(2026, 9, 27)
    assert_not_includes dias, Date.new(2026, 10, 3)
  end

  test "consolidacao roda 1x por MES distinto, nao 1x por dia" do
    # Mês ÚNICO com vários dias ⇒ UMA consolidação.
    tarefa = tarefa_para(user_id: @user.id, inicial: "2026-09-01", final: "2026-09-05")
    chamadas = executar(tarefa)

    assert_equal 1, chamadas.count { |c| c.first == :consolidar }
    assert_equal 5, chamadas.count { |c| c.first == :calcular }
    assert_equal [ [ :consolidar, @user.id, 2026, 9 ] ], chamadas.select { |c| c.first == :consolidar }
  end

  test "idempotente: rodar 2x produz a mesma sequencia" do
    tarefa = tarefa_para(user_id: @user.id, inicial: "2026-09-28", final: "2026-10-02")

    primeira = executar(tarefa)
    segunda = executar(tarefa)

    assert_equal primeira, segunda
    assert_not_empty primeira
  end

  test "periodo ABERTO (momento_final ausente): o fim e Date.current, nunca futuro" do
    inicio = Date.current - 2
    tarefa = tarefa_para(user_id: @user.id, inicial: inicio.iso8601, final: :ausente)

    chamadas = executar(tarefa)
    dias = chamadas.select { |c| c.first == :calcular }.map(&:last)

    assert_includes dias, Date.current
    assert_equal (inicio..Date.current).to_a, dias
    assert_not_includes dias, Date.current + 1
  end

  test "momento_final nil explicito: tratado como periodo aberto (fim = Date.current)" do
    inicio = Date.current - 1
    tarefa = tarefa_para(user_id: @user.id, inicial: inicio.iso8601, final: nil)

    dias = executar(tarefa).select { |c| c.first == :calcular }.map(&:last)
    assert_equal (inicio..Date.current).to_a, dias
  end

  test "dia FUTURO nao e recalculado (recorte em Date.current)" do
    inicio = Date.current - 1
    futuro = Date.current + 5
    tarefa = tarefa_para(user_id: @user.id, inicial: inicio.iso8601, final: futuro.iso8601)

    dias = executar(tarefa).select { |c| c.first == :calcular }.map(&:last)

    assert_equal (inicio..Date.current).to_a, dias
    assert dias.all? { |d| d <= Date.current }
  end

  test "periodo inteiramente futuro: skip silencioso (nada recalculado)" do
    tarefa = tarefa_para(user_id: @user.id, inicial: (Date.current + 1).iso8601, final: (Date.current + 3).iso8601)

    assert_empty executar(tarefa)
  end

  test "mes FINALIZADO nao e reescrito nem consolidado; o outro mes do periodo segue" do
    # Setembro finalizado (registro real + finalizar!); outubro livre.
    registro = RegistroMensalFrequencia.create!(
      user: @user, ano: 2026, mes: 9,
      data_inicio: Date.new(2026, 9, 1), data_fim: Date.new(2026, 9, 30)
    )
    registro.finalizar!

    tarefa = tarefa_para(user_id: @user.id, inicial: "2026-09-28", final: "2026-10-02")
    chamadas = executar(tarefa)

    # Nenhuma chamada toca setembro (nem dia, nem consolidação).
    assert chamadas.none? { |c| c.first == :calcular && c.last.month == 9 }
    assert_not_includes chamadas, [ :consolidar, @user.id, 2026, 9 ]

    # Outubro segue: dias 1 e 2 recalculados e outubro consolidado.
    assert_equal [
      [ :calcular, @user.id, Date.new(2026, 10, 1) ],
      [ :calcular, @user.id, Date.new(2026, 10, 2) ],
      [ :consolidar, @user.id, 2026, 10 ]
    ], chamadas
  end

  test "payload invalido: skip silencioso (nao recalcula nada)" do
    invalidos = [
      tarefa_para(user_id: 999_999_999, inicial: "2026-09-01", final: "2026-09-30"), # user inexistente
      tarefa_para(user_id: @user.id, inicial: nil, final: "2026-09-30"),              # início ausente
      tarefa_para(user_id: @user.id, inicial: "", final: "2026-09-30"),               # início em branco
      tarefa_para(user_id: @user.id, inicial: "data-invalida", final: "2026-09-30"),  # início não parseável
      tarefa_para(user_id: @user.id, inicial: "2026-09-30", final: "2026-09-01"),     # invertido (fim < início)
      tarefa_para(user_id: @user.id, inicial: "2026-09-01", final: "fim-invalido")    # fim presente e não parseável
    ]

    invalidos.each do |tarefa|
      assert_empty executar(tarefa)
    end
  end

  test "erro em um dia nao derruba o periodo; os demais dias e a consolidacao seguem (com log)" do
    dia_que_falha = Date.new(2026, 9, 2)
    calcular = lambda do |_user, data|
      raise "falha simulada" if data == dia_que_falha
    end
    consolidar = ->(*_a, **_k) { }

    log_io = StringIO.new
    logger_original = Rails.logger
    Rails.logger = Logger.new(log_io)
    begin
      com_metodos_de_classe_stubados([
        [ CalculoDiarioService, :calcular, calcular ],
        [ ConsolidacaoMensalService, :consolidar, consolidar ]
      ]) do
        assert_nothing_raised do
          VincularDesvincularHandler.call(
            tarefa_para(user_id: @user.id, inicial: "2026-09-01", final: "2026-09-03")
          )
        end
      end
    ensure
      Rails.logger = logger_original
    end

    assert_match(/Falha ao calcular o dia #{dia_que_falha}/, log_io.string)
  end

  test "payload vazio/nil: skip silencioso" do
    tarefa = TarefaRecalculo.new(tipo_entidade: "VINCULAR_DESVINCULAR", referencia: "r", payload: {})
    assert_nothing_raised { VincularDesvincularHandler.call(tarefa) }

    tarefa_nil = TarefaRecalculo.new(tipo_entidade: "VINCULAR_DESVINCULAR", referencia: "r")
    assert_nothing_raised { VincularDesvincularHandler.call(tarefa_nil) }
  end

  test "registry tem o handler de VINCULAR_DESVINCULAR no boot" do
    assert_equal VincularDesvincularHandler.method(:call), ExecutaTarefasJob.handlers["VINCULAR_DESVINCULAR"]
  end
end
