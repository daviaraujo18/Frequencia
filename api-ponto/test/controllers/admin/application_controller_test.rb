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
  end
end
