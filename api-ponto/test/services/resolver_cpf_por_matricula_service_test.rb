require "test_helper"

class ResolverCpfPorMatriculaServiceTest < ActiveSupport::TestCase
  def stub_competencia(resposta)
    SticapiClient::Gestorh.define_singleton_method(:competencia) { |*_args| resposta }
    yield
  ensure
    SticapiClient::Gestorh.singleton_class.remove_method(:competencia)
  end

  test "resolve as matriculas encontradas na competencia" do
    folha = [
      { "matricula" => "1001", "nome" => "Fulano", "cpf" => "11122233344", "nascimento" => "1990-01-01", "tipo_vinculo" => "Efetivo", "folha" => "X" },
      { "matricula" => "1002", "nome" => "Ciclano", "cpf" => "55566677788", "nascimento" => "1985-05-05", "tipo_vinculo" => "Comissionado", "folha" => "X" }
    ]

    resultado = nil
    stub_competencia(folha) do
      resultado = ResolverCpfPorMatriculaService.call(%w[1001 1002], mes: 7, ano: 2026)
    end

    assert_equal({ "1001" => "11122233344", "1002" => "55566677788" }, resultado)
  end

  test "matricula nao encontrada na competencia nao aparece no resultado" do
    folha = [ { "matricula" => "1001", "cpf" => "11122233344" } ]

    resultado = nil
    stub_competencia(folha) do
      resultado = ResolverCpfPorMatriculaService.call(%w[1001 9999], mes: 7, ano: 2026)
    end

    assert_equal({ "1001" => "11122233344" }, resultado)
    assert_not resultado.key?("9999")
  end

  test "retorna hash vazio quando a competencia esta vazia" do
    resultado = nil
    stub_competencia([]) do
      resultado = ResolverCpfPorMatriculaService.call(%w[1001], mes: 7, ano: 2026)
    end

    assert_equal({}, resultado)
  end

  test "normaliza matriculas para string na busca (integer vs string)" do
    folha = [ { "matricula" => "1001", "cpf" => "11122233344" } ]

    resultado = nil
    stub_competencia(folha) do
      resultado = ResolverCpfPorMatriculaService.call([ 1001 ], mes: 7, ano: 2026)
    end

    assert_equal({ "1001" => "11122233344" }, resultado)
  end

  test "ignora registros da competencia sem matricula ou cpf" do
    folha = [
      { "matricula" => "1001", "cpf" => "11122233344" },
      { "matricula" => nil, "cpf" => "99988877766" },
      { "matricula" => "1002", "cpf" => nil }
    ]

    resultado = nil
    stub_competencia(folha) do
      resultado = ResolverCpfPorMatriculaService.call(%w[1001 1002], mes: 7, ano: 2026)
    end

    assert_equal({ "1001" => "11122233344" }, resultado)
  end

  test "chama SticapiClient::Gestorh.competencia apenas uma vez por instancia mesmo com multiplas chamadas" do
    chamadas = 0
    folha = [ { "matricula" => "1001", "cpf" => "11122233344" } ]

    SticapiClient::Gestorh.define_singleton_method(:competencia) do |*_args|
      chamadas += 1
      folha
    end

    begin
      service = ResolverCpfPorMatriculaService.new(mes: 7, ano: 2026)
      service.call(%w[1001])
      service.call(%w[1001])
    ensure
      SticapiClient::Gestorh.singleton_class.remove_method(:competencia)
    end

    assert_equal 1, chamadas
  end

  # --- mais_recente (10B.3) ---

  test "mais_recente prioriza o mes atual quando a matricula aparece nos dois" do
    travel_to Time.zone.local(2026, 7, 15) do
      SticapiClient::Gestorh.define_singleton_method(:competencia) do |mes:, ano:|
        if mes == 7 && ano == 2026
          [ { "matricula" => "1001", "cpf" => "AAA_MES_ATUAL" } ]
        elsif mes == 6 && ano == 2026
          [ { "matricula" => "1001", "cpf" => "BBB_MES_ANTERIOR" } ]
        else
          []
        end
      end

      begin
        resultado = ResolverCpfPorMatriculaService.mais_recente(%w[1001])
        assert_equal({ "1001" => "AAA_MES_ATUAL" }, resultado)
      ensure
        SticapiClient::Gestorh.singleton_class.remove_method(:competencia)
      end
    end
  end

  test "mais_recente usa o mes anterior quando a matricula so aparece nele" do
    travel_to Time.zone.local(2026, 7, 15) do
      SticapiClient::Gestorh.define_singleton_method(:competencia) do |mes:, ano:|
        if mes == 6 && ano == 2026
          [ { "matricula" => "2002", "cpf" => "SO_MES_ANTERIOR" } ]
        else
          []
        end
      end

      begin
        resultado = ResolverCpfPorMatriculaService.mais_recente(%w[2002])
        assert_equal({ "2002" => "SO_MES_ANTERIOR" }, resultado)
      ensure
        SticapiClient::Gestorh.singleton_class.remove_method(:competencia)
      end
    end
  end

  test "mais_recente atravessa a virada de ano corretamente (janeiro cai para dezembro do ano anterior)" do
    travel_to Time.zone.local(2026, 1, 10) do
      chamadas_mes_ano = []

      SticapiClient::Gestorh.define_singleton_method(:competencia) do |mes:, ano:|
        chamadas_mes_ano << [ mes, ano ]
        []
      end

      begin
        ResolverCpfPorMatriculaService.mais_recente(%w[1001])
        assert_includes chamadas_mes_ano, [ 12, 2025 ]
        assert_includes chamadas_mes_ano, [ 1, 2026 ]
      ensure
        SticapiClient::Gestorh.singleton_class.remove_method(:competencia)
      end
    end
  end
end
