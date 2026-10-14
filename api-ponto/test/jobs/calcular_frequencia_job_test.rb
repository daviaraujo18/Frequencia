require "test_helper"

class CalcularFrequenciaJobTest < ActiveJob::TestCase
  # `CalculoDiarioService.calcular` é um método real (`def self.calcular`),
  # então `remove_method` depois de um `define_singleton_method` o apagaria de
  # vez. Captura/restaura o UnboundMethod real (helper compartilhado) — a versão
  # anterior reinstalava um WRAPPER que chamava o original, deixando um override
  # permanente no singleton; agora o próprio método de produção volta.
  def com_calcular_stub(stub)
    com_metodo_de_classe_stubado(CalculoDiarioService, :calcular, stub) { yield }
  end
  def criar_regime(limite_credito: 10, limite_debito: 10)
    Regime.create!(
      nome: "Jornada",
      modalidade: "HORAS",
      limite_credito: limite_credito,
      limite_debito: limite_debito,
      expediente: [ { "dias" => "SEG,TER,QUA,QUI,SEX,", "inicio" => "08:00", "fim" => "12:00" } ]
    )
  end

  def vincular(user, regime, data:)
    RegimeFrequentador.create!(user: user, regime: regime, momento_inicial: data - 60, tipo: RegimeFrequentador::OFICIAL)
  end

  def bater(user, momento)
    TimeRecord.create!(user: user, punched_at: momento, raw_data: "x", authentication_mode: "manual")
  end

  test "roda sem erro para usuario sem nenhum TimeRecord" do
    user = User.create!(nome_completo: "Sem Marcacao", password: "123456", cpf: "11122233344")

    assert_nothing_raised { CalcularFrequenciaJob.perform_now(user.id) }

    assert_equal 3, CalculoDiario.where(user: user).count
  end

  test "recalcula CalculoDiario dos ultimos 3 dias e consolida o mes corrente" do
    hoje = Date.new(2026, 9, 15)
    user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")
    regime = criar_regime
    vincular(user, regime, data: hoje)

    travel_to(hoje.to_time.change(hour: 18)) do
      bater(user, hoje.to_time.change(hour: 8))
      bater(user, hoje.to_time.change(hour: 12))
      bater(user, (hoje - 1).to_time.change(hour: 8))
      bater(user, (hoje - 1).to_time.change(hour: 12))

      CalcularFrequenciaJob.perform_now(user.id)
    end

    [ hoje, hoje - 1, hoje - 2 ].each do |data|
      assert CalculoDiario.exists?(user: user, data: data), "esperava CalculoDiario para #{data}"
    end

    calculo_hoje = CalculoDiario.find_by(user: user, data: hoje)
    assert_equal 4 * 3600, calculo_hoje.total_segundos

    registro = RegistroMensalFrequencia.find_by(user: user, ano: hoje.year, mes: hoje.month)
    assert registro.present?
    assert_equal 8 * 3600, registro.trabalhado
  end

  test "pula silenciosamente usuario com mes ja finalizado, sem interromper os demais" do
    hoje = Date.new(2026, 9, 15)
    user_finalizado = User.create!(nome_completo: "Mes Fechado", password: "123456", cpf: "11122233344")
    user_normal = User.create!(nome_completo: "Mes Aberto", password: "123456", cpf: "55566677788")

    regime = criar_regime
    vincular(user_finalizado, regime, data: hoje)
    vincular(user_normal, regime, data: hoje)

    travel_to(hoje.to_time.change(hour: 18)) do
      ConsolidacaoMensalService.consolidar(user_finalizado, hoje.year, hoje.month)
      ConsolidacaoMensalService.finalizar(user_finalizado, hoje.year, hoje.month)

      bater(user_normal, hoje.to_time.change(hour: 8))
      bater(user_normal, hoje.to_time.change(hour: 12))

      assert_nothing_raised { CalcularFrequenciaJob.perform_now }
    end

    registro_normal = RegistroMensalFrequencia.find_by(user: user_normal, ano: hoje.year, mes: hoje.month)
    assert registro_normal.present?
    assert_equal 4 * 3600, registro_normal.trabalhado
  end

  test "erro generico em um usuario nao impede o processamento dos demais" do
    user1 = User.create!(nome_completo: "Vai Falhar", password: "123456", cpf: "11122233344")
    user2 = User.create!(nome_completo: "Vai Funcionar", password: "123456", cpf: "55566677788")

    original_calcular = CalculoDiarioService.method(:calcular)
    stub_calcular = lambda do |user, data|
      raise "falha simulada" if user.cpf == "11122233344"

      original_calcular.call(user, data)
    end

    com_calcular_stub(stub_calcular) do
      assert_nothing_raised { CalcularFrequenciaJob.perform_now }
    end

    assert_equal 0, CalculoDiario.where(user: user1).count
    assert_equal 3, CalculoDiario.where(user: user2).count
  end

  # Tarefa 32.1 (débito D2/17.5) — guarda de mês finalizado POR DIA. Sem a
  # guarda, `calcular` (save! sem trava) reescreveria o `CalculoDiario` de um
  # mês fechado antes de o `consolidar` levantar `MesFinalizadoError` (que o
  # job engole). Snapshot dos campos prova que o registro fica intocado.
  test "mes finalizado: os ultimos 3 dias NAO sao reescritos e a consolidacao nao altera o registro" do
    hoje = Date.new(2026, 9, 15)
    user = User.create!(nome_completo: "Mes Fechado", password: "123456", cpf: "11122233344")
    regime = criar_regime
    vincular(user, regime, data: hoje)

    travel_to(hoje.to_time.change(hour: 18)) do
      # Valores propositalmente "errados" (distintos do recálculo real do
      # regime HORAS 08-12 ⇒ meta 14400s / total 0): se a guarda falhar, o
      # `calcular` do dia sobrescreve e o snapshot muda.
      calculo = CalculoDiario.create!(
        user: user, data: hoje,
        meta_segundos: 999, normal_segundos: 111, total_segundos: 111, falta: true, informacao: "snapshot"
      )
      ConsolidacaoMensalService.consolidar(user, hoje.year, hoje.month)
      ConsolidacaoMensalService.finalizar(user, hoje.year, hoje.month)

      registro = RegistroMensalFrequencia.find_by(user: user, ano: hoje.year, mes: hoje.month)
      snapshot_calculo = calculo.reload.attributes
      snapshot_registro = registro.attributes

      CalcularFrequenciaJob.perform_now(user.id)

      assert_equal snapshot_calculo, calculo.reload.attributes,
                   "CalculoDiario de mes finalizado nao pode ser reescrito"
      assert_equal snapshot_registro, registro.reload.attributes,
                   "RegistroMensalFrequencia de mes finalizado nao pode mudar"
    end
  end

  # A guarda é POR DIA (não só mês corrente): os 3 últimos dias podem cruzar a
  # virada de mês. Aqui `hoje` é 11/01 → recálculo cobre 11/01, 10/31, 10/30;
  # outubro está finalizado (10/31 e 10/30 são pulados) e novembro está aberto.
  test "virada de mes: dias do mes anterior finalizado NAO sao tocados; mes corrente segue normal" do
    hoje = Date.new(2026, 11, 1)
    user = User.create!(nome_completo: "Virada", password: "123456", cpf: "11122233344")
    regime = criar_regime
    vincular(user, regime, data: hoje - 2.months)

    travel_to(hoje.to_time.change(hour: 18)) do
      calculo_out = CalculoDiario.create!(
        user: user, data: Date.new(2026, 10, 31),
        meta_segundos: 999, total_segundos: 111, falta: true, informacao: "snapshot"
      )
      ConsolidacaoMensalService.consolidar(user, 2026, 10)
      ConsolidacaoMensalService.finalizar(user, 2026, 10)

      snapshot_out = calculo_out.reload.attributes

      CalcularFrequenciaJob.perform_now(user.id)

      assert_equal snapshot_out, calculo_out.reload.attributes,
                   "10/31 pertence a mes finalizado e nao pode ser reescrito"
      assert_not CalculoDiario.exists?(user: user, data: Date.new(2026, 10, 30)),
                 "10/30 pertence a mes finalizado e nao pode ser calculado"
      assert CalculoDiario.exists?(user: user, data: hoje),
             "11/01 pertence ao mes corrente (aberto) e deve ser calculado"
      assert RegistroMensalFrequencia.find_by(user: user, ano: 2026, mes: 11).present?,
             "mes corrente (aberto) deve ser consolidado"
    end
  end

  # Mutation target da guarda PRÉ-consolidação: mês corrente finalizado ⇒
  # `consolidar` não pode nem ser chamado (a guarda prévia evita depender do
  # `MesFinalizadoError` engolido).
  test "mes corrente finalizado: consolidar NAO e chamado" do
    hoje = Date.new(2026, 9, 15)
    user = User.create!(nome_completo: "Corrente Fechado", password: "123456", cpf: "11122233344")
    regime = criar_regime
    vincular(user, regime, data: hoje)

    travel_to(hoje.to_time.change(hour: 18)) do
      ConsolidacaoMensalService.consolidar(user, hoje.year, hoje.month)
      ConsolidacaoMensalService.finalizar(user, hoje.year, hoje.month)

      chamou = false
      stub = lambda do |*_args|
        chamou = true
        raise "consolidar nao deveria ser chamado para mes finalizado"
      end

      com_metodo_de_classe_stubado(ConsolidacaoMensalService, :consolidar, stub) do
        assert_nothing_raised { CalcularFrequenciaJob.perform_now(user.id) }
      end

      assert_not chamou, "consolidar foi chamado apesar do mes corrente estar finalizado"
    end
  end

  # Prova a MEMOIZAÇÃO de `finalizado?` por [ano, mes] (S1/32.1). Fora da virada
  # de mês, os 3 dias recalculados e a consolidação prévia caem no MESMO mês ⇒ o
  # predicado deve ser consultado UMA única vez por usuário (contra 4× sem memo:
  # 3 do laço + 1 pré-consolidação). O mês está ABERTO, então o valor memoizado é
  # `false` — isso prova que o memo distingue "não cacheado" de "cacheado como
  # false": com `||=` simples o `false` reconsultaria e contaria 4×.
  test "finalizado? e consultado uma vez para o mesmo mes (memoizacao por ano/mes)" do
    hoje = Date.new(2026, 9, 15)
    user = User.create!(nome_completo: "Memo", password: "123456", cpf: "11122233344")
    regime = criar_regime
    vincular(user, regime, data: hoje)

    chamadas = 0
    original = ConsolidacaoMensalService.method(:finalizado?)
    contando = lambda do |*args|
      chamadas += 1
      original.call(*args)
    end

    travel_to(hoje.to_time.change(hour: 18)) do
      com_metodo_de_classe_stubado(ConsolidacaoMensalService, :finalizado?, contando) do
        CalcularFrequenciaJob.perform_now(user.id)
      end
    end

    assert_equal 1, chamadas,
                 "9/2026 deveria ser consultado 1x (memoizado), nao 4x"
  end

  test "nao executa quando o lock ja esta adquirido por outra execucao" do
    user = User.create!(nome_completo: "Fulano", password: "123456", cpf: "11122233344")
    chamou = false
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    outra_conexao = PG.connect(host: config[:host], port: config[:port], dbname: config[:database], user: config[:username], password: config[:password])

    begin
      outra_conexao.exec("SELECT pg_try_advisory_lock(#{CalcularFrequenciaJob::LOCK_KEY})")

      com_calcular_stub(->(*_args) { chamou = true }) do
        CalcularFrequenciaJob.perform_now(user.id)
      end

      assert_not chamou
    ensure
      outra_conexao.exec("SELECT pg_advisory_unlock(#{CalcularFrequenciaJob::LOCK_KEY})")
      outra_conexao.close
    end
  end
end
