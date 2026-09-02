require "test_helper"

class RegimeTest < ActiveSupport::TestCase
  test "valid with nome" do
    regime = Regime.new(nome: "Jornada Padrão", modalidade: "HORAS", resumo: "8h/dia", meta_semanal: "40h")
    assert regime.valid?
  end

  test "resumo_exibicao usa o campo resumo quando presente" do
    regime = Regime.new(resumo: "8h/dia", expediente: [ { "dias" => "SEG,TER", "inicio" => "08:00", "fim" => "16:00" } ])
    assert_equal [ "8h/dia" ], regime.resumo_exibicao
  end

  test "resumo_exibicao computa dias/horas do expediente quando resumo esta em branco" do
    regime = Regime.new(expediente: [
      { "dias" => "SEG,TER,QUA,QUI,SEX,", "inicio" => "07:00", "fim" => "13:00" }
    ])
    assert_equal [ "SEG,TER,QUA,QUI,SEX, de 07:00 às 13:00" ], regime.resumo_exibicao
  end

  test "resumo_exibicao lista um item por periodo do expediente" do
    regime = Regime.new(expediente: [
      { "dias" => "SEG,TER,QUA,QUI,SEX,", "inicio" => "08:00", "fim" => "12:00" },
      { "dias" => "SEG,TER,QUA,QUI,SEX,", "inicio" => "14:00", "fim" => "18:00" }
    ])
    assert_equal [
      "SEG,TER,QUA,QUI,SEX, de 08:00 às 12:00",
      "SEG,TER,QUA,QUI,SEX, de 14:00 às 18:00"
    ], regime.resumo_exibicao
  end

  test "resumo_exibicao retorna vazio quando nao ha resumo nem expediente" do
    regime = Regime.new
    assert_equal [], regime.resumo_exibicao
  end

  test "invalid without nome" do
    regime = Regime.new
    assert_not regime.valid?
    assert_includes regime.errors[:nome], "não pode ficar em branco"
  end

  test "invalid with modalidade fora das disponiveis" do
    regime = Regime.new(nome: "Jornada Padrão", modalidade: "Presencial")
    assert_not regime.valid?
    assert_includes regime.errors[:modalidade], "não está incluído na lista"
  end

  test "valid sem modalidade (allow_nil)" do
    regime = Regime.new(nome: "Jornada Padrão", modalidade: nil)
    assert regime.valid?
  end

  test "Regime::MODALIDADES_LABELS cobre todos os valores de MODALIDADES_DISPONIVEIS" do
    assert_equal Regime::MODALIDADES_DISPONIVEIS.sort, Regime::MODALIDADES_LABELS.keys.sort
  end

  test "Regime::MODALIDADES_LABELS tem os textos exatos pedidos" do
    assert_equal "Horas", Regime::MODALIDADES_LABELS["HORAS"]
    assert_equal "Horas com intervalo", Regime::MODALIDADES_LABELS["HORAS_COM_INTERVALO"]
    assert_equal "Ocorrências", Regime::MODALIDADES_LABELS["OCORRENCIAS"]
  end

  test "has many regime_frequentadores e users through" do
    regime = Regime.create!(nome: "Jornada Padrão")
    user = User.create!(nome_completo: "Fulano", password: "123456")
    RegimeFrequentador.create!(user: user, regime: regime, momento_inicial: Time.current)

    assert_includes regime.users, user
  end

  test "restrict_with_exception impede excluir regime com regime_frequentadores vinculados" do
    regime = Regime.create!(nome: "Jornada Padrão")
    user = User.create!(nome_completo: "Fulano", password: "123456")
    RegimeFrequentador.create!(user: user, regime: regime, momento_inicial: Time.current)

    assert_raises(ActiveRecord::DeleteRestrictionError) { regime.destroy }
  end

  test "categorias= cria regime_categorias associadas" do
    regime = Regime.create!(nome: "Jornada Padrão", categorias: [ "SERVIDOR_CARREIRA", "AUXILIAR_DA_JUSTICA" ])

    assert_equal [ "SERVIDOR_CARREIRA", "AUXILIAR_DA_JUSTICA" ], regime.reload.categorias
  end

  test "categorias= substitui as categorias existentes (nao acumula)" do
    regime = Regime.create!(nome: "Jornada Padrão", categorias: [ "SERVIDOR_CARREIRA" ])
    regime.update!(categorias: [ "ESTAGIARIO" ])

    assert_equal [ "ESTAGIARIO" ], regime.reload.categorias
  end

  test "categorias= ignora valores em branco" do
    regime = Regime.create!(nome: "Jornada Padrão", categorias: [ "SERVIDOR_CARREIRA", "", nil ])

    assert_equal [ "SERVIDOR_CARREIRA" ], regime.reload.categorias
  end

  test "categorias vazio por padrao" do
    regime = Regime.create!(nome: "Jornada Padrão")
    assert_equal [], regime.categorias
  end

  test "belongs_to anterior e padrao (auto-referencia opcional)" do
    regime_base = Regime.create!(nome: "Jornada Base")
    regime_novo = Regime.create!(nome: "Jornada Nova", anterior: regime_base, padrao: regime_base)

    assert_equal regime_base, regime_novo.anterior
    assert_equal regime_base, regime_novo.padrao
  end

  test "expediente aceita array de horarios em jsonb" do
    horario = { "inicio" => "08:00", "fim" => "12:00", "dias" => "SEG,TER,QUA,QUI,SEX" }
    regime = Regime.create!(nome: "Jornada Padrão", expediente: [ horario ])

    assert_equal [ horario ], regime.reload.expediente
  end
end
