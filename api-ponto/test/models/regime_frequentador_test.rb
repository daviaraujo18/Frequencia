require "test_helper"

class RegimeFrequentadorTest < ActiveSupport::TestCase
  test "valid with user, regime e momento_inicial" do
    regime = Regime.create!(nome: "Jornada Padrão")
    user = User.create!(nome_completo: "Fulano", password: "123456")

    rf = RegimeFrequentador.new(user: user, regime: regime, momento_inicial: Time.current, tipo: "principal")
    assert rf.valid?
  end

  test "invalid without momento_inicial" do
    regime = Regime.create!(nome: "Jornada Padrão")
    user = User.create!(nome_completo: "Fulano", password: "123456")

    rf = RegimeFrequentador.new(user: user, regime: regime)
    assert_not rf.valid?
    assert_includes rf.errors[:momento_inicial], "não pode ficar em branco"
  end

  test "invalid sem user" do
    regime = Regime.create!(nome: "Jornada Padrão")
    rf = RegimeFrequentador.new(regime: regime, momento_inicial: Time.current)
    assert_not rf.valid?
  end

  test "invalid sem regime" do
    user = User.create!(nome_completo: "Fulano", password: "123456")
    rf = RegimeFrequentador.new(user: user, momento_inicial: Time.current)
    assert_not rf.valid?
  end
end
