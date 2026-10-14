require "test_helper"

# Task 31.4 — testes do handler de `RECALCALAR_TODOS` (todos com vínculo ativo).
#
# O eixo "vínculo ativo" (`Pessoas::Vinculo.ativos`) e o motor de recálculo
# (`CalculoDiarioService`/`ConsolidacaoMensalService`) são stubados via
# `class_method_stub_helper` (capturar/restaurar o método REAL — NUNCA
# `remove_method`, lição da Sprint 29). Assim o teste prova a REGRA do handler
# (quem é alvo, isolamento de erro, skip de mês finalizado) sem tocar o banco
# `pessoas` (readonly, outro Postgres — task 8.13) nem o motor de cálculo (que
# tem suíte própria, sem regressão).
class RecalcularTodosHandlerTest < ActiveSupport::TestCase
  def setup
    @user_a = User.create!(nome_completo: "Frequentador A", password: "123456", cpf: "11111111111")
    @user_b = User.create!(nome_completo: "Frequentador B", password: "123456", cpf: "22222222222")
    # Tem `User` local, mas NÃO tem vínculo ativo (CPF fora da lista resolvida
    # no Pessoas) — não pode ser tocado.
    @user_sem_vinculo = User.create!(nome_completo: "Sem Vinculo", password: "123456", cpf: "33333333333")
  end

  # Double chainable MÍNIMO de `Pessoas::Vinculo.ativos` para o encadeamento
  # usado pelo handler (`joins(:pessoa).distinct.pluck("pessoas.cpf")`). Devolve
  # os CPFs injetados em memória — não consulta o banco `pessoas`.
  def relacao_ativos(cpfs)
    fake = Object.new
    fake.define_singleton_method(:joins) { |*_args| fake }
    fake.define_singleton_method(:distinct) { fake }
    fake.define_singleton_method(:pluck) { |*_cols| cpfs }
    fake
  end

  # Triple no formato do helper: [owner, metodo, corpo]. O double é capturado
  # num LOCAL (o corpo roda com `self` = Pessoas::Vinculo, então não enxerga
  # métodos da instância de teste).
  def stub_ativos(cpfs)
    fake = relacao_ativos(cpfs)
    [ Pessoas::Vinculo, :ativos, -> { fake } ]
  end

  def tarefa
    # `RECALCULAR_TODOS` é um gatilho global: sem alvo no payload.
    TarefaRecalculo.new(tipo_entidade: "RECALCULAR_TODOS", referencia: "global")
  end

  test "recalcula SOMENTE os usuarios com vinculo ativo" do
    chamadas = []
    calcular = ->(user, data) { chamadas << [ user.id, data ] }
    consolidar = ->(*_a, **_k) { }

    com_metodos_de_classe_stubados([
      stub_ativos([ @user_a.cpf, @user_b.cpf ]),
      [ CalculoDiarioService, :calcular, calcular ],
      [ ConsolidacaoMensalService, :consolidar, consolidar ]
    ]) do
      RecalcularTodosHandler.call(tarefa)
    end

    tocados = chamadas.map(&:first).uniq
    assert_equal [ @user_a.id, @user_b.id ].sort, tocados.sort
    assert_not_includes tocados, @user_sem_vinculo.id

    # 3 dias por usuário (mirror do CalcularFrequenciaJob: últimos 3 dias).
    assert_equal 3 * 2, chamadas.size
  end

  test "idempotente: rodar 2x produz a mesma saida" do
    runs = []
    2.times do
      saidas = []
      calcular = ->(user, data) { saidas << [ :calcular, user.cpf, data ] }
      consolidar = ->(user, ano, mes, **) { saidas << [ :consolidar, user.cpf, ano, mes ] }

      com_metodos_de_classe_stubados([
        stub_ativos([ @user_a.cpf, @user_b.cpf ]),
        [ CalculoDiarioService, :calcular, calcular ],
        [ ConsolidacaoMensalService, :consolidar, consolidar ]
      ]) do
        RecalcularTodosHandler.call(tarefa)
      end

      runs << saidas
    end

    assert_equal runs.first, runs.last
    assert_not_empty runs.first
  end

  test "erro em um usuario nao derruba o lote (os demais seguem) e loga por CPF" do
    processados = []
    # Capturado em LOCAL: o corpo instalado por `define_singleton_method` roda
    # com `self` = a classe, então um ivar de teste (`@user_a`) NÃO resolve ali.
    cpf_que_falha = @user_a.cpf
    calcular = lambda do |user, _data|
      raise "falha simulada" if user.cpf == cpf_que_falha

      processados << user.cpf
    end

    log_io = StringIO.new
    logger_original = Rails.logger
    Rails.logger = Logger.new(log_io)
    begin
      com_metodos_de_classe_stubados([
        stub_ativos([ @user_a.cpf, @user_b.cpf ]),
        [ CalculoDiarioService, :calcular, calcular ],
        [ ConsolidacaoMensalService, :consolidar, ->(*_a, **_k) { } ]
      ]) do
        assert_nothing_raised { RecalcularTodosHandler.call(tarefa) }
      end
    ensure
      Rails.logger = logger_original
    end

    # O usuário que falhou não é processado; o outro SEGUE (lote isolado) —
    # 3 vezes (os 3 dias do pipeline), todos do CPF de B.
    assert_equal [ @user_b.cpf ], processados.uniq
    assert_not_includes processados, @user_a.cpf
    assert_match(/Falha ao processar CPF #{@user_a.cpf}/, log_io.string)
  end

  test "MesFinalizadoError na consolidacao: skip silencioso (nao propaga, nao loga falha)" do
    consolidar = ->(*_a, **_k) { raise ConsolidacaoMensalService::MesFinalizadoError, "mes fechado" }

    log_io = StringIO.new
    logger_original = Rails.logger
    Rails.logger = Logger.new(log_io)
    begin
      com_metodos_de_classe_stubados([
        stub_ativos([ @user_a.cpf ]),
        [ CalculoDiarioService, :calcular, ->(*_a) { } ],
        [ ConsolidacaoMensalService, :consolidar, consolidar ]
      ]) do
        assert_nothing_raised { RecalcularTodosHandler.call(tarefa) }
      end
    ensure
      Rails.logger = logger_original
    end

    assert_no_match(/Falha ao processar CPF/, log_io.string)
  end

  # --- Task 32.2 (débito D2 da 31.4) — guarda de mês finalizado no handler ---
  # Espelha os testes da 32.1 (`CalcularFrequenciaJob`). Aqui o alvo (user) vem
  # de `stub_ativos`; o motor de cálculo roda REAL nos testes de snapshot/virada
  # (prova que nada é reescrito), e é stubado nos testes de decisão (prova que
  # uma etapa NÃO é chamada).

  # Guarda POR DIA. Sem ela, `calcular` (save! sem trava) reescreveria o
  # `CalculoDiario` de um mês fechado antes de o `consolidar` levantar
  # `MesFinalizadoError` (que o handler engole). Snapshot dos campos prova que
  # o registro fica intocado — motor REAL, sem stub de calcular/consolidar.
  test "mes finalizado: os ultimos 3 dias NAO sao reescritos e a consolidacao nao altera o registro" do
    hoje = Date.new(2026, 9, 15)

    travel_to(hoje.to_time.change(hour: 18)) do
      # Valores propositalmente "errados" (distintos do recálculo real): se a
      # guarda falhar, o `calcular` do dia sobrescreve e o snapshot muda.
      calculo = CalculoDiario.create!(
        user: @user_a, data: hoje,
        meta_segundos: 999, normal_segundos: 111, total_segundos: 111, falta: true, informacao: "snapshot"
      )
      ConsolidacaoMensalService.consolidar(@user_a, hoje.year, hoje.month)
      ConsolidacaoMensalService.finalizar(@user_a, hoje.year, hoje.month)

      registro = RegistroMensalFrequencia.find_by(user: @user_a, ano: hoje.year, mes: hoje.month)
      snapshot_calculo = calculo.reload.attributes
      snapshot_registro = registro.attributes

      com_metodos_de_classe_stubados([ stub_ativos([ @user_a.cpf ]) ]) do
        RecalcularTodosHandler.call(tarefa)
      end

      assert_equal snapshot_calculo, calculo.reload.attributes,
                   "CalculoDiario de mes finalizado nao pode ser reescrito"
      assert_equal snapshot_registro, registro.reload.attributes,
                   "RegistroMensalFrequencia de mes finalizado nao pode mudar"
    end
  end

  # A guarda é POR DIA (não só mês corrente): os 3 últimos dias podem cruzar a
  # virada de mês. `hoje` = 11/01 → recálculo cobre 11/01, 10/31, 10/30; outubro
  # está finalizado (10/31 e 10/30 são pulados) e novembro está aberto.
  test "virada de mes: dias do mes anterior finalizado NAO sao tocados; mes corrente segue normal" do
    hoje = Date.new(2026, 11, 1)

    travel_to(hoje.to_time.change(hour: 18)) do
      calculo_out = CalculoDiario.create!(
        user: @user_a, data: Date.new(2026, 10, 31),
        meta_segundos: 999, total_segundos: 111, falta: true, informacao: "snapshot"
      )
      ConsolidacaoMensalService.consolidar(@user_a, 2026, 10)
      ConsolidacaoMensalService.finalizar(@user_a, 2026, 10)

      snapshot_out = calculo_out.reload.attributes

      com_metodos_de_classe_stubados([ stub_ativos([ @user_a.cpf ]) ]) do
        RecalcularTodosHandler.call(tarefa)
      end

      assert_equal snapshot_out, calculo_out.reload.attributes,
                   "10/31 pertence a mes finalizado e nao pode ser reescrito"
      assert_not CalculoDiario.exists?(user: @user_a, data: Date.new(2026, 10, 30)),
                 "10/30 pertence a mes finalizado e nao pode ser calculado"
      assert CalculoDiario.exists?(user: @user_a, data: hoje),
             "11/01 pertence ao mes corrente (aberto) e deve ser calculado"
      assert RegistroMensalFrequencia.find_by(user: @user_a, ano: 2026, mes: 11).present?,
             "mes corrente (aberto) deve ser consolidado"
    end
  end

  # Mutation target da guarda PRÉ-consolidação: mês corrente finalizado ⇒
  # `consolidar` não pode nem ser chamado (a guarda prévia evita depender do
  # `MesFinalizadoError` engolido).
  test "mes corrente finalizado: consolidar NAO e chamado" do
    hoje = Date.new(2026, 9, 15)

    travel_to(hoje.to_time.change(hour: 18)) do
      ConsolidacaoMensalService.consolidar(@user_a, hoje.year, hoje.month)
      ConsolidacaoMensalService.finalizar(@user_a, hoje.year, hoje.month)

      chamou = false
      stub = lambda do |*_args|
        chamou = true
        raise "consolidar nao deveria ser chamado para mes finalizado"
      end

      com_metodos_de_classe_stubados([
        stub_ativos([ @user_a.cpf ]),
        [ ConsolidacaoMensalService, :consolidar, stub ]
      ]) do
        assert_nothing_raised { RecalcularTodosHandler.call(tarefa) }
      end

      assert_not chamou, "consolidar foi chamado apesar do mes corrente estar finalizado"
    end
  end

  # Prova a MEMOIZAÇÃO de `finalizado?` por [ano, mes]. Fora da virada de mês, os
  # 3 dias recalculados e a consolidação prévia caem no MESMO mês ⇒ o predicado
  # deve ser consultado UMA única vez por usuário (contra 4× sem memo: 3 do laço
  # + 1 pré-consolidação). O mês está ABERTO, logo o valor memoizado é `false` —
  # isso prova que o memo distingue "não cacheado" de "cacheado como false": com
  # `||=` simples o `false` reconsultaria e contaria 4×.
  test "finalizado? e consultado uma vez para o mesmo mes (memoizacao por ano/mes)" do
    hoje = Date.new(2026, 9, 15)

    chamadas = 0
    original = ConsolidacaoMensalService.method(:finalizado?)
    contando = lambda do |*args|
      chamadas += 1
      original.call(*args)
    end

    travel_to(hoje.to_time.change(hour: 18)) do
      com_metodos_de_classe_stubados([
        stub_ativos([ @user_a.cpf ]),
        [ CalculoDiarioService, :calcular, ->(*_a) { } ],
        [ ConsolidacaoMensalService, :consolidar, ->(*_a, **_k) { } ],
        [ ConsolidacaoMensalService, :finalizado?, contando ]
      ]) do
        RecalcularTodosHandler.call(tarefa)
      end
    end

    assert_equal 1, chamadas,
                 "9/2026 deveria ser consultado 1x (memoizado), nao 4x"
  end

  test "CPF de vinculo ativo sem User correspondente: ignorado sem erro" do
    processados = []
    calcular = ->(user, _data) { processados << user.cpf }

    com_metodos_de_classe_stubados([
      stub_ativos([ @user_a.cpf, "99999999999" ]),
      [ CalculoDiarioService, :calcular, calcular ],
      [ ConsolidacaoMensalService, :consolidar, ->(*_a, **_k) { } ]
    ]) do
      assert_nothing_raised { RecalcularTodosHandler.call(tarefa) }
    end

    assert_equal [ @user_a.cpf ], processados.uniq
  end

  test "lista de vinculos ativos vazia: nada e recalculado (nao varre a base)" do
    chamou = false
    calcular = ->(*_a) { chamou = true }
    consolidar = ->(*_a, **_k) { chamou = true }

    com_metodos_de_classe_stubados([
      stub_ativos([]),
      [ CalculoDiarioService, :calcular, calcular ],
      [ ConsolidacaoMensalService, :consolidar, consolidar ]
    ]) do
      assert_nothing_raised { RecalcularTodosHandler.call(tarefa) }
    end

    assert_not chamou
  end

  test "registry tem o handler de RECALCULAR_TODOS no boot" do
    assert_equal RecalcularTodosHandler.method(:call), ExecutaTarefasJob.handlers["RECALCULAR_TODOS"]
  end
end
