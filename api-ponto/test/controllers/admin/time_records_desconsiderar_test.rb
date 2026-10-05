require "test_helper"

# Tarefa 30.2 (Sprint 30) — PONTO DE ENTRADA HTTP do gate D5 (desconsiderar),
# atrás da flag `FREQUENCIA_AUTORIZACAO_CASCATA` (`FrequenciaAutorizacaoCascata`,
# Decisão D3). Rota: `POST /time_records/:id/desconsiderar` (member action em
# `Admin::TimeRecordsController`; path real — o controller vive em
# `scope module: "admin"`, ver plano da 30.1 §1.3).
#
# O que se prova aqui (critérios da 30.2):
#   - `:off` → 404 (rota genuinamente indisponível; constraint de rota);
#   - `:shadow` → roda mas é NO-OP (nem `update!`/`create!`), só LOGA e responde
#     redirect com notice;
#   - `:on` → aplica o gate D5 (passo 5). Autorizado (gestor do órgão) → efeito
#     da Sprint 19 preservado (`desconsiderar!` + `IntervencaoFrequencia`);
#     negado → `CanCan::AccessDenied` (redirect do base) SEM efeito;
#   - `GestorIndividual` (passo 4) VÊ mas NÃO desconsidera (ruling D5);
#   - sem role → negado sem efeito;
#   - `justificativa` em branco → redirect com alert, sem efeito.
#
# A visibilidade/elegibilidade NÃO é stubada: é calculada pela própria cascata
# de produção sobre o SCHEMA REAL do espelho (ADR-0006) — mesmo padrão da
# matriz de aceite da 29.8. Pré-requisito:
# `RAILS_ENV=test bin/rails test:pessoas_schema:load`.
module Admin
  class TimeRecordsDesconsiderarTest < ActionDispatch::IntegrationTest
    include PessoasEspelhoHelper

    # Mesma data-âncora da suíte de elegibilidade (dia no passado; o motor só
    # marca `falta` em data já passada).
    DATA = Date.new(2026, 9, 7)
    META = 8 * 3600

    setup do
      skip_sem_espelho!
    end

    # ------------------------------------------------------------- :on / efeito

    test "on: gestor do orgao do alvo e autorizado e aplica desconsiderar! (efeito preservado)" do
      gestor, _alvo, registro = cenario_gestor_do_orgao

      com_flag("on") do
        login_como(gestor)
        post desconsiderar_time_record_path(registro), params: { justificativa: "Batida indevida" }
      end

      assert_redirected_to time_records_path
      assert flash[:notice].present?, "sucesso deve preencher flash notice"

      registro.reload
      assert registro.desconsiderado?, "o registro deve ser desconsiderado"
      assert registro.ressalva?, "desconsiderar! marca ressalva (efeito da Sprint 19)"

      intervencao = IntervencaoFrequencia.find_by(time_record: registro)
      assert intervencao, "desconsiderar! cria a IntervencaoFrequencia de auditoria"
      assert_equal "desconsideracao_ponto", intervencao.tipo
      assert_equal "registrado", intervencao.status
      assert_equal "Batida indevida", intervencao.justificativa
      assert_equal gestor.id, intervencao.responsavel_id,
                   "responsavel: current_user (o gestor logado)"
    end

    # ------------------------------------------------- GestorIndividual (D5)

    test "on: gestor individual (passo 4) VE mas NAO desconsidera — negado SEM efeito" do
      gestor, alvo, registro = cenario_gestor_individual

      # Sanidade do cenário: o acionador VÊ o alvo pela cascata de visualização
      # (passo 4) — sem isto, o teste passaria pela negativa errada.
      assert AutorizacaoFrequencia.new(gestor).pode_ver?(alvo),
             "pre-condicao D5: o gestor individual precisa VER (passo 4)"

      com_flag("on") do
        # A Ability NÃO concede a ação custom ao passo 4 (só o passo 5).
        refute Ability.new(gestor).can?(:desconsiderar, registro),
               "D5: gestor individual (passo 4) NAO pode desconsiderar"

        login_como(gestor)
        post desconsiderar_time_record_path(registro), params: { justificativa: "Tentativa" }
      end

      assert_redirected_to dashboard_path, "negado → redirect do base (rescue_from AccessDenied)"
      assert flash[:alert].present?, "AccessDenied deve preencher flash alert"

      registro.reload
      refute registro.desconsiderado?, "sem autorização → SEM efeito (nada desconsiderado)"
      assert_equal 0, IntervencaoFrequencia.where(time_record: registro).count,
                   "sem autorização → nenhuma IntervencaoFrequencia"
    end

    # ------------------------------------------------------------- sem role

    test "on: usuario sem role/hierarquia e negado SEM efeito" do
      alvo = criar_usuario(nome: "Alvo Sem Role D5", cpf: proximo_cpf_teste)
      registro = registrar_dia_elegivel(alvo)
      sem_role = criar_usuario(nome: "Sem Role D5")

      com_flag("on") do
        login_como(sem_role)
        post desconsiderar_time_record_path(registro), params: { justificativa: "Tentativa" }
      end

      assert_redirected_to dashboard_path
      assert flash[:alert].present?
      refute registro.reload.desconsiderado?
      assert_equal 0, IntervencaoFrequencia.where(time_record: registro).count
    end

    # ----------------------------------------------------------------- :off

    test "off: a rota NAO existe (404) e nenhum efeito" do
      gestor, _alvo, registro = cenario_gestor_do_orgao

      com_flag(nil) do
        login_como(gestor)
        post desconsiderar_time_record_path(registro), params: { justificativa: "Batida indevida" }
      end

      assert_response :not_found, "em :off a constraint da rota torna o caminho indisponível (404)"
      refute registro.reload.desconsiderado?
      assert_equal 0, IntervencaoFrequencia.where(time_record: registro).count
    end

    # --------------------------------------------------------------- :shadow

    test "shadow: roda mas e NO-OP — nao escreve, responde notice e LOGA o evento proprio (Q7)" do
      gestor, alvo, registro = cenario_gestor_do_orgao
      logger = RecordingLogger.new

      com_flag("shadow") do
        with_logger(logger) do
          login_como(gestor)
          post desconsiderar_time_record_path(registro), params: { justificativa: "Batida indevida" }
        end
      end

      assert_redirected_to time_records_path
      assert flash[:notice].present?, "shadow responde com notice (informa que está em observação)"

      registro.reload
      refute registro.desconsiderado?, "shadow é NO-OP: nada de update!"
      assert_equal 0, IntervencaoFrequencia.where(time_record: registro).count,
                   "shadow é NO-OP: nada de create!"

      # Evento PRÓPRIO do gate D5 (não reusa o de visualização — Q7).
      entrada = logger.entradas.find do |e|
        e[:evento] == "frequencia_autorizacao_cascata.desconsiderar_shadow"
      end
      assert entrada, "shadow do gate D5 deve logar o evento próprio"
      assert_equal alvo.id, entrada[:alvo_id]
      assert_equal :negaria, entrada[:decisao]
      refute logger.entradas.any? { |e| e[:evento] == "frequencia_autorizacao_cascata.shadow" },
             "não deve reusar o evento de shadow da VISUALIZAÇÃO"
    end

    test "on: negação efetiva LOGA o evento proprio do gate D5 (simetria com o shadow)" do
      alvo = criar_usuario(nome: "Alvo Neg Log D5", cpf: proximo_cpf_teste)
      registro = registrar_dia_elegivel(alvo)
      sem_role = criar_usuario(nome: "Sem Role Log D5")
      logger = RecordingLogger.new

      com_flag("on") do
        with_logger(logger) do
          login_como(sem_role)
          post desconsiderar_time_record_path(registro), params: { justificativa: "Tentativa" }
        end
      end

      assert_redirected_to dashboard_path
      entrada = logger.entradas.find do |e|
        e[:evento] == "frequencia_autorizacao_cascata.desconsiderar_negacao" && e[:alvo_id] == alvo.id
      end
      assert entrada, "no :on a negação efetiva do gate D5 deve logar o evento próprio"
    end

    # ---------------------------------------------------- justificativa vazia

    test "on: justificativa em branco → alert e SEM efeito (nao chama desconsiderar!)" do
      gestor, _alvo, registro = cenario_gestor_do_orgao

      com_flag("on") do
        login_como(gestor)
        post desconsiderar_time_record_path(registro), params: { justificativa: "" }
      end

      assert_redirected_to time_records_path
      assert flash[:alert].present?, "justificativa obrigatória → alert"

      registro.reload
      refute registro.desconsiderado?, "sem justificativa → SEM efeito"
      assert_equal 0, IntervencaoFrequencia.where(time_record: registro).count
    end

    # ------------------------------------- Ability (fonte única do gate D5)

    test "Ability: :desconsiderar so e concedida sob a cascata e so ao passo 5 (D5)" do
      gestor_orgao, _alvo1, registro1 = cenario_gestor_do_orgao
      gestor_individual, _alvo2, registro2 = cenario_gestor_individual

      # REGRA POSITIVA: sob `:on`, o passo 5 (gestor do órgão) PODE.
      com_flag("on") do
        assert Ability.new(gestor_orgao).can?(:desconsiderar, registro1),
               "passo 5 (gestor do orgao do alvo) deve poder desconsiderar"

        # D5: o passo 4 (GestorIndividual) NÃO pode — embora VEJA.
        refute Ability.new(gestor_individual).can?(:desconsiderar, registro2),
               "D5: gestor individual (passo 4) NAO pode desconsiderar"
      end

      # FAIL-CLOSED: sem a cascata a ação não existe (`:off` e `:shadow`).
      com_flag(nil) do
        refute Ability.new(gestor_orgao).can?(:desconsiderar, registro1),
               "sem a flag (:off) a acao nao e concedida"
      end
      com_flag("shadow") do
        refute Ability.new(gestor_orgao).can?(:desconsiderar, registro1),
               "shadow NAO concede o gate D5 (so observa)"
      end
    end

    # ------------------- D5 × `manage :all` (fall-through do admin)

    test "Ability: admin NAO-gestor NAO desconsidera sob :on (D5 vale para admin); manage :all segue" do
      # Regressão medida por probe (2026-10-05): com `can :manage, :all` para
      # admin, um `can` com bloco que devolve `false` CAI no `manage` e perde a
      # precedência (fall-through) — o admin NÃO-gestor desconsideraria. O
      # `cannot :desconsiderar, TimeRecord` (definido antes do `can` de bloco)
      # corta esse vazamento. O legado `podeDesconsiderarFrequencia` só chama
      # `isGestorOrgao` — não há curto-circuito de admin.
      admin = criar_usuario(nome: "Admin Nao Gestor D5", admin: true)
      alvo = criar_usuario(nome: "Alvo Admin Nao Gestor D5", cpf: proximo_cpf_teste)
      registro = registrar_dia_elegivel(alvo)

      com_flag("on") do
        ability = Ability.new(admin)
        refute ability.can?(:desconsiderar, registro),
               "D5: admin nao-gestor NAO pode desconsiderar (o manage :all nao pode vazar)"
        assert ability.can?(:manage, :all),
               "o restante do acesso do admin deve seguir intacto (manage :all)"
      end
    end

    # --------------------------------------------------------------------------
    # Infra
    # --------------------------------------------------------------------------

    private

    # Cenário "gestor do órgão do alvo, com dia elegível": o acionador é gestor
    # da unidade RAIZ onde o alvo está lotado (passo 5 da cascata); o alvo tem um
    # TimeRecord + CalculoDiario elegíveis na data-âncora.
    def cenario_gestor_do_orgao
      cpf_gestor = proximo_cpf_teste
      gestor_pessoa = criar_pessoa(cpf: cpf_gestor, nome: "Gestor D5")
      raiz = criar_unidade(descricao: "Raiz D5 #{SecureRandom.hex(3)}", active: true,
                           gestor_id: gestor_pessoa.id)

      cpf_alvo = proximo_cpf_teste
      criar_pessoa_lotada(unidade: raiz, cpf: cpf_alvo, nome: "Alvo D5")
      alvo = criar_usuario(nome: "Alvo D5", cpf: cpf_alvo)
      gestor = criar_usuario(nome: "Gestor D5", cpf: cpf_gestor)

      registro = registrar_dia_elegivel(alvo)

      # Sanidade do cenário: o acionador É gestor do órgão do alvo (sem isto os
      # testes de `:on` passariam pela negativa, e não pela autorização).
      assert AutorizacaoFrequencia.new(gestor).gestor_de_orgao_do?(alvo),
             "pre-condicao: o acionador precisa ser gestor do orgao do alvo"

      [ gestor, alvo, registro ]
    end

    # Gestor individual ATIVO do alvo (passo 4) — sem hierarquia (não é gestor
    # de órgão).
    def cenario_gestor_individual
      alvo = criar_usuario(nome: "Alvo GI D5", cpf: proximo_cpf_teste)
      gestor = criar_usuario(nome: "Gestor GI D5")
      gestor_individual(gerido: alvo, gestor_user: gestor, ativo: true)
      registro = registrar_dia_elegivel(alvo)
      [ gestor, alvo, registro ]
    end

    # TimeRecord + CalculoDiario elegíveis na data-âncora (mesma montagem do
    # teste da 29.5).
    def registrar_dia_elegivel(user)
      registro = TimeRecord.create!(
        user: user,
        raw_data: "#{DATA} 08:00:00",
        punched_at: Time.zone.local(DATA.year, DATA.month, DATA.day, 8, 0),
        authentication_mode: "biometric"
      )
      CalculoDiario.create!(user: user, data: DATA, meta_segundos: META)
      registro
    end

    def criar_usuario(nome: "Usuario D5", cpf: nil, admin: false, roles: [])
      user = User.create!(nome_completo: nome, password: "123456", cpf: cpf, admin: admin)
      roles.each { |role| user.add_role(role) }
      user
    end

    def gestor_individual(gerido:, gestor_user:, ativo: true)
      gestor = GestorIndividual.create!(nome: "Gestor Teste D5", gestor_user: gestor_user)
      vinculo = GestorIndividualGerenciado.create!(gestor_individual: gestor, user: gerido)
      vinculo.desativar! unless ativo
      vinculo
    end

    # Users COM cpf autenticam contra o Pessoas2 — o ponto de entrada é stubado
    # para devolver o hash de "123456" a QUALQUER cpf (mesmo padrão da matriz).
    def login_como(user)
      hash = BCrypt::Password.create("123456")
      fake = Struct.new(:encrypted_password).new(hash)
      com_metodo_de_classe_stubado(Pessoas::User, :buscar_por_cpf, ->(_cpf) { fake }) do
        post login_path, params: { username: user.username, password: "123456" }
      end
    end

    def proximo_cpf_teste
      PessoasEspelhoHelper.proximo_cpf
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

    def with_logger(logger)
      anterior = Rails.logger
      Rails.logger = logger
      yield
    ensure
      Rails.logger = anterior
    end

    class RecordingLogger
      def initialize
        @entradas = []
      end

      def info(payload = nil)
        @entradas << payload if payload.is_a?(Hash)
      end

      def warn(*); end
      def debug(*); end
      def error(*); end
      def fatal(*); end
      def level(*); end
      def add(*); end

      # O Rails consulta o formatter ao renderizar a 404 (exception handling);
      # sem isto o logger de teste estoura `NoMethodError`.
      def formatter
        @formatter ||= Logger::Formatter.new
      end

      def formatter=(value)
        @formatter = value
      end

      attr_reader :entradas
    end
  end
end
