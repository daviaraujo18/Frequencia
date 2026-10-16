require "test_helper"

# Task 23.10 (auditoria de fechamento da Sprint 23) — Admin::UsersController
# não tinha NENHUM teste até esta task, apesar de usar
# `load_and_authorize_resource :user, only: [:edit, :update]` (task 23.7).
# Gap real: o único controller admin com `load_and_authorize_resource`
# (em vez do padrão `authorize!` explícito usado nos demais) estava sem
# cobertura de autorização e sem cobertura funcional básica.
module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @admin = User.create!(nome_completo: "Admin Teste", password: "123456", admin: true)
      post login_path, params: { username: @admin.username, password: "123456" }
    end

    # Mesmo padrão de stub de test/controllers/admin/frequentadores_controller_test.rb
    # (banco `pessoas_test` sem schema carregado — task 8.13). Usa o helper
    # capturar/restaurar: `remove_method` num método real de produção (aqui um
    # `def self.`) o apagaria para os arquivos seguintes do mesmo processo.
    #
    # Task 33.3 (Sprint 33) — o stub HONRA `incluir_cpfs` (espelha o contrato real
    # `scope.where(pessoas: { cpf: incluir_cpfs })`): sem isso, o `incluir_cpfs`
    # que a cascata injeta em `/users` seria ignorado e o teste passaria
    # independentemente do filtro (teste degenerado). `nil` = sem filtro (todos).
    def stub_vinculos(vinculos)
      corpo = lambda do |incluir_cpfs: nil, **_kwargs|
        filtrados = if incluir_cpfs.nil?
          vinculos
        else
          vinculos.select { |v| incluir_cpfs.include?(v.pessoa.cpf) }
        end
        Kaminari.paginate_array(filtrados).page(1)
      end
      com_metodo_de_classe_stubado(Pessoas::Vinculo, :frequentadores_ativos, corpo) { yield }
    end

    test "deve listar usuarios sem cpf (cadastrados manualmente)" do
      sem_cpf = User.create!(nome_completo: "Usuario Local", password: "123456")

      stub_vinculos([]) { get users_path }

      assert_response :success
      assert_select "td", text: sem_cpf.nome_completo
    end

    test "deve redirecionar para login se nao autenticado" do
      delete logout_path
      get users_path
      assert_redirected_to login_path
    end

    test "deve mostrar formulario de edicao de usuario sem cpf" do
      sem_cpf = User.create!(nome_completo: "Editavel", password: "123456")

      get edit_user_path(sem_cpf)

      assert_response :success
    end

    test "deve atualizar usuario sem cpf" do
      sem_cpf = User.create!(nome_completo: "Editavel", password: "123456")

      patch user_path(sem_cpf), params: { user: { nome_completo: "Nome Alterado" } }

      assert_redirected_to users_path
      assert_equal "Nome Alterado", sem_cpf.reload.nome_completo
    end

    test "nao deve atualizar usuario vinculado ao pessoas (com cpf)" do
      com_cpf = User.create!(nome_completo: "Vindo Do Pessoas", password: "123456", cpf: "11122233344")

      patch user_path(com_cpf), params: { user: { nome_completo: "Tentativa De Alteracao" } }

      assert_redirected_to users_path
      assert_not_equal "Tentativa De Alteracao", com_cpf.reload.nome_completo
    end

    # --- Autorização (task 23.7 / 23.10) ---
    # `load_and_authorize_resource` nega edit/update a quem não tem
    # `can :manage, User` — apenas admin (role ou coluna legada) tem essa
    # permissão; gestor/operador/autenticado-sem-role só têm `:read`.

    test "usuario nao-admin nao deve acessar formulario de edicao" do
      sem_cpf = User.create!(nome_completo: "Editavel", password: "123456")
      login_como_nao_admin

      get edit_user_path(sem_cpf)

      assert_redirected_to dashboard_path
    end

    test "usuario nao-admin nao deve atualizar usuario" do
      sem_cpf = User.create!(nome_completo: "Editavel", password: "123456")
      login_como_nao_admin

      patch user_path(sem_cpf), params: { user: { nome_completo: "Nome Alterado" } }

      assert_redirected_to dashboard_path
      assert_not_equal "Nome Alterado", sem_cpf.reload.nome_completo
    end

    test "gestor tambem nao deve editar usuario (fora do escopo de manage do gestor)" do
      sem_cpf = User.create!(nome_completo: "Editavel", password: "123456")
      delete logout_path
      gestor = User.create!(nome_completo: "Gestor Teste", password: "123456")
      gestor.add_role(:gestor)
      post login_path, params: { username: gestor.username, password: "123456" }

      get edit_user_path(sem_cpf)

      assert_redirected_to dashboard_path
    end

    # Task 33.3 (Sprint 33) — REVISÃO DO CASO QUE SANCIONAVA O 200 SEM CONTEÚDO.
    # Antes, o teste "usuario nao-admin ainda pode listar usuarios (read baseline)"
    # asseria SÓ `assert_response :success` (com um stub VAZIO `stub_vinculos([])`):
    # provava que o HTTP 200 saía, mas NADA sobre o conteúdo — foi exatamente o
    # formato que deixou passar o Bug 🔴1 (`users#index` vazava o roster de
    # frequentadores de terceiros a um autenticado comum; Bug Finder 30, achado 5).
    # Agora o caso assere o CONTEÚDO sob a cascata LIGADA (`:on`), no grão da
    # matriz da 29.8: o não-admin lista usuários (read baseline preservado), mas
    # NÃO vê o terceiro fora dos visíveis.
    test "usuario nao-admin lista usuarios mas NAO ve terceiro fora dos visiveis (conteudo sob :on)" do
      login_como_nao_admin
      vinculos = [ vinculo_double(NOME_TERCEIRO, CPF_TERCEIRO), vinculo_double(NOME_VISIVEL, CPF_VISIVEL) ]

      # CONTRASTE (:off é o comportamento de hoje): o terceiro aparece — logo a
      # ausência sob `:on` é atribuível à cascata, não ao stub.
      com_flag(nil) do
        com_visiveis([ CPF_VISIVEL ]) do
          stub_vinculos(vinculos) { get users_path }
        end
      end
      assert_response :success
      assert_select "td", text: NOME_TERCEIRO

      # SOB TESTE: 200 E sem o terceiro no corpo (o que o teste antigo não asseria).
      com_flag("on") do
        com_visiveis([ CPF_VISIVEL ]) do
          stub_vinculos(vinculos) { get users_path }
        end
      end
      assert_response :success
      assert_select "td", { text: NOME_TERCEIRO, count: 0 },
                    "sob :on o não-admin NÃO pode ver o terceiro fora dos visíveis"
      assert_select "td", text: NOME_VISIVEL
    end

    private

    PessoaDouble = Struct.new(:nome, :cpf, keyword_init: true)
    VinculoDouble = Struct.new(:id, :pessoa, keyword_init: true)

    CPF_TERCEIRO = "30030030030".freeze
    CPF_VISIVEL  = "20020020020".freeze
    NOME_TERCEIRO = "Terceiro Invisivel Users 33".freeze
    NOME_VISIVEL  = "Visivel Users 33".freeze

    def vinculo_double(nome, cpf)
      VinculoDouble.new(id: cpf.to_i, pessoa: PessoaDouble.new(nome: nome, cpf: cpf))
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

    def login_como_nao_admin
      delete logout_path
      usuario_comum = User.create!(nome_completo: "Usuario Comum", password: "123456", admin: false)
      post login_path, params: { username: usuario_comum.username, password: "123456" }
    end
  end
end
