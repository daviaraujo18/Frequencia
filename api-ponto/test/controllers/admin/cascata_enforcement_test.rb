require "test_helper"

# Tarefa 33.1 (Sprint 33) — Camada 1 (runtime): testes do contrato de declaração
# de postura + guard fail-closed (`Admin::ApplicationController#verificar_postura_cascata`).
#
# Tarefa 33.4 (Sprint 33) — ESTENDE este arquivo (não recria): a 33.1 já entregava
# T4 (fail-closed sob `raise`) e T5 (`log` → não levanta + UM WARN). O delta da
# 33.4 é (a) o ENDURECIMENTO de T5 (prova que o WARN é o do guard, não espúrio) e
# (b) a prova de NÃO-VACUIDADE por mutation testing — as 3 mutações (neutralizar
# o guard; remover o hook `included do` do concern; trocar o predicado da flag no
# PORO) foram executadas sobre `app/**` e cada uma derruba o teste correspondente.
# O projeto não tem framework de mutation testing: a prova são os NÚMEROS medidos,
# registrados em `docs/progress/iteration_33.md` §Notas (33.4), no idiom dos
# reviews anteriores (29.3/29.6/32.1/32.2).
#
# Cobre cada critério de aceite testável da 33.1:
#   - controller sem postura sob `raise` → levanta `CascataNaoDeclaradaError`;
#   - `log` ≠ `raise`: mesmo cenário sob `log` → NÃO levanta, emite UM WARN;
#   - a mensagem é idêntica nos dois modos (único delta: levantar × WARN);
#   - fail-closed em TODOS os estados de `FREQUENCIA_AUTORIZACAO_CASCATA`;
#   - no-op para `:coberto` e para `:dispensado` (com justificativa);
#   - macro exige justificativa (`""`/`nil` → ArgumentError);
#   - cobertura: todo `Admin::*` declara postura; a base `Presenca::*` não é afetada.
#
# O guard é exercitado DIRETO (sem HTTP): ele só lê `self.class.cascata_postura`
# e o estado da flag `FREQUENCIA_CASCATA_ENFORCEMENT` — não depende de request.
module Admin
  # Controller de teste que NÃO declara postura de propósito (default `nil`).
  class SemPosturaTestStubController < Admin::ApplicationController
  end

  # Controller de teste que declara `:dispensado` via macro (justificativa real).
  class DispensadoTestStubController < Admin::ApplicationController
    fora_da_cascata_justificativa("controller de teste — não lê recursos de frequência")
  end

  # Controller de teste DEDICADO ao teste de persistência da justificativa —
  # isolado para não contaminar o `SemPosturaTestStubController`, que outros
  # testes exigem permanentemente sem postura (ordem aleatória da suíte).
  class JustificativaPersistidaTestStubController < Admin::ApplicationController
  end

  # Controller de teste SEM postura, roteável, para provar o guard numa ACTION
  # real (via `with_routing`). Skips os before_actions que dependem de rotas/
  # sessão do app — o alvo é o `verificar_postura_cascata`.
  class SemPosturaWiringController < Admin::ApplicationController
    skip_before_action :require_login, :set_configurations, :verify_authenticity_token
    skip_authorization_check

    def index
      render plain: "ok"
    end
  end

  class CascataEnforcementTest < ActiveSupport::TestCase
    test "o guard esta registrado como before_action na base admin" do
      filtros = Admin::ApplicationController._process_action_callbacks.map(&:filter)
      assert_includes filtros, :verificar_postura_cascata
    end

    # ------------------------------------------------------------------
    # (1) Contrato: sem postura sob `raise` → levanta
    # ------------------------------------------------------------------
    test "controller sem postura sob raise levanta CascataNaoDeclaradaError" do
      com_enforcement("raise") do
        erro = assert_raises(CascataNaoDeclaradaError) { guard(Admin::SemPosturaTestStubController) }
        assert_match "Admin::SemPosturaTestStubController", erro.message
      end
    end

    # ------------------------------------------------------------------
    # (2) `log` ≠ `raise`: NÃO levanta, emite um WARN com o nome da classe
    # ------------------------------------------------------------------
    test "mesmo controller sob log NAO levanta e emite UM warn do guard (nao espurio)" do
      com_enforcement("log") do
        with_logger do |io|
          guard(Admin::SemPosturaTestStubController) # não deve levantar

          warns = io.string.lines.select { |linha| linha.include?("WARN") }
          assert_equal 1, warns.size, "deve emitir exatamente um WARN"
          # 33.4 (endurecimento): o único WARN TEM de ser o do guard — carrega o
          # nome da classe E o marcador da mensagem de `verificar_postura_cascata`.
          # Um WARN espúrio (de outra origem no mesmo logger) não satisfaz este
          # assert, o que prova que a emissão vem da decisão sob teste.
          assert_match "Admin::SemPosturaTestStubController", warns.first
          assert_match "sem postura de cascata declarada", warns.first
        end
      end
    end

    test "log e raise produzem a MESMA mensagem (unico delta: levantar x WARN)" do
      msg_raise = assert_raises(CascataNaoDeclaradaError) do
        com_enforcement("raise") { guard(Admin::SemPosturaTestStubController) }
      end.message

      msg_log = nil
      with_logger do |io|
        com_enforcement("log") { guard(Admin::SemPosturaTestStubController) }
        msg_log = io.string
      end

      assert_includes msg_log, msg_raise
    end

    # ------------------------------------------------------------------
    # (3) Fail-closed em TODOS os estados de FREQUENCIA_AUTORIZACAO_CASCATA (D2)
    # ------------------------------------------------------------------
    test "fail-closed independe de FREQUENCIA_AUTORIZACAO_CASCATA (off/shadow/on)" do
      %w[off shadow on].each do |estado|
        com_cascata_flag(estado) do
          com_enforcement("raise") do
            assert_raises(CascataNaoDeclaradaError, "estado #{estado}") do
              guard(Admin::SemPosturaTestStubController)
            end
          end
        end
      end
    end

    # ------------------------------------------------------------------
    # (4) No-op para quem declarou
    # ------------------------------------------------------------------
    test "no-op para controller :coberto (clude o concern)" do
      assert_equal :coberto, Admin::FrequenciaController.cascata_postura

      com_enforcement("raise") { assert_nil guard(Admin::FrequenciaController) }
    end

    test "no-op para controller :dispensado (meta declarou justificativa)" do
      assert_equal :dispensado, Admin::DispensadoTestStubController.cascata_postura

      com_enforcement("raise") { assert_nil guard(Admin::DispensadoTestStubController) }

      com_enforcement("log") do
        with_logger do |io|
          guard(Admin::DispensadoTestStubController)
          assert_empty io.string, "um :dispensado não deve emitir WARN"
        end
      end
    end

    # ------------------------------------------------------------------
    # (5) Macro exige justificativa
    # ------------------------------------------------------------------
    test "fora_da_cascata_justificativa exige justificativa nao-vazia" do
      [ "", nil, "   " ].each do |motivo|
        assert_raises(ArgumentError, "motivo #{motivo.inspect}") do
          Admin::SemPosturaTestStubController.fora_da_cascata_justificativa(motivo)
        end
      end

      assert_nil Admin::SemPosturaTestStubController.cascata_postura,
                 "a macro falhou antes de setar a postura — a classe continua sem declarar"
    end

    test "fora_da_cascata_justificativa PERSISTE o motivo (runtime, sem grep)" do
      motivo = "motivo persistido de teste — corpo gateado por current_user.admin?"
      Admin::JustificativaPersistidaTestStubController.fora_da_cascata_justificativa(motivo)

      assert_equal :dispensado, Admin::JustificativaPersistidaTestStubController.cascata_postura
      assert_equal motivo, Admin::JustificativaPersistidaTestStubController.cascata_justificativa,
                   "o motivo deve ficar legível em runtime (a 33.2 não pode depender de grep no fonte)"
    end

    # ------------------------------------------------------------------
    # (6) Cobertura de anotação: todo Admin::* declara postura
    # ------------------------------------------------------------------
    test "todo controller Admin::* da arvore declara postura de cascata" do
      classes = admin_controller_classes.reject { |klass| klass == Admin::ApplicationController }

      assert_operator classes.size, :>, 10, "esperado encontrar os controllers Admin::* reais"

      classes.each do |klass|
        assert klass.cascata_postura.present?,
               "#{klass} não declara postura (:coberto ou :dispensado) — o guard o barraria"
      end
    end

    # ------------------------------------------------------------------
    # (7) A base Presenca::* NÃO é alcançada pelo guard
    # ------------------------------------------------------------------
    test "a base Presenca::* nao herda o guard nem a postura" do
      refute Presenca::ApplicationController <= Admin::ApplicationController
      refute Presenca::ApplicationController.respond_to?(:cascata_postura),
             "Presenca::ApplicationController não deve expor a postura da cascata"

      # Prova por EFEITO (não só relação de herança estática): o guard não está
      # na cadeia de callbacks de uma action Presenca::*. Um controller novo
      # Presenca::* jamais é barrado por `verificar_postura_cascata`.
      filtros = Presenca::ApplicationController._process_action_callbacks.map(&:filter)
      refute_includes filtros, :verificar_postura_cascata,
                      "o guard de postura não deve alcançar a base Presenca::*"
    end

    # ------------------------------------------------------------------
    # (8) PORO da flag de enforcement
    # ------------------------------------------------------------------
    test "default do enforcement e raise em test (sem ENV explicita)" do
      com_enforcement(nil) do
        assert_equal :raise, FrequenciaCascataEnforcement.modo
        assert FrequenciaCascataEnforcement.raise?
        refute FrequenciaCascataEnforcement.log?
      end
    end

    test "valores da flag: familia LIGAR -> raise; familia OBSERVAR -> log" do
      %w[raise levantar RAISE On true 1 YES enabled ativo strict].each do |valor|
        com_enforcement(valor) { assert_equal :raise, FrequenciaCascataEnforcement.modo, "valor #{valor}" }
      end
      %w[log avisar warn off OFF false 0 no observar shadow].each do |valor|
        com_enforcement(valor) { assert_equal :log, FrequenciaCascataEnforcement.modo, "valor #{valor}" }
      end
    end

    test "valor NAO reconhecido falha-closed (raise) e emite UM warn (BF-M2)" do
      com_enforcement("lg") do
        modo = nil
        with_logger do |io|
          modo = FrequenciaCascataEnforcement.modo
          assert_equal 1, io.string.lines.count { |l| l.include?("WARN") }
          assert_match "não reconhecido", io.string
        end
        assert_equal :raise, modo, "valor ambíguo nunca deve desligar o gate em silêncio"
      end
    end

    test "fora de test: default e :log, mas CI so liga se truthy (BF baixo)" do
      prod = ActiveSupport::EnvironmentInquirer.new("production")
      com_metodo_de_classe_stubado(Rails, :env, -> { prod }) do
        com_env("CI", nil)     { assert_equal :log,   FrequenciaCascataEnforcement.send(:padrao) }
        com_env("CI", "false") { assert_equal :log,   FrequenciaCascataEnforcement.send(:padrao) }
        com_env("CI", "0")     { assert_equal :log,   FrequenciaCascataEnforcement.send(:padrao) }
        com_env("CI", "1")     { assert_equal :raise, FrequenciaCascataEnforcement.send(:padrao) }
        com_env("CI", "true")  { assert_equal :raise, FrequenciaCascataEnforcement.send(:padrao) }
      end
    end

    # ------------------------------------------------------------------
    # (9) A postura NÃO é herdada por subclasse de concreto (BF-M1)
    # ------------------------------------------------------------------
    test "postura nao e herdada por subclasse de controller admin concreto" do
      filho_dispensado = Class.new(Admin::DashboardController)
      assert_nil filho_dispensado.cascata_postura,
                 "filho de :dispensado não deve herdar postura (falso-verde)"
      assert_nil filho_dispensado.cascata_justificativa, "nem a justificativa alheia"

      filho_coberto = Class.new(Admin::FrequenciaController)
      assert_nil filho_coberto.cascata_postura, "filho de :coberto não deve herdar postura"

      com_enforcement("raise") do
        assert_raises(CascataNaoDeclaradaError) { guard(filho_dispensado) }
        assert_raises(CascataNaoDeclaradaError) { guard(filho_coberto) }
      end
    end

    private

    # Exercita o guard direto (método privado do before_action).
    def guard(controller_class)
      controller_class.new.send(:verificar_postura_cascata)
    end

    # Substitui `Rails.logger` por um logger que escreve num StringIO, restaurando
    # ao final — mesmo idioma dos testes existentes (jobs/handlers).
    def with_logger
      anterior = Rails.logger
      io = StringIO.new
      Rails.logger = Logger.new(io)
      yield io
    ensure
      Rails.logger = anterior
    end

    # Classes dos controllers `Admin::*` reais (varredura dos arquivos-fonte, sem
    # lista paralela). O glob só enxerga `app/controllers/admin/`, nunca os stubs.
    def admin_controller_classes
      Dir[Rails.root.join("app/controllers/admin/*_controller.rb")].sort.map do |path|
        nome = File.basename(path, ".rb") # "frequencia_por_orgao_controller"
        "Admin::#{nome.camelize}".constantize
      end
    end

    # Executa o bloco com `FREQUENCIA_CASCATA_ENFORCEMENT` = `valor` (nil remove) e
    # restaura o valor anterior — mesmo idioma dos testes de cascata (29.7).
    def com_enforcement(valor)
      com_env(FrequenciaCascataEnforcement::VARIAVEL, valor) { yield }
    end

    # Executa o bloco com `FREQUENCIA_AUTORIZACAO_CASCATA` = `valor` (nil remove).
    def com_cascata_flag(valor)
      com_env(FrequenciaAutorizacaoCascata::VARIAVEL, valor) { yield }
    end

    def com_env(variavel, valor)
      anterior = ENV[variavel]
      if valor.nil?
        ENV.delete(variavel)
      else
        ENV[variavel] = valor
      end
      yield
    ensure
      if anterior.nil?
        ENV.delete(variavel)
      else
        ENV[variavel] = anterior
      end
    end
  end

  # Prova do gate numa ACTION real: o guard, registrado como before_action na
  # base admin, barra (raise) ou apenas avisa (log) a execução de um controller
  # `Admin::*` sem postura. Exercita a cadeia de callbacks, não só o método.
  class CascataEnforcementWiringTest < ActionDispatch::IntegrationTest
    test "action de controller admin sem postura: raise barra, log so avisa" do
      with_routing do |set|
        set.draw { get "/sem_postura_wiring", to: "admin/sem_postura_wiring#index" }

        com_enforcement("raise") do
          assert_raises(CascataNaoDeclaradaError) { get "/sem_postura_wiring" }
        end

        com_enforcement("log") do
          with_logger do |io|
            get "/sem_postura_wiring"
            assert_response :success

            # 33.4 (endurecimento — M1 do review 33.4): a cadeia REAL de callbacks
            # também prova que o WARN vem do guard. Um request completo pode logar
            # OUTROS WARNs, então filtramos a linha do GUARD (nome da classe +
            # marcador), em vez de contar todos os WARNs do logger.
            warns_do_guard = io.string.lines.select do |linha|
              linha.include?("WARN") && linha.include?("Admin::SemPosturaWiringController")
            end
            assert_equal 1, warns_do_guard.size,
                         "o guard deve emitir exatamente um WARN para a classe sem postura"
            assert_match "sem postura de cascata declarada", warns_do_guard.first,
                         "o WARN tem de ser o do guard (`verificar_postura_cascata`), não espúrio"
          end
        end
      end
    end

    private

    def com_enforcement(valor)
      anterior = ENV[FrequenciaCascataEnforcement::VARIAVEL]
      if valor.nil?
        ENV.delete(FrequenciaCascataEnforcement::VARIAVEL)
      else
        ENV[FrequenciaCascataEnforcement::VARIAVEL] = valor
      end
      yield
    ensure
      if anterior.nil?
        ENV.delete(FrequenciaCascataEnforcement::VARIAVEL)
      else
        ENV[FrequenciaCascataEnforcement::VARIAVEL] = anterior
      end
    end

    def with_logger
      anterior = Rails.logger
      io = StringIO.new
      Rails.logger = Logger.new(io)
      yield io
    ensure
      Rails.logger = anterior
    end
  end
end
