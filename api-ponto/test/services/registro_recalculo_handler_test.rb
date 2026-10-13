require "test_helper"

# Task 31.3 — testes do handler de `REGISTRO_FREQUENCIA` / `REGISTRO_ESTACAO`.
#
# O recálculo em si (CalculoDiarioService/ConsolidacaoMensalService) é stubbado
# via `class_method_stub_helper` (capturar/restaurar o método REAL — NUNCA
# `remove_method`, lição da Sprint 29). Assim o teste prova a REGRA do handler
# (dia × mês, skip de mês finalizado, alvo ausente) sem depender do motor de
# cálculo — que tem suíte própria (sem regressão).
class RegistroRecalculoHandlerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def tarefa_para(user_id:, data:)
    TarefaRecalculo.new(
      tipo_entidade: "REGISTRO_FREQUENCIA",
      referencia: "REGISTRO_FREQUENCIA:#{user_id}:#{data}",
      payload: { "user_id" => user_id, "data" => data }
    )
  end

  test "data = hoje: recalcula o DIA e NAO consolida o mes" do
    chamadas = []
    calcular = ->(user, data) { chamadas << [ :calcular, user.id, data ] }
    consolidar = ->(user, ano, mes, **) { chamadas << [ :consolidar, user.id, ano, mes ] }

    tarefa = tarefa_para(user_id: @user.id, data: Date.current.iso8601)

    com_metodos_de_classe_stubados([
      [ CalculoDiarioService, :calcular, calcular ],
      [ ConsolidacaoMensalService, :consolidar, consolidar ]
    ]) do
      RegistroRecalculoHandler.call(tarefa)
    end

    assert_equal [ [ :calcular, @user.id, Date.current ] ], chamadas
  end

  test "data passada: recalcula o DIA afetado E consolida o MES correspondente" do
    data_passada = Date.current.prev_month
    chamadas = []
    calcular = ->(user, data) { chamadas << [ :calcular, user.id, data ] }
    consolidar = ->(user, ano, mes, **) { chamadas << [ :consolidar, user.id, ano, mes ] }

    tarefa = tarefa_para(user_id: @user.id, data: data_passada.iso8601)

    com_metodos_de_classe_stubados([
      [ CalculoDiarioService, :calcular, calcular ],
      [ ConsolidacaoMensalService, :consolidar, consolidar ]
    ]) do
      RegistroRecalculoHandler.call(tarefa)
    end

    # Ordem importa: o dia precisa ser recalculado ANTES da consolidação,
    # senão o mês reagrega um `CalculoDiario` desatualizado.
    assert_equal [
      [ :calcular, @user.id, data_passada ],
      [ :consolidar, @user.id, data_passada.year, data_passada.month ]
    ], chamadas
  end

  test "data futura: skip silencioso, nao recalcula o dia nem consolida o mes" do
    data_futura = Date.current + 1

    # Sem stub: prova que o guard de futuro barra ANTES de tocar em qualquer
    # coisa (se caísse no ramo do `else`, criaria `CalculoDiario` + `RegistroMensalFrequencia`).
    assert_no_difference -> { CalculoDiario.count } do
      assert_no_difference -> { RegistroMensalFrequencia.count } do
        assert_nothing_raised do
          RegistroRecalculoHandler.call(tarefa_para(user_id: @user.id, data: data_futura.iso8601))
        end
      end
    end
  end

  test "mes finalizado: NAO altera o CalculoDiario do dia nem o RegistroMensalFrequencia" do
    data = Date.new(2026, 9, 10)
    calculo = CalculoDiario.create!(
      user: @user, data: data, informacao: "origem", falta: false,
      meta_segundos: 111, normal_segundos: 222, excepcional_segundos: 0, total_segundos: 333
    )
    registro = RegistroMensalFrequencia.create!(
      user: @user, ano: 2026, mes: 9,
      data_inicio: Date.new(2026, 9, 1), data_fim: Date.new(2026, 9, 30),
      trabalhado: 555, meta_mensal: 777
    )
    registro.finalizar!

    # Real (sem stub): se o guard de finalização não rodasse, `calcular`
    # reescreveria o dia (sem regime vira "Nenhum regime ativo"/zeros) e
    # `consolidar` levantaria (engolido) — o dia ficaria alterado.
    assert_no_difference -> { CalculoDiario.count } do
      assert_no_difference -> { RegistroMensalFrequencia.count } do
        assert_nothing_raised do
          RegistroRecalculoHandler.call(tarefa_para(user_id: @user.id, data: data.iso8601))
        end
      end
    end

    calculo.reload
    assert_equal 111, calculo.meta_segundos
    assert_equal 222, calculo.normal_segundos
    assert_equal 333, calculo.total_segundos
    assert_equal "origem", calculo.informacao

    registro.reload
    assert_equal 555, registro.trabalhado
    assert_equal 777, registro.meta_mensal
    assert registro.finalizado?
  end

  test "mes finalizado com data de HOJE: a trava vale para o dia (nao chama calcular)" do
    hoje = Date.current
    registro = RegistroMensalFrequencia.create!(
      user: @user, ano: hoje.year, mes: hoje.month,
      data_inicio: hoje.beginning_of_month, data_fim: hoje.end_of_month
    )
    registro.finalizar!

    chamou = false
    calcular = ->(*_a) { chamou = true }
    consolidar = ->(*_a, **_k) { chamou = true }

    com_metodos_de_classe_stubados([
      [ CalculoDiarioService, :calcular, calcular ],
      [ ConsolidacaoMensalService, :consolidar, consolidar ]
    ]) do
      assert_nothing_raised do
        RegistroRecalculoHandler.call(tarefa_para(user_id: @user.id, data: hoje.iso8601))
      end
    end

    assert_not chamou
  end

  test "MesFinalizadoError na consolidacao: skip silencioso (nao propaga)" do
    data_passada = Date.current.prev_month
    consolidar = ->(*_args, **_kwargs) { raise ConsolidacaoMensalService::MesFinalizadoError, "mês fechado" }

    tarefa = tarefa_para(user_id: @user.id, data: data_passada.iso8601)

    com_metodos_de_classe_stubados([
      [ CalculoDiarioService, :calcular, ->(*_a) { } ],
      [ ConsolidacaoMensalService, :consolidar, consolidar ]
    ]) do
      assert_nothing_raised { RegistroRecalculoHandler.call(tarefa) }
    end
  end

  test "payload sem data valida: skip silencioso, nao recalcula nada" do
    chamou = false
    calcular = ->(*_a) { chamou = true }
    consolidar = ->(*_a, **_k) { chamou = true }

    [ nil, "", "data-invalida" ].each do |valor_invalido|
      payload = { "user_id" => @user.id }
      payload["data"] = valor_invalido if valor_invalido
      tarefa = TarefaRecalculo.new(tipo_entidade: "REGISTRO_FREQUENCIA", referencia: "r", payload: payload)

      com_metodos_de_classe_stubados([
        [ CalculoDiarioService, :calcular, calcular ],
        [ ConsolidacaoMensalService, :consolidar, consolidar ]
      ]) do
        assert_nothing_raised { RegistroRecalculoHandler.call(tarefa) }
      end
    end

    assert_not chamou
  end

  test "usuario inexistente: skip silencioso, nao recalcula nada" do
    chamou = false
    calcular = ->(*_a) { chamou = true }
    consolidar = ->(*_a, **_k) { chamou = true }

    tarefa = tarefa_para(user_id: 999_999_999, data: Date.current.iso8601)

    com_metodos_de_classe_stubados([
      [ CalculoDiarioService, :calcular, calcular ],
      [ ConsolidacaoMensalService, :consolidar, consolidar ]
    ]) do
      assert_nothing_raised { RegistroRecalculoHandler.call(tarefa) }
    end

    assert_not chamou
  end

  test "payload vazio/nil: skip silencioso" do
    tarefa = TarefaRecalculo.new(tipo_entidade: "REGISTRO_ESTACAO", referencia: "r", payload: {})
    assert_nothing_raised { RegistroRecalculoHandler.call(tarefa) }

    tarefa_nil = TarefaRecalculo.new(tipo_entidade: "REGISTRO_ESTACAO", referencia: "r")
    assert_nothing_raised { RegistroRecalculoHandler.call(tarefa_nil) }
  end

  test "registry tem os handlers de REGISTRO_FREQUENCIA e REGISTRO_ESTACAO no boot" do
    handler = RegistroRecalculoHandler.method(:call)

    assert_equal handler, ExecutaTarefasJob.handlers["REGISTRO_FREQUENCIA"]
    assert_equal handler, ExecutaTarefasJob.handlers["REGISTRO_ESTACAO"]
  end
end
