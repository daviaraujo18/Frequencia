require "test_helper"

class AtualizarFrequentadorCacheServiceTest < ActiveSupport::TestCase
  test "extrai orgao e vinculo quando vinculos_ativos vem como Array (varios vinculos)" do
    dados = {
      "id" => 42,
      "nome" => "Fulano de Tal",
      "lotacao_principal" => { "unidade" => { "descricao" => "Vara Cível" } },
      "vinculos_ativos" => [
        { "tipo_vinculo" => { "nome" => "Efetivo" } },
        { "tipo_vinculo" => { "nome" => "Comissionado" } }
      ]
    }

    cache = AtualizarFrequentadorCacheService.call(cpf: "11122233344", dados: dados)

    assert_equal "Vara Cível", cache.orgao
    assert_equal "Efetivo", cache.vinculo
  end

  test "extrai vinculo quando vinculos_ativos vem como Hash unico (achado real da Sprint 10B: pessoa com 1 so vinculo)" do
    dados = {
      "id" => 42,
      "nome" => "Fulano de Tal",
      "lotacao_principal" => { "unidade" => { "descricao" => "Vara Cível" } },
      "vinculos_ativos" => { "tipo_vinculo" => { "nome" => "Efetivo" }, "matricula" => "1001" }
    }

    cache = AtualizarFrequentadorCacheService.call(cpf: "11122233344", dados: dados)

    assert_equal "Efetivo", cache.vinculo
  end

  test "vinculo fica nil quando vinculos_ativos esta ausente" do
    dados = { "id" => 42, "nome" => "Fulano de Tal" }

    cache = AtualizarFrequentadorCacheService.call(cpf: "11122233344", dados: dados)

    assert_nil cache.vinculo
    assert_nil cache.orgao
  end

  test "faz upsert (nao duplica) para o mesmo cpf" do
    dados = { "id" => 1, "nome" => "Primeiro" }
    AtualizarFrequentadorCacheService.call(cpf: "11122233344", dados: dados)

    dados_atualizados = { "id" => 1, "nome" => "Segundo" }
    AtualizarFrequentadorCacheService.call(cpf: "11122233344", dados: dados_atualizados)

    assert_equal 1, FrequentadorCache.where(cpf: "11122233344").count
    assert_equal "Segundo", FrequentadorCache.find_by(cpf: "11122233344").nome
  end
end
