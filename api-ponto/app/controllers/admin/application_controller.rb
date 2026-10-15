module Admin
  # Controller base do contexto administrativo (ADR-001, Seção 4).
  # Concentra autenticação de sessão e autorização (CanCanCan, task 23.7).
  # Todas as rotas administrativas exigem login, exceto as explicitamente
  # liberadas (ex: Admin::SessionsController#new/#create, tela de login).
  class ApplicationController < ::ApplicationController
    include CanCan::ControllerAdditions

    # Task 26.1 (Sprint 26) — identidade do app (padrão basic8). O nome
    # público atual "API Ponto TJPI" é preservado (título/header/footer do
    # layout admin); a descrição contextualiza o sistema para o partial
    # `shared/_header` (marca central) e meta tags.
    APP_NAME = "API Ponto TJPI".freeze
    APP_DESCRIPTION = "Sistema de registro e controle de frequência do TJPI".freeze

    # Tarefa 33.1 (Sprint 33) — Camada 1: contrato de declaração de postura
    # perante a cascata de autorização de frequência. Todo controller `Admin::*`
    # declara EXATAMENTE uma postura:
    #   - `:coberto`    → inclui `FrequenciaAuthorization` (hook `included`);
    #   - `:dispensado` → chama `.fora_da_cascata_justificativa("motivo")`.
    # `nil` (default) = NÃO declarado → o guard `verificar_postura_cascata`
    # barra em runtime (fail-closed sob `FREQUENCIA_CASCATA_ENFORCEMENT=raise`).
    # A postura é HERDADA (class_attribute) e NÃO é declarada na base de
    # propósito: assim cada controller concreto precisa declarar a sua. A base
    # `Presenca::*` não herda `Admin::ApplicationController` e, por isso, não é
    # alcançada pelo guard (contexto pré-sessão — ADR-0003; Bug 🟠2 = risco aceito).
    class_attribute :cascata_postura, default: nil

    # Tarefa 33.1 (Sprint 33) — motivo da dispensa, PERSISTIDO para leitura em
    # runtime (não só no texto-fonte). A macro abaixo grava aqui; o meta-teste
    # de drift (33.2) asserta `cascata_justificativa.present?` de forma fiável,
    # sem heurística de grep sobre o código. `nil` quando a postura não é
    # `:dispensado`.
    class_attribute :cascata_justificativa, default: nil

    # Tarefa 33.1 (Sprint 33) — postura é decisão POR CLASSE, nunca HERDADA.
    # `class_attribute` propaga o valor para subclasses; sem este reset, um
    # controller novo criado por `class X < Admin::AlgumConcreto` (em vez de
    # herdar a base) passaria no guard sem declarar nada, herdando a postura —
    # e, no eixo `:dispensado`, até a justificativa alheia (falso-verde). O hook
    # ZERA a postura em toda subclasse; quem quiser postura declara a sua (via
    # `include FrequenciaAuthorization` ou `fora_da_cascata_justificativa`).
    def self.inherited(subclasse)
      super
      subclasse.cascata_postura = nil
      subclasse.cascata_justificativa = nil
    end

    # Macro de dispensa explícita. A justificativa é OBRIGATÓRIA no código
    # (motivo em branco → `ArgumentError`): dispensar um controller da cascata é
    # uma decisão consciente e auditável, não um esquecimento silencioso. O
    # meta-teste de drift (33.2) exige justificativa NÃO vazia para aceitar um
    # `:dispensado` — lida via `cascata_justificativa` (runtime), não por grep.
    def self.fora_da_cascata_justificativa(motivo)
      raise ArgumentError, "justificativa obrigatória para dispensar a cascata" if motivo.blank?

      self.cascata_justificativa = motivo
      self.cascata_postura = :dispensado
    end

    # Task 24.3 (Sprint 24) — Pagy (RF03): expõe o backend de paginação para
    # todos os controllers admin via `@pagy, @collection = pagy(...)`. O módulo
    # é privado no Pagy 9 (chamado pelas actions), e sua inclusão NÃO altera a
    # autenticação (require_login/current_user) nem a autorização CanCanCan
    # da task 23.7 (RN06 — zero regressão em auth/ability).
    include Pagy::Backend

    layout "admin"

    # Task 26.6 (Sprint 26) — trilho de navegação do admin (RNF05), porta do
    # padrão basic8 (`add_breadcrumb "Início", :root_path` no ApplicationController
    # do fonte). Aqui entra no contexto ADMIN e não na base: a base do Frequencia
    # é `ActionController::API` e é compartilhada com `Presenca::*` (RNF01/RNF06 —
    # contexto API/presença intocado; ADR-001 Seção 4). O `admin` renderiza o
    # partial `shared/_title` (26.4) que consome `breadcrumbs`; o contexto
    # presença não renderiza breadcrumbs em nenhuma view.
    add_breadcrumb "Início", :root_path

    before_action :require_login
    # Task 26.1 (Sprint 26) — contexto do layout admin (porta do
    # `set_configurations` do basic8): define @app_name/@app_description/
    # @app_icon/@menu/@static_menu consumidos pelos partials `shared/*`
    # (tasks 26.2–26.5) e pelos scaffolds da Sprint 25. Sem tocar no
    # contexto API/presença — `ApplicationController` base (ActionController::API)
    # e `Presenca::*` continuam sem sessão/menu (RNF01/RNF06).
    before_action :set_configurations
    # Tarefa 33.1 (Sprint 33) — Camada 1: guard fail-closed que exige DECLARAÇÃO
    # de postura (não restringe leitura de conteúdo). Roda em TODA action admin
    # e é INDEPENDENTE de `FREQUENCIA_AUTORIZACAO_CASCATA`. No-op para quem
    # declarou (`:coberto`/`:dispensado`).
    before_action :verificar_postura_cascata
    check_authorization

    # Task 23.7 — CanCanCan: redireciona para dashboard quando o usuário
    # não tem permissão. Mantém o mesmo padrão de alert do require_admin
    # legado ( mensagem em pt-BR ).
    rescue_from CanCan::AccessDenied do |exception|
      redirect_to dashboard_path, alert: exception.message
    end

    helper_method :current_user, :logged_in?

    private

    # Tarefa 33.1 (Sprint 33) — Camada 1 (runtime): guard que exige DECLARAÇÃO
    # de postura por controller (não restringe leitura de conteúdo). Se a classe
    # NÃO declarou postura: `Rails.logger.warn` no modo `log` (fail-open) ou
    # `CascataNaoDeclaradaError` no modo `raise` (fail-closed). Independente de
    # `FREQUENCIA_AUTORIZACAO_CASCATA` (`:off`/`:shadow`/`:on`) — o furo da
    # omissão existe em qualquer estado da cascata (D2).
    #
    # Com TODOS os controllers `Admin::*` declarados, é NO-OP em produção, em
    # qualquer estado da flag de cascata (D2/R3).
    def verificar_postura_cascata
      return if self.class.cascata_postura.present?

      msg = "#{self.class.name}: controller admin sem postura de cascata declarada " \
            "(include FrequenciaAuthorization ou fora_da_cascata_justificativa)"
      return Rails.logger.warn(msg) if FrequenciaCascataEnforcement.log?

      raise CascataNaoDeclaradaError, msg
    end

    # Resolve o usuário do contexto admin. Duas fontes de sessão coexistem
    # (ver bug_report_23_cs): `session[:user_id]` (contrato legado — fonte
    # de verdade deste contexto) e a sessão Warden/Devise. Correções:
    #
    # - B3: revalida `status` a cada request — conta desativada (status != 1)
    #   tem a sessão revogada imediatamente (nunca fica "válida" até o
    #   browser fechar; sem alterar `active_for_authentication?`/Ability).
    # - B4: quando a sessão vem do cookie `remember_user_token` (Warden
    #   autentica via rememberable após o browser ser reaberto, mas
    #   `session[:user_id]` está vazio), sincroniza o id para o contexto
    #   admin reconhecer o usuário — o remember_me passa a entregar acesso.
    def current_user
      return @current_user if defined?(@current_user)

      @current_user =
        if session[:user_id]
          user_from_session
        else
          user_from_warden
        end
    end

    def user_from_session
      user = User.find_by(id: session[:user_id])
      return user if user&.status == 1

      revoke_admin_session!
      nil
    end

    # Warden autentica via `authenticate(scope: :user)` — fast path pela
    # sessão Warden ou strategy rememberable quando há cookie de remember.
    def user_from_warden
      warden_user = request.env["warden"]&.authenticate(scope: :user)
      return nil unless warden_user

      if warden_user.status == 1
        session[:user_id] = warden_user.id
        warden_user
      else
        revoke_admin_session!
        nil
      end
    end

    def revoke_admin_session!
      session[:user_id] = nil
      request.env["warden"]&.logout(:user)
    end

    def logged_in?
      current_user.present?
    end

    def require_login
      unless logged_in?
        redirect_to login_path
      end
    end

    # Task 23.7 — Mantido como fallback legado. Controllers que usavam
    # require_admin agora usam load_and_authorize_resource ou authorize!
    # do CanCanCan. O método permanece disponível para chamada manual
    # se necessário durante a transição.
    def require_admin(fallback_path = dashboard_path)
      return if current_user&.admin?

      redirect_to fallback_path, alert: "Acesso restrito a administradores"
    end

    # Task 26.1 (Sprint 26) — contexto do layout admin (porta fiel do
    # `set_configurations` do basic8; fonte: basic8/app/controllers/
    # application_controller.rb). Definido como before_action para que
    # TODAS as actions admin exponham @app_name/@app_description/@app_icon/
    # @menu/@static_menu às views.
    #
    # O `@static_menu` reflete a navegação atual do layout `admin.html.erb`
    # (sidebar inline) convertida para o formato data-driven do basic8:
    # itens com :permission/:permission_check (filtro CanCanCan que a
    # sidebar da task 26.2 aplica em todos os níveis), :active_test
    # (avaliado por `menu_activated?` na zutils) e :children (grupos).
    #
    # SEM rotas mortas: o item "Inicializar Estação" do layout inline
    # apontava para `href="#"` sem rota real — ficou de fora. Os grupos
    # (Presença/Estação de Ponto/Relatório Mensal) mantêm `url: "#"` por
    # serem headers de seção do AdminLTE treeview (não são rotas).
    #
    # Nomes/ícones em pt-BR/FA espelham o layout atual (as views já
    # migraram `bi-*` → `fa-*`); o padrão do basic8 de usar `Model.icon`/
    # `Model.model_name.human` entra quando a Sprint 25 adicionar os
    # `self.icon` customizados e as entries I18n dos models.
    def set_configurations
      @app_name = APP_NAME
      @app_description = APP_DESCRIPTION
      @app_icon = ApplicationRecord.icon
      @menu = []
      @static_menu = [
        {
          url: dashboard_path,
          active_test: "controller_name == 'dashboard'",
          icon: "fas fa-gauge",
          name: "Dashboard",
          permission: :read,
          permission_check: :all
        },
        {
          url: time_records_path,
          active_test: "controller_name == 'time_records'",
          icon: "fas fa-clock-rotate-left",
          name: "Registros de Ponto",
          permission: :read,
          permission_check: TimeRecord
        },
        {
          url: users_path,
          active_test: "controller_name == 'users'",
          icon: "fas fa-users",
          name: "Usuários",
          # Reflete o guard do layout inline (`current_user&.admin?`): só
          # admin tem :manage em User (ability 23.5 — inclui role :admin).
          permission: :manage,
          permission_check: User
        },
        {
          url: "#",
          active_test: "",
          icon: "fas fa-user-check",
          name: "Presença",
          permission: :read,
          permission_check: :all,
          children: [
            {
              url: frequentadores_path,
              active_test: "controller_name == 'frequentadores'",
              icon: "fas fa-circle",
              name: "Frequentadores",
              permission: :read,
              permission_check: :all
            },
            {
              url: "#",
              active_test: "",
              icon: "fas fa-circle",
              name: "Estação de Ponto",
              permission: :read,
              permission_check: :all,
              children: [
                {
                  url: estacoes_path,
                  active_test: "controller_name == 'estacoes'",
                  icon: "fas fa-circle",
                  name: "Explorar Estações",
                  permission: :read,
                  permission_check: EstacaoPonto
                },
                {
                  url: versoes_path,
                  active_test: "controller_name == 'versoes'",
                  icon: "fas fa-circle",
                  name: "Explorar Versões",
                  permission: :read,
                  permission_check: Versao
                }
              ]
            },
            {
              url: "#",
              active_test: "",
              icon: "fas fa-circle",
              name: "Relatório Mensal",
              permission: :read,
              permission_check: :all,
              children: [
                {
                  url: relatorio_terceirizados_path,
                  active_test: "controller_name == 'relatorio_terceirizados'",
                  icon: "fas fa-circle",
                  name: "Relatório Terceirizados",
                  permission: :read,
                  permission_check: :all
                },
                {
                  url: frequencia_por_orgao_path,
                  active_test: "controller_name == 'frequencia_por_orgao'",
                  icon: "fas fa-circle",
                  name: "Frequência por Órgão",
                  permission: :read,
                  permission_check: :all
                },
                {
                  url: parcial_path,
                  active_test: "controller_name == 'parcial'",
                  icon: "fas fa-circle",
                  name: "Parcial",
                  permission: :read,
                  permission_check: :all
                }
              ]
            },
            {
              url: frequencia_path,
              active_test: "controller_name == 'frequencia'",
              icon: "fas fa-circle",
              name: "Frequência",
              permission: :read,
              permission_check: :all
            },
            {
              url: regimes_path,
              active_test: "controller_name == 'regimes'",
              icon: "fas fa-circle",
              name: "Regimes",
              permission: :read,
              permission_check: Regime
            },
            {
              url: direitos_deveres_path,
              active_test: "controller_name == 'direitos_deveres'",
              icon: "fas fa-circle",
              name: "Direitos & Deveres",
              permission: :read,
              permission_check: :all
            },
            {
              url: gestores_individuais_path,
              active_test: "controller_name == 'gestores_individuais'",
              icon: "fas fa-circle",
              name: "Gestores Individuais",
              permission: :read,
              permission_check: :all
            }
          ]
        }
      ]
    end
  end
end
