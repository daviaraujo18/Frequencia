require "test_helper"

# Task 31 (fix de cobertura da cascata) — prova que `admin/users#index` deixou
# de vazar o roster de frequentadores a um autenticado comum.
#
# Antes da correção, `users#index` lia `Pessoas::Vinculo.frequentadores_ativos`
# SEM aplicar a cascata (achado 🔴 do
# `docs/quality/bug_report_30_cobertura_cascata_bug-finder.md`), enquanto a
# MESMA fonte era restringida em `/frequentadores`. Aqui exercitamos o mesmo
# contrato da 29.7:
#   - não-admin (sem role) só vê o visível com a flag LIGADA;
#   - com a flag DESLIGADA nada muda (paridade com `/frequentadores`);
#   - ADMIN (passo 2 — visão global) continua vendo tudo (controle positivo).
# A visibilidade é injetada pelo MESMO ponto de entrada de produção
# (`Pessoas::Vinculo.cpfs_frequentadores_visiveis`), stubado com
# `com_metodo_de_classe_stubado` (nunca `remove_method`).
module Admin
  class UsersCascataControllerTest < ActionDispatch::IntegrationTest
    PessoaDouble = Struct.new(:nome, :cpf, keyword_init: true)
    VinculoDouble = Struct.new(:id, :pessoa, keyword_init: true)

    CPF_TERCEIRO = "30030030030".freeze
    CPF_VISIVEL = "20020020020".freeze

    setup do
      @vinculo_terceiro = VinculoDouble.new(
        id: 1, pessoa: PessoaDouble.new(nome: "Pessoa de Terceiro BF", cpf: CPF_TERCEIRO)
      )
      @vinculo_visivel = VinculoDouble.new(
        id: 2, pessoa: PessoaDouble.new(nome: "Pessoa Visivel BF", cpf: CPF_VISIVEL)
      )
    end

    # ------------------------------------------------------------------
    # (a) não-admin NÃO acessa dados de terceiros nas telas corrigidas
    # ------------------------------------------------------------------

    test "nao-admin NAO ve o terceiro quando a flag esta ligada e ele esta fora dos visiveis" do
      login_como_nao_admin

      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) do
          stub_vinculos([ @vinculo_terceiro, @vinculo_visivel ]) { get users_path }
        end
      end

      assert_response :success
      assert_select "td", { text: "Pessoa de Terceiro BF", count: 0 },
                    "sob a flag :on o nao-admin NAO pode ver o frequentador de terceiro"
      assert_select "td", text: "Pessoa Visivel BF"
    end

    test "nao-admin NAO ve NENHUM terceiro quando nenhum cpf e visivel (fail-closed)" do
      login_como_nao_admin

      com_flag("on") do
        com_visiveis([]) do
          stub_vinculos([ @vinculo_terceiro, @vinculo_visivel ]) { get users_path }
        end
      end

      assert_response :success
      assert_select "td", { text: "Pessoa de Terceiro BF", count: 0 }
      assert_select "td", { text: "Pessoa Visivel BF", count: 0 }
    end

    test "nao-admin ve o terceiro com a flag DESLIGADA (paridade com /frequentadores)" do
      login_como_nao_admin

      com_flag(nil) do
        com_visiveis([ CPF_VISIVEL ]) do
          stub_vinculos([ @vinculo_terceiro, @vinculo_visivel ]) { get users_path }
        end
      end

      assert_response :success
      assert_select "td", text: "Pessoa de Terceiro BF"
    end

    # ------------------------------------------------------------------
    # (b) controle positivo: admin (visão global / passo 2) continua vendo tudo
    # ------------------------------------------------------------------

    test "admin ve o terceiro mesmo sob a flag ligada (passo 2 — visao global)" do
      login_como_admin

      com_flag("on") do
        com_visiveis([]) do
          stub_vinculos([ @vinculo_terceiro, @vinculo_visivel ]) { get users_path }
        end
      end

      assert_response :success
      assert_select "td", text: "Pessoa de Terceiro BF"
      assert_select "td", text: "Pessoa Visivel BF"
    end

    # ------------------------------------------------------------------
    # Contas locais sem CPF (inclui admins) — gate admin-only
    # ------------------------------------------------------------------

    test "nao-admin NAO ve contas locais sem cpf (nao enumera contas privilegiadas)" do
      User.create!(nome_completo: "Conta Local Sem Cpf", password: "123456")
      login_como_nao_admin

      stub_vinculos([]) { get users_path }

      assert_response :success
      assert_select "td", text: "Conta Local Sem Cpf", count: 0
    end

    test "admin ve contas locais sem cpf (controle positivo)" do
      User.create!(nome_completo: "Conta Local Sem Cpf", password: "123456")
      login_como_admin

      stub_vinculos([]) { get users_path }

      assert_response :success
      assert_select "td", text: "Conta Local Sem Cpf"
    end

    private

    def login_como_admin
      delete logout_path
      admin = User.create!(nome_completo: "Admin Cascata Users", password: "123456", admin: true)
      post login_path, params: { username: admin.username, password: "123456" }
    end

    def login_como_nao_admin
      delete logout_path
      comum = User.create!(nome_completo: "Usuario Comum Cascata", password: "123456", admin: false)
      post login_path, params: { username: comum.username, password: "123456" }
    end

    # Stub de `frequentadores_ativos` que HONRA `incluir_cpfs` — espelha o
    # contrato real (`scope.where(pessoas: { cpf: incluir_cpfs })`):
    #   nil        → sem filtro (todos);
    #   lista vazia→ nenhum (fail-closed);
    #   lista      → só os cpfs da lista.
    def stub_vinculos(vinculos, &bloco)
      corpo = lambda do |incluir_cpfs: nil, **_kwargs|
        filtrados = if incluir_cpfs.nil?
          vinculos
        else
          vinculos.select { |v| incluir_cpfs.include?(v.pessoa.cpf) }
        end
        Kaminari.paginate_array(filtrados).page(1)
      end

      com_metodo_de_classe_stubado(Pessoas::Vinculo, :frequentadores_ativos, corpo) { bloco.call }
    end

    def com_visiveis(cpfs, &bloco)
      com_metodo_de_classe_stubado(
        Pessoas::Vinculo, :cpfs_frequentadores_visiveis, ->(_usuario) { cpfs }
      ) { bloco.call }
    end

    def com_flag(valor)
      anterior = ENV[FrequenciaAutorizacaoCascata::VARIAVEL]
      if valor.nil?
        ENV.delete(FrequenciaAutorizacaoCascata::VARIAVEL)
      else
        ENV[FrequenciaAutorizacaoCascata::VARIAVEL] = valor
      end
      yield
    ensure
      if anterior.nil?
        ENV.delete(FrequenciaAutorizacaoCascata::VARIAVEL)
      else
        ENV[FrequenciaAutorizacaoCascata::VARIAVEL] = anterior
      end
    end
  end
end
