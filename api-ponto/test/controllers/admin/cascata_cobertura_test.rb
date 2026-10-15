require "test_helper"
require "tmpdir"
require "fileutils"
require_relative "../../support/cobertura_cascata"

# Tarefa 33.2 (Sprint 33) — Camada 2 (build): META-TESTE DE DRIFT da cascata de
# autorização. Fecha a CLASSE do Bug 🔴1 — um controller `Admin::*` que lê um
# recurso de frequência SEM declarar postura — em QUALQUER estado da flag. O
# detector consumido é o helper `CoberturaCascata` (`test/support/`), exercitado
# aqui com arquivos SINTÉTICOS em memória (T1/M1/M2/M3) e com a árvore real (T2/T3).
#
# Cobre cada critério de aceite testável da 33.2:
#   - T1: controller novo sensível sem declaração → REPROVADO (arquivo sintético);
#   - T2: a árvore real declara postura → verde; injetar um sensível sem postura → vermelho;
#   - T3: recíproco — todo `:coberto` inclui `FrequenciaAuthorization`;
#   - conjunto fechado e justificado (Q33-C);
#   - M1: varredura RECURSIVA + resolução por classe (subpasta / fora de `admin/`);
#   - M2: base abstrata excluída e comentários ignorados;
#   - M3: justificativa lida em RUNTIME (`cascata_justificativa`), nunca por grep;
#   - flag-independente: não lê `FREQUENCIA_AUTORIZACAO_CASCATA`/`FREQUENCIA_CASCATA_ENFORCEMENT`.
module Admin
  # `:dispensado` "mentindo": seta a postura SEM justificativa em runtime — o
  # estado que a macro torna inalcançável, mas que o detector precisa reprovar
  # (M3). Usado para provar que a checagem é runtime, não grep no texto-fonte.
  class DispensadoSemJustificativaTestStubController < Admin::ApplicationController
    self.cascata_postura = :dispensado
  end

  # `:dispensado` legítimo via a macro da Camada 1 (justificativa persistida).
  class DispensadoComJustificativaTestStubController < Admin::ApplicationController
    fora_da_cascata_justificativa("controller de teste — não lê recursos de frequência")
  end

  # `:coberto` "mentindo": declara participar da cascata mas NÃO inclui o concern
  # (usado no assert recíproco T3 — remover o `include` deve reprovar).
  class CobertoSemIncludeTestStubController < Admin::ApplicationController
    self.cascata_postura = :coberto
  end

  # Controller que vive sob `admin/**` mas NÃO herda a base admin (herda a RAIZ) —
  # prova o critério por CAMINHO (M1 do review 33.2). Sem ele, a varredura por
  # ancestralidade o deixaria ESCAPAR (falso-negativo na classe exata que a 33.2
  # fecha). O `::` é OBRIGATÓRIO: dentro de `module Admin`, `ApplicationController`
  # resolveria para `Admin::ApplicationController` e o stub herdaria a base admin
  # (bug_report_33_2, Bug 2 — o teste não exercia o critério de caminho).
  class NaoHerdaBaseAdminTestStubController < ::ApplicationController
  end

  class CoberturaCascataTest < ActiveSupport::TestCase
    # ------------------------------------------------------------------
    # (conjunto fechado e justificado)
    # ------------------------------------------------------------------
    test "o conjunto sensivel e exatamente o fechado (Q33-C)" do
      # Asserta o conjunto LITERAL (não-tautológico): documenta o contrato e falha
      # ALTO se a `Ability` ganhar/perder um recurso — forçando atualização
      # consciente (bug_report_33_2, Obs.: comparar com a própria expressão
      # derivada seria tautológico). O detector DERIVA da `Ability` (§Notas 33.2,
      # M2), então NÃO há falso-negativo silencioso; este assert é a trava de
      # contrato.
      assert_equal %w[TimeRecord CalculoDiario RegistroMensalFrequencia
                      IntervencaoFrequencia Pessoas::Vinculo],
                   CoberturaCascata::RECURSOS_SENSIVEIS
    end

    test "Bug1(33.2): classe retida sem cascata_postura e DRIFT, nao NoMethodError" do
      arquivo = CoberturaCascata::Arquivo.new(
        caminho: "/probe/admin/top_level_controller.rb",
        conteudo: "class Admin::TopLevelController < ::ApplicationController\n" \
                  "  def index; TimeRecord.all; end\nend\n",
        klass: Admin::NaoHerdaBaseAdminTestStubController
      )

      refute arquivo.klass.respond_to?(:cascata_postura), "pré-condição: a classe não declara postura"
      assert_equal [ arquivo ], CoberturaCascata.detectores([ arquivo ]),
                   "sem `cascata_postura` deve REPROVAR (drift), nunca levantar NoMethodError"
    end

    # ------------------------------------------------------------------
    # (T1) controller novo sem declaração FALHA — arquivo sintético
    # ------------------------------------------------------------------
    test "T1: arquivo sintetico que le TimeRecord sem declarar e rejeitado" do
      arquivo = sintetico(<<~RUBY)
        class Admin::NovoController < Admin::ApplicationController
          def index
            @registros = TimeRecord.all
          end
        end
      RUBY

      assert_equal [ arquivo ], CoberturaCascata.detectores([ arquivo ]),
                   "um controller novo que lê frequência sem declarar deve ser REPROVADO"
    end

    test "T1 (contraprova): o mesmo arquivo com declaração runtime NAO e rejeitado" do
      conteudo = "TimeRecord.all\n"
      declarado = sintetico(conteudo, klass: Admin::FrequenciaController)
      refute_includes CoberturaCascata.detectores([ declarado ]), declarado
    end

    # ------------------------------------------------------------------
    # (T2) toda a árvore real declara postura
    # ------------------------------------------------------------------
    test "T2: a arvore real de controllers nao tem drift (verde)" do
      arquivos = CoberturaCascata.arquivos_do_app

      assert_operator arquivos.size, :>=, 10, "esperado encontrar os controllers admin reais"
      assert_empty CoberturaCascata.detectores(arquivos),
                   "nenhum controller sensível da árvore real pode ficar sem declaração"
    end

    test "T2: injetar um controller sensivel sem postura deixa o gate VERMELHO" do
      arquivos = CoberturaCascata.arquivos_do_app
      intruso = sintetico("Pessoas::Vinculo.frequentadores_ativos\n")

      drift = CoberturaCascata.detectores(arquivos + [ intruso ])
      assert_equal [ intruso ], drift
    end

    # ------------------------------------------------------------------
    # (T3) assert recíproco: :coberto ⟺ inclui FrequenciaAuthorization
    # ------------------------------------------------------------------
    test "T3: todo controller :coberto da arvore realmente inclui o concern" do
      cobertos = CoberturaCascata.arquivos_do_app.map(&:klass).compact
                                              .select { |k| k.cascata_postura == :coberto }

      refute_empty cobertos, "esperado encontrar controllers :coberto na árvore real"
      cobertos.each do |klass|
        assert klass.include?(FrequenciaAuthorization),
               "#{klass} declara :coberto mas não inclui FrequenciaAuthorization (declaração mentirosa)"
      end
    end

    test "T3: um :coberto que nao inclui o concern e reprovado (remover o include -> falha)" do
      refute CoberturaCascata.declarado?(Admin::CobertoSemIncludeTestStubController),
             "declarar :coberto sem incluir o concern não pode contar como declaração"

      arquivo = sintetico("TimeRecord.all\n", klass: Admin::CobertoSemIncludeTestStubController)
      assert_equal [ arquivo ], CoberturaCascata.detectores([ arquivo ])
    end

    # ------------------------------------------------------------------
    # (M1) varredura RECURSIVA + por classe
    # ------------------------------------------------------------------
    test "M1: a varredura e recursiva (enxerga subpastas reais)" do
      caminhos = CoberturaCascata.caminhos_controller(Rails.root.join("app/controllers"))

      assert(caminhos.any? { |p| p.include?("/presenca/") },
             "a varredura deve descer em subpastas (glob recursivo)")
    end

    test "M1: controller sensivel em SUBPASTA e enumerado e reprovado (arquivo sintetico)" do
      Dir.mktmpdir do |tmp|
        aninhado = File.join(tmp, "admin", "sub", "novo_controller.rb")
        FileUtils.mkdir_p(File.dirname(aninhado))
        File.write(aninhado, "class Admin::Sub::NovoController\n  def index; TimeRecord.all; end\nend\n")

        arquivos = CoberturaCascata.arquivos_do_app(raiz: tmp)

        assert_equal [ aninhado ], arquivos.map(&:caminho),
                     "o glob recursivo deve alcançar o controller em subpasta"
        assert_equal [ aninhado ], CoberturaCascata.detectores(arquivos).map(&:caminho),
                     "um sensível em subpasta sem declaração deve ser reprovado"
      end
    end

    test "M1(33.2): controller sob admin/ que NAO herda a base admin e retido (criterio por CAMINHO)" do
      Dir.mktmpdir do |tmp|
        FileUtils.mkdir_p(File.join(tmp, "admin"))
        caminho = File.join(tmp, "admin", "nao_herda_base_admin_test_stub_controller.rb")
        File.write(caminho, "class Admin::NaoHerdaBaseAdminTestStubController < ApplicationController\nend\n")

        arquivos = CoberturaCascata.arquivos_do_app(raiz: tmp)

        assert_includes arquivos.map(&:caminho), caminho,
                        "critério por CAMINHO deve reter todo `admin/**/*_controller.rb`, " \
                        "mesmo que a classe NÃO herde a base admin (senão escaparia — M1)"
      end
    end

    # ------------------------------------------------------------------
    # (M2) base abstrata excluída e comentários ignorados
    # ------------------------------------------------------------------
    test "M2: a base abstrata (application_controller) e excluida" do
      arquivos = CoberturaCascata.arquivos_do_app

      refute_includes arquivos.map { |a| File.basename(a.caminho) }, "application_controller.rb"
      refute_includes arquivos.map(&:klass), Admin::ApplicationController
    end

    test "M2: um recurso citado APENAS em comentario nao conta como sensivel" do
      refute CoberturaCascata.sensivel?("# só comenta TimeRecord/CalculoDiario aqui\n"),
             "recurso em comentário não pode marcar o arquivo como sensível"
      refute CoberturaCascata.sensivel?("   # Pessoas::Vinculo\n"), "comentário indentado também é ignorado"
    end

    test "M2: estacoes (só comentário) não é sensível; dashboard (código real) é" do
      estacoes = Rails.root.join("app/controllers/admin/estacoes_controller.rb")
      dashboard = Rails.root.join("app/controllers/admin/dashboard_controller.rb")

      refute CoberturaCascata.sensivel?(File.read(estacoes)),
             "estacoes casa o conjunto só por comentário — não é sensível"
      assert CoberturaCascata.sensivel?(File.read(dashboard)),
             "dashboard lê TimeRecord em código real — é sensível (declarado :dispensado)"
    end

    # ------------------------------------------------------------------
    # (M3) justificativa lida em RUNTIME — nunca por grep no texto-fonte
    # ------------------------------------------------------------------
    test "M3: :dispensado sem cascata_justificativa em runtime e reprovado (sem grep)" do
      # O TEXTO-FONTE menciona a macro com justificativa, mas o RUNTIME não tem
      # justificativa — o detector não pode se deixar enganar pelo texto.
      conteudo = "fora_da_cascata_justificativa(\"motivo só no texto\")\nTimeRecord.all\n"
      arquivo = sintetico(conteudo, klass: Admin::DispensadoSemJustificativaTestStubController)

      assert_nil Admin::DispensadoSemJustificativaTestStubController.cascata_justificativa
      assert_equal [ arquivo ], CoberturaCascata.detectores([ arquivo ]),
                   "a checagem deve ler cascata_justificativa em runtime, não o texto-fonte"
    end

    test "M3: :dispensado com cascata_justificativa persistida é aceito" do
      arquivo = sintetico("TimeRecord.all\n", klass: Admin::DispensadoComJustificativaTestStubController)

      assert Admin::DispensadoComJustificativaTestStubController.cascata_justificativa.present?
      assert_empty CoberturaCascata.detectores([ arquivo ])
    end

    # ------------------------------------------------------------------
    # (flag-independente)
    # ------------------------------------------------------------------
    test "flag-independente: o resultado nao depende das flags de cascata/enforcement" do
      arquivos = CoberturaCascata.arquivos_do_app
      esperado = CoberturaCascata.detectores(arquivos).map(&:caminho)

      [ %w[off log], %w[shadow log], %w[on raise] ].each do |cascata, enforcement|
        com_env("FREQUENCIA_AUTORIZACAO_CASCATA", cascata) do
          com_env("FREQUENCIA_CASCATA_ENFORCEMENT", enforcement) do
            assert_equal esperado, CoberturaCascata.detectores(arquivos).map(&:caminho),
                         "o meta-teste é flag-independente (cascata=#{cascata}, enforcement=#{enforcement})"
          end
        end
      end
    end

    private

    # Arquivo sintético (em memória) — nada é escrito no repositório.
    def sintetico(conteudo, caminho: "app/controllers/admin/novo_controller.rb", klass: nil)
      CoberturaCascata::Arquivo.new(caminho: caminho, conteudo: conteudo, klass: klass)
    end

    # Executa o bloco com `variavel`=valor (nil remove) e restaura — mesmo idioma
    # dos testes de cascata (29.7) e do 33.1.
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
end
