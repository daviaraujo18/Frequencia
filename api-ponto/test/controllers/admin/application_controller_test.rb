require "test_helper"

# Task 24.3 (Sprint 24) — contrato do Admin::ApplicationController.
#
# A Sprint 24 adota o pagy (RF03) no stack admin. Esta suíte valida o aceite
# da 24.3 SEM depender de views de listagem (que só chegam na Sprint 25):
#
#   1. `include Pagy::Backend` presente de fato na classe base admin
#      (o método `pagy` é privado no Pagy 9, então `private_method_defined?`).
#   2. `pagy(...)` CALLABLE dentro do contexto de um controller admin real
#      (esteira router → before_action → CanCan → action — mesmo padrão do
#      authorization_matrix_test da Sprint 23) e devolvendo `[Pagy, records]`.
#   3. Constructos da 23.7 intactos: `CanCan::ControllerAdditions` no ancestry,
#      after_action do `check_authorization` registrado (bloco proveniente do
#      cancancan) e `rescue_from CanCan::AccessDenied` com handler.
#   4. Auth inalterado (RN06): guest redirecionado ao login e `current_user`
#      derivado da sessão continua funcionando.
#
# Padrões copiados dos testes admin existentes: usuários criados inline
# (username via callback do User), login via `/login` (sessão legada).
module Admin
  class ApplicationControllerTest < ActionDispatch::IntegrationTest
    # ----------------------------------------------------------------------
    # Helpers (mesmo padrão dos demais arquivos de teste admin)
    # ----------------------------------------------------------------------

    def criar_usuario(nome_completo: "Usuario Contrato Teste")
      User.create!(nome_completo: nome_completo, password: "123456")
    end

    def login_como(user)
      post login_path, params: { username: user.username, password: "123456" }
      assert_response :redirect
      follow_redirect!
    end

    # ----------------------------------------------------------------------
    # Pagy::Backend (RF03)
    # ----------------------------------------------------------------------

    test "Admin::ApplicationController inclui Pagy::Backend e expoe o metodo pagy" do
      assert_includes Admin::ApplicationController.ancestors, Pagy::Backend,
                      "Pagy::Backend deve estar no ancestry do controller base admin"
      # Pagy 9 define `pagy` como private no módulo Backend (chamado pelas
      # actions) — o assert de "callable" real está no teste abaixo.
      assert Admin::ApplicationController.private_method_defined?(:pagy),
             "o método privado pagy (Pagy 9) deve estar disponível na classe"
    end

    test "pagy fica callable em controller admin e devolve [Pagy, records]" do
      usuario = criar_usuario
      login_como(usuario)

      get dashboard_path
      assert_response :success

      pagy, records = @controller.send(:pagy, User.all)
      assert_instance_of Pagy, pagy
      assert_equal User.count, pagy.count, "pagy.count deve refletir o total da collection"
      assert_equal [ User.count, pagy.limit ].min, records.size,
                   "página 1 deve trazer no máximo `limit` registros"
      # Pagy não aplica ORDER BY — a collection é devolvida como fornecida;
      # comparação por conjunto de ids (todos os usuários cabem na página 1).
      assert_equal User.ids.sort, records.map(&:id).sort,
                   "os registros da página devem ser a collection paginada"
    end

    # ----------------------------------------------------------------------
    # Constructos da 23.7 preservados (RN06)
    # ----------------------------------------------------------------------

    test "23.7 intacto: CanCan incluido, check_authorization registrado e rescue_from presente" do
      assert_includes Admin::ApplicationController.ancestors, CanCan::ControllerAdditions,
                      "CanCan::ControllerAdditions (23.7) deve continuar no ancestry"

      # `check_authorization` (23.7) registra um after_action com bloco — a
      # única after_action com Proc da classe base admin. A origem do bloco é
      # o próprio cancancan (não um callback do projeto).
      after_procs = Admin::ApplicationController._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :after && callback.filter.is_a?(Proc)
      end
      assert after_procs.any?, "check_authorization (23.7) deve registrar after_action"

      arquivo, = after_procs.first.source_location
      assert_match %r{cancancan.*/controller_additions\.rb}, arquivo,
                   "o after_action deve ser o bloco do check_authorization (cancancan)"

      # Comportamento do check_authorization: action que não autoriza → exceção.
      controller_sem_autorizacao = Admin::ApplicationController.new
      assert_raises(CanCan::AuthorizationNotPerformed) do
        after_procs.first.call(controller_sem_autorizacao)
      end

      # `rescue_from CanCan::AccessDenied` (23.7) registrado com handler Proc
      # e com resolutibilidade para a exceção que o CanCan lança.
      handlers = Admin::ApplicationController.rescue_handlers.select do |chave, _|
        chave == "CanCan::AccessDenied"
      end
      assert handlers.any?, "rescue_from CanCan::AccessDenied (23.7) deve estar registrado"
      assert_instance_of Proc, handlers.first[1]
      assert_kind_of Proc, Admin::ApplicationController.handler_for_rescue(CanCan::AccessDenied.new),
                     "deve existir handler invocável para CanCan::AccessDenied"
    end

    # ----------------------------------------------------------------------
    # Auth inalterado (RN06)
    # ----------------------------------------------------------------------

    test "auth inalterado: guest redirecionado ao login e current_user preservado" do
      get dashboard_path
      assert_redirected_to login_path
      assert_nil @controller.send(:current_user), "guest não tem current_user (sessão vazia)"

      usuario = criar_usuario
      login_como(usuario)

      get dashboard_path
      assert_response :success
      assert_equal usuario.id, @controller.send(:current_user).id,
                   "current_user deve continuar derivando do usuário autenticado na sessão"
    end

    # ----------------------------------------------------------------------
    # set_configurations (task 26.1 — contexto do layout)
    # ----------------------------------------------------------------------

    test "set_configurations expoe o contexto do layout apos acao admin real" do
      usuario = criar_usuario
      login_como(usuario)

      get dashboard_path
      assert_response :success

      assert_equal "API Ponto TJPI", @controller.instance_variable_get(:@app_name),
                   "@app_name deve preservar a identidade atual do app"
      assert_equal "Sistema de registro e controle de frequência do TJPI",
                   @controller.instance_variable_get(:@app_description),
                   "@app_description deve contextualizar o sistema"
      assert_equal ApplicationRecord.icon, @controller.instance_variable_get(:@app_icon),
                   "@app_icon deve vir do fallback ApplicationRecord.icon"
      assert_equal [], @controller.instance_variable_get(:@menu),
                   "@menu deve começar vazio (padrão basic8)"

      static_menu = @controller.instance_variable_get(:@static_menu)
      assert static_menu.any?, "@static_menu deve conter os itens de navegação admin"
    end

    test "set_configurations monta @static_menu sem rotas mortas (url '#' so em itens com children)" do
      usuario = criar_usuario
      login_como(usuario)

      get dashboard_path
      assert_response :success

      static_menu = @controller.instance_variable_get(:@static_menu)
      folhas_com_rota_morta = []

      visitar = lambda do |itens|
        itens.each do |item|
          if item[:children].present?
            visitar.call(item[:children])
          elsif item[:url].to_s == "#"
            folhas_com_rota_morta << item[:name]
          end
        end
      end
      visitar.call(static_menu)

      assert_empty folhas_com_rota_morta,
                   "nenhum item folha pode ter url '#' (rota morta como o 'Inicializar Estação' do layout inline)"
    end

    test "set_configurations inclui a navegacao real do layout admin no padrao basic8" do
      usuario = criar_usuario
      login_como(usuario)

      get dashboard_path
      assert_response :success

      static_menu = @controller.instance_variable_get(:@static_menu)
      urls = []

      coletar = lambda do |itens|
        itens.each do |item|
          urls << item[:url].to_s if item[:url].present?
          coletar.call(item[:children]) if item[:children].present?
        end
      end
      coletar.call(static_menu)

      assert_includes urls, dashboard_path
      assert_includes urls, time_records_path
      assert_includes urls, users_path
      assert_includes urls, frequentadores_path
      assert_includes urls, estacoes_path
      assert_includes urls, versoes_path
      assert_includes urls, relatorio_terceirizados_path
      assert_includes urls, frequencia_por_orgao_path
      assert_includes urls, parcial_path
      assert_includes urls, frequencia_path
      assert_includes urls, regimes_path
      assert_includes urls, direitos_deveres_path
      assert_includes urls, gestores_individuais_path

      # Cada item-folha do padrão basic8 carrega permission/permission_check/
      # active_test (a sidebar da 26.2 filtra e destaca por eles).
      presenca = static_menu.find { |item| item[:name] == "Presença" }
      assert presenca, "grupo Presença deve existir no menu"
      assert presenca[:children].any?, "grupo Presença deve ter children (sub-navegação)"

      folhas = []
      coletar_folhas = lambda do |itens|
        itens.each do |item|
          if item[:children].present?
            coletar_folhas.call(item[:children])
          else
            folhas << item
          end
        end
      end
      coletar_folhas.call(static_menu)
      assert folhas.none? { |item| item[:permission].nil? || item[:permission_check].nil? },
             "todo item-folha deve ter :permission e :permission_check para o filtro CanCanCan"
    end
  end
end
