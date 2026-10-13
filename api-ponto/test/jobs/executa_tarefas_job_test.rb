require "test_helper"

# Task 31.2 — testes do job de despacho da fila (`ExecutaTarefasJob`).
#
# O job é exercitado com handlers FAKE injetados no registry (os handlers
# reais só existem nas 31.3–31.5). O registry é estado de classe — cada teste
# guarda um SNAPSHOT do registry no `setup`, limpa SÓ para o teste rodar
# isolado, e RESTAURA o snapshot no `teardown`. É save/restore NÃO-DESTRUTIVO:
# handlers reais registrados por outros arquivos do mesmo worker sobrevivem
# (nunca os zeramos de vez, nunca `remove_method`).
class ExecutaTarefasJobTest < ActiveJob::TestCase
  def setup
    @handlers_backup = ExecutaTarefasJob.handlers.dup
    ExecutaTarefasJob.handlers.clear
  end

  def teardown
    ExecutaTarefasJob.handlers.replace(@handlers_backup)
  end

  def criar_tarefa(tipo, referencia:)
    TarefaRecalculo.create!(tipo_entidade: tipo, referencia: referencia)
  end

  test "despacha cada tarefa pendente ao handler do seu tipo (registry)" do
    chamadas = []
    ExecutaTarefasJob.registrar_handler("REGISTRO_FREQUENCIA", ->(t) { chamadas << [ t.tipo_entidade, t.referencia ] })
    ExecutaTarefasJob.registrar_handler("RECALCULAR_TODOS", ->(t) { chamadas << [ t.tipo_entidade, t.referencia ] })

    t1 = criar_tarefa("REGISTRO_FREQUENCIA", referencia: "u1:2026-10-13")
    t2 = criar_tarefa("RECALCULAR_TODOS", referencia: "global")

    ExecutaTarefasJob.perform_now

    assert_equal [ [ "REGISTRO_FREQUENCIA", "u1:2026-10-13" ], [ "RECALCULAR_TODOS", "global" ] ], chamadas
    [ t1, t2 ].each do |tarefa|
      tarefa.reload
      assert_equal TarefaRecalculo::STATUS_PROCESSADA, tarefa.status
      assert_not_nil tarefa.processada_em
    end
  end

  test "tipo adiado nao e despachado nem que haja handler registrado, e marca skip" do
    chamou = false
    # Um handler para um tipo adiado NÃO deve ser chamado — prova que o guard
    # de TIPOS_ADIADOS é anterior à consulta ao registry.
    ExecutaTarefasJob.registrar_handler("FERIADO", ->(_t) { chamou = true })

    tarefa = criar_tarefa("FERIADO", referencia: "feriado:1")

    assert_nothing_raised { ExecutaTarefasJob.perform_now }

    assert_not chamou
    tarefa.reload
    assert_equal TarefaRecalculo::STATUS_PROCESSADA, tarefa.status
    assert_not_nil tarefa.processada_em
  end

  test "tipo declarado sem handler (ainda nao implementado) e skipado sem erro" do
    tarefa = criar_tarefa("VINCULAR_DESVINCULAR", referencia: "vinculo:1")

    assert_nothing_raised { ExecutaTarefasJob.perform_now }

    tarefa.reload
    assert_equal TarefaRecalculo::STATUS_PROCESSADA, tarefa.status
  end

  test "tipo nao-adiado sem handler loga warn (handler nao registrado) e e skipado" do
    log_io = StringIO.new
    logger_original = Rails.logger
    Rails.logger = Logger.new(log_io)

    begin
      tarefa = criar_tarefa("VINCULAR_DESVINCULAR", referencia: "vinculo:1")
      assert_nothing_raised { ExecutaTarefasJob.perform_now }
    ensure
      Rails.logger = logger_original
    end

    # O warn é a única defesa contra a falha silenciosa: tipo sem handler
    # (autoload/boot) drenado sem efeito deve deixar rastro.
    assert_match(/sem handler para VINCULAR_DESVINCULAR; drenando como processada \(id=#{tarefa.id}\)/, log_io.string)
    tarefa.reload
    assert_equal TarefaRecalculo::STATUS_PROCESSADA, tarefa.status
  end

  test "tipo adiado sem handler NAO loga warn (skip esperado, nao anomalia)" do
    log_io = StringIO.new
    logger_original = Rails.logger
    Rails.logger = Logger.new(log_io)

    begin
      criar_tarefa("FERIADO", referencia: "feriado:1")
      ExecutaTarefasJob.perform_now
    ensure
      Rails.logger = logger_original
    end

    assert_no_match(/sem handler para FERIADO/, log_io.string)
  end

  test "registry e preservado (save/restore nao-destrutivo): handler de outro arquivo sobrevive" do
    # Reproduz o risco do débito D2: um handler REAL registrado por OUTRO
    # arquivo do mesmo worker ANTES deste rodar. O ciclo setup/teardown DESTE
    # arquivo não pode apagá-lo — se voltássemos a zerar o registry
    # (`@handlers = {}`), ele sumiria e os arquivos seguintes passariam
    # vacuamente (tarefa "skipada" em vez de "handled").
    outro_arquivo = ->(_t) { }
    ExecutaTarefasJob.registrar_handler("HANDLER_DE_OUTRO_ARQUIVO", outro_arquivo)

    backup_do_harness = @handlers_backup
    begin
      setup     # snapshot (contém o handler acima) + clear só para o teste
      assert_empty ExecutaTarefasJob.handlers, "o setup deve isolar o cenário limpando só para o teste"

      teardown  # RESTAURA o snapshot (não zera)
      assert_equal outro_arquivo, ExecutaTarefasJob.handlers["HANDLER_DE_OUTRO_ARQUIVO"],
                   "o teardown deve restaurar, não descartar, os handlers pre-existentes"
    ensure
      # remove o resíduo do cenário simulado e devolve o @handlers_backup do
      # harness (usado pelo teardown do Minitest ao fim do teste).
      ExecutaTarefasJob.handlers.delete("HANDLER_DE_OUTRO_ARQUIVO")
      @handlers_backup = backup_do_harness
    end
  end

  test "erro em um item nao derruba o lote: o item vira erro e os demais seguem" do
    processados = []
    ExecutaTarefasJob.registrar_handler("REGISTRO_FREQUENCIA", ->(_t) { raise "falha simulada" })
    ExecutaTarefasJob.registrar_handler("RECALCULAR_TODOS", ->(t) { processados << t.referencia })

    falha = criar_tarefa("REGISTRO_FREQUENCIA", referencia: "u1:2026-10-13")
    ok = criar_tarefa("RECALCULAR_TODOS", referencia: "global")

    assert_nothing_raised { ExecutaTarefasJob.perform_now }

    assert_equal TarefaRecalculo::STATUS_ERRO, falha.reload.status
    assert_nil falha.processada_em
    assert_equal TarefaRecalculo::STATUS_PROCESSADA, ok.reload.status
    assert_equal [ "global" ], processados
  end

  test "idempotencia: rodar 2x sobre a mesma fila = efeito unico" do
    contador = 0
    ExecutaTarefasJob.registrar_handler("REGISTRO_FREQUENCIA", ->(_t) { contador += 1 })

    criar_tarefa("REGISTRO_FREQUENCIA", referencia: "u1:2026-10-13")

    ExecutaTarefasJob.perform_now
    ExecutaTarefasJob.perform_now

    assert_equal 1, contador
    assert_equal 0, TarefaRecalculo.pendentes.count
  end

  test "nao executa quando o lock ja esta adquirido por outra execucao" do
    chamou = false
    ExecutaTarefasJob.registrar_handler("REGISTRO_FREQUENCIA", ->(_t) { chamou = true })
    criar_tarefa("REGISTRO_FREQUENCIA", referencia: "u1:2026-10-13")

    config = ActiveRecord::Base.connection_db_config.configuration_hash
    outra_conexao = PG.connect(host: config[:host], port: config[:port], dbname: config[:database], user: config[:username], password: config[:password])

    begin
      outra_conexao.exec("SELECT pg_try_advisory_lock(#{ExecutaTarefasJob::LOCK_KEY})")

      ExecutaTarefasJob.perform_now

      assert_not chamou
      assert_equal 1, TarefaRecalculo.pendentes.count
    ensure
      outra_conexao.exec("SELECT pg_advisory_unlock(#{ExecutaTarefasJob::LOCK_KEY})")
      outra_conexao.close
    end
  end

  test "LOCK_KEY e distinta das chaves dos demais jobs" do
    chaves_existentes = [
      ImportarDadosPessoaJob::LOCK_KEY,
      ImportarServidoresUnidadeJob::LOCK_KEY,
      ImportarGestoresIndividuaisJob::LOCK_KEY,
      SincronizarAfastamentosJob::LOCK_KEY,
      CalcularFrequenciaJob::LOCK_KEY
    ]

    assert_not_includes chaves_existentes, ExecutaTarefasJob::LOCK_KEY
    assert_equal chaves_existentes.uniq.size, chaves_existentes.size
  end
end
