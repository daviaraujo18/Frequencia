require "test_helper"

# Task 31.5 — testes do PRODUTOR do evento `VINCULAR_DESVINCULAR`: o callback
# `after_commit` de `RegimeFrequentador` (create/update/destroy).
#
# Cobre: create enfileira; update que MUDA o período enfileira; update que NÃO
# muda NÃO enfileira; destroy enfileira; referência estável; dedup (2 eventos do
# mesmo período = 1 pendente); e — crítico — uma FALHA no enfileiramento NÃO
# quebra o create/update/destroy (o vínculo persiste mesmo assim).
class RegimeFrequentadorProdutorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @regime = Regime.create!(nome: "Jornada", modalidade: "HORAS")
  end

  def vincular(inicial:, final: nil)
    RegimeFrequentador.create!(
      user: @user, regime: @regime, tipo: RegimeFrequentador::OFICIAL,
      momento_inicial: inicial, momento_final: final
    )
  end

  # Pendentes de VINCULAR_DESVINCULAR (a referência é a identidade do recálculo).
  def pendentes
    TarefaRecalculo.pendentes.where(tipo_entidade: "VINCULAR_DESVINCULAR")
  end

  # --- create -------------------------------------------------------------

  test "create enfileira 1 tarefa com referencia ESTAVEL por periodo" do
    vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0), final: Time.zone.local(2026, 9, 30, 18, 0))

    assert_equal 1, pendentes.count
    tarefa = pendentes.first
    # Referência usa user_id + DATAS (não o timestamp hora/minuto).
    assert_equal "VINCULAR_DESVINCULAR:#{@user.id}:2026-09-01:2026-09-30", tarefa.referencia
    assert_equal @user.id, tarefa.payload["user_id"]
    assert_equal "2026-09-01", tarefa.payload["momento_inicial"]
    assert_equal "2026-09-30", tarefa.payload["momento_final"]
  end

  test "create com periodo ABERTO enfileira com momento_final nulo" do
    vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0))

    tarefa = pendentes.first
    assert_equal "VINCULAR_DESVINCULAR:#{@user.id}:2026-09-01:", tarefa.referencia
    assert_nil tarefa.payload["momento_final"]
  end

  test "2 eventos do MESMO periodo = 1 tarefa pendente (referencia estavel)" do
    vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0), final: Time.zone.local(2026, 9, 30, 18, 0))
    # Horários DIFERENTES no mesmo dia não mudam a identidade (o recálculo é por dia).
    vincular(inicial: Time.zone.local(2026, 9, 1, 9, 30), final: Time.zone.local(2026, 9, 30, 12, 0))

    assert_equal 2, RegimeFrequentador.where(user: @user).count
    assert_equal 1, pendentes.count
  end

  # --- update -------------------------------------------------------------

  test "update que MUDA o periodo enfileira" do
    rf = vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0), final: Time.zone.local(2026, 9, 30, 18, 0))
    # Drena a pendente do create para isolar o efeito do update.
    pendentes.each { |t| t.update!(status: TarefaRecalculo::STATUS_PROCESSADA) }

    rf.update!(momento_final: Time.zone.local(2026, 10, 15, 18, 0))

    assert_equal 1, pendentes.count
    assert_equal "VINCULAR_DESVINCULAR:#{@user.id}:2026-09-01:2026-10-15", pendentes.first.referencia
  end

  test "update que NAO muda o periodo NAO enfileira" do
    rf = vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0), final: Time.zone.local(2026, 9, 30, 18, 0))
    pendentes.each { |t| t.update!(status: TarefaRecalculo::STATUS_PROCESSADA) }

    # Muda um atributo que NÃO é o período.
    rf.update!(tipo: RegimeFrequentador::TEMPORARIO)

    assert_equal 0, pendentes.count
  end

  # --- destroy ------------------------------------------------------------

  test "destroy enfileira (desvincular)" do
    rf = vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0), final: Time.zone.local(2026, 9, 30, 18, 0))
    pendentes.each { |t| t.update!(status: TarefaRecalculo::STATUS_PROCESSADA) }

    rf.destroy!

    assert_equal 1, pendentes.count
    assert_equal "VINCULAR_DESVINCULAR:#{@user.id}:2026-09-01:2026-09-30", pendentes.first.referencia
  end

  # --- robustez: falha no enfileiramento NÃO quebra a persistência ---------

  test "falha no enfileiramento (create): o vinculo PERSISTE e nao levanta" do
    stub_que_falha = ->(**) { raise "falha simulada no enfileiramento" }

    log_io = StringIO.new
    logger_original = Rails.logger
    Rails.logger = Logger.new(log_io)
    begin
      com_metodo_de_classe_stubado(TarefaRecalculo, :enfileirar!, stub_que_falha) do
        assert_nothing_raised do
          assert_difference -> { RegimeFrequentador.where(user: @user).count }, 1 do
            vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0))
          end
        end
      end
    ensure
      Rails.logger = logger_original
    end

    assert_match(/Falha ao enfileirar recalculo/, log_io.string)
  end

  test "falha no enfileiramento (update): o vinculo PERSISTE a mudanca e nao levanta" do
    rf = vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0))
    stub_que_falha = ->(**) { raise "falha simulada no enfileiramento" }

    com_metodo_de_classe_stubado(TarefaRecalculo, :enfileirar!, stub_que_falha) do
      assert_nothing_raised { rf.update!(momento_final: Time.zone.local(2026, 10, 15, 18, 0)) }
    end

    assert_equal Time.zone.local(2026, 10, 15, 18, 0), rf.reload.momento_final
  end

  test "falha no enfileiramento (destroy): o vinculo e REMOVIDO e nao levanta" do
    rf = vincular(inicial: Time.zone.local(2026, 9, 1, 8, 0))
    stub_que_falha = ->(**) { raise "falha simulada no enfileiramento" }

    com_metodo_de_classe_stubado(TarefaRecalculo, :enfileirar!, stub_que_falha) do
      assert_nothing_raised do
        assert_difference -> { RegimeFrequentador.where(user: @user).count }, -1 do
          rf.destroy!
        end
      end
    end
  end
end
