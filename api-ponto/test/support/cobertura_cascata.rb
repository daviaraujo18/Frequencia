# frozen_string_literal: true

require "pathname"

# Tarefa 33.2 (Sprint 33) — Camada 2 (build): detector de drift da cascata de
# autorização. Fecha a CLASSE do Bug 🔴1 — um controller novo que lê frequência
# (`TimeRecord`/`CalculoDiario`/`RegistroMensalFrequencia`/`IntervencaoFrequencia`/
# `Pessoas::Vinculo`) e não declara postura de cascata — em QUALQUER estado da
# flag, inclusive no `:off` de produção, onde a Camada 1 (o guard de runtime) é
# no-op. É FLAG-INDEPENDENTE: NÃO lê `FREQUENCIA_AUTORIZACAO_CASCATA` nem
# `FREQUENCIA_CASCATA_ENFORCEMENT` (ver o meta-teste `cascata_cobertura_test.rb`).
#
# Duas responsabilidades, deliberadamente separadas para serem UNIT-TESTÁVEIS:
#
#   1. SENSIBILIDADE (`sensivel?`) — ESTÁTICA, por conteúdo. Um controller é
#      "sensível" se cita um dos recursos do conjunto fechado (Q33-C) FORA de
#      linha de comentário. M2 do review 33.1: `estacoes_controller.rb:4` casa
#      só por comentário; a base casa por causa do menu (`permission_check:
#      TimeRecord`) — nenhum dos dois "lê" o recurso.
#   2. DECLARAÇÃO (`declarado?`) — RUNTIME, pela CLASSE (M3 do review 33.1).
#      Lê `cascata_postura` (o contrato que a Camada 1 introduz) e, para
#      `:dispensado`, exige `cascata_justificativa.present?` (persistida pela
#      macro `fora_da_cascata_justificativa`). NUNCA faz grep no texto-fonte: um
#      `:dispensado` sem justificativa em runtime é REPROVADO mesmo que o texto
#      mencione `fora_da_cascata_justificativa("…")` (declaração morta).
#
# O detector puro (`detectores`) opera sobre uma lista de `Arquivo`, o que
# permite provar T1/M1/M2/M3 com arquivos SINTÉTICOS em memória — sem criar
# arquivos no repositório.
module CoberturaCascata
  # Conjunto FECHADO de recursos sensíveis (Q33-C = sim), DERIVADO da fonte única
  # `Ability::RECURSOS_FREQUENCIA` (`ability.rb:74-79`) + `Pessoas::Vinculo`
  # (M2 do review 33.2: NADA de lista PARALELA — um recurso novo na `Ability`
  # passa a ser coberto automaticamente, sem falso-negativo silencioso).
  RECURSOS_SENSIVEIS = (Ability::RECURSOS_FREQUENCIA.map(&:name) + [ "Pessoas::Vinculo" ]).freeze

  # Um "arquivo de controller varrido": o conteúdo-fonte e, quando resolvível, a
  # CLASSE real correspondente — a fonte da verdade da declaração em runtime.
  Arquivo = Struct.new(:caminho, :conteudo, :klass, keyword_init: true)

  class << self
    # --- (1) sensibilidade: estática, por conteúdo ------------------------

    # Um recurso citado APENAS numa LINHA DE COMENTÁRIO (linha inteira) NÃO conta
    # como sensível (M2). Comentário no FIM de uma linha de código NÃO é
    # descartado — a sobre-inclusão é INTENCIONAL (fail-closed: entre acusar de
    # mais e deixar passar, o detector acusa; M4 do review 33.2).
    def sensivel?(conteudo)
      linhas_de_codigo(conteudo).any? do |linha|
        RECURSOS_SENSIVEIS.any? { |recurso| cita_recurso?(linha, recurso) }
      end
    end

    # --- (2) declaração: runtime, pela classe -----------------------------

    # `:coberto` ⟺ inclui `FrequenciaAuthorization` (assert recíproco T3 — a
    # declaração não pode mentir); `:dispensado` ⟺ tem `cascata_justificativa`
    # não vazia (M3, lida em runtime). Qualquer outro estado (nil/inválido) NÃO
    # é uma declaração válida.
    def declarado?(klass)
      return false if klass.nil?
      # Uma classe retida pelo critério de CAMINHO (M1) pode NÃO herdar a base
      # admin e, portanto, NÃO responder a `cascata_postura` — nesse caso ela
      # simplesmente NÃO declarou (drift sinalizado pelo build), nunca um
      # `NoMethodError` no detector (bug_report_33_2, Bug 1).
      return false unless klass.respond_to?(:cascata_postura)

      case klass.cascata_postura
      when :coberto    then klass.include?(FrequenciaAuthorization)
      when :dispensado then klass.cascata_justificativa.present?
      else false
      end
    end

    # --- (3) detector puro (unit-testável com arquivos sintéticos) --------

    # Devolve os arquivos SENSÍVEIS que NÃO declaram postura — o drift que o
    # build deve reprovar (T1/T2).
    def detectores(arquivos)
      arquivos.select { |arquivo| sensivel?(arquivo.conteudo) && !declarado?(arquivo.klass) }
    end

    # --- (4) varredura real (recursiva) -----------------------------------

    # Varre `app/controllers/**/*_controller.rb` RECURSIVAMENTE (M1: nem o glob
    # top-level de um nível, nem `File.basename(...).camelize`) e resolve cada
    # arquivo à classe pela POSIÇÃO relativa do caminho — de modo que um
    # controller em SUBPASTA (`admin/<sub>/x_controller.rb`) ou um herdeiro da
    # base FORA de `admin/` seja resolvido e varrido. Mantém apenas subclasses de
    # `Admin::ApplicationController` — exclui, estruturalmente, a base abstrata
    # (não é subclasse de si mesma) e as bases `Presenca::*`/`Users::*` (não
    # herdam o guard). Um arquivo cujo símbolo não resolve é mantido (`klass`
    # nil) para que um controller novo ainda-não-carregado não escape.
    def arquivos_do_app(raiz: nil)
      raiz ||= Rails.root.join("app/controllers")
      base = Admin::ApplicationController
      prefixo_admin = File.join(raiz.to_s, "admin") + File::SEPARATOR

      caminhos_controller(raiz).filter_map do |caminho|
        klass = classe_do_controller(caminho, raiz)

        # Reter se: (a) não resolve (controller novo ainda não carregado); (b)
        # herda a base admin (ANCESTRALIDADE); ou (c) vive sob `admin/`
        # (critério por CAMINHO — M1 do review 33.2: pega um controller admin que
        # NÃO herde a base admin e, sem isso, escaparia). A base ABSTRATA é sempre
        # excluída (M2 do review 33.1: casa o conjunto pelo menu, não lê recurso).
        sob_admin = caminho.to_s.start_with?(prefixo_admin)
        herdou = klass.is_a?(Class) && klass < base
        next if klass == base
        next unless klass.nil? || herdou || sob_admin

        Arquivo.new(caminho: caminho, conteudo: File.read(caminho), klass: klass)
      end
    end

    # Caminhos de controllers sob `raiz`, RECURSIVO (inclui subpastas) — é o que
    # fecha o falso-verde apontado em M1.
    def caminhos_controller(raiz)
      Dir[File.join(raiz.to_s, "**", "*_controller.rb")].sort
    end

    # Resolve a classe pela POSIÇÃO relativa (não pelo basename): preserva o
    # namespace de subpastas. `admin/frequencia_controller.rb` →
    # `Admin::FrequenciaController`; `admin/sub/x_controller.rb` →
    # `Admin::Sub::XController`. Retorna `nil` quando não há constante carregável.
    def classe_do_controller(caminho, raiz)
      relativo = Pathname.new(caminho).relative_path_from(Pathname.new(raiz.to_s)).to_s
      relativo.sub(/\.rb\z/, "").camelize.safe_constantize
    rescue StandardError
      nil
    end

    private

    # Descarta apenas linhas de comentário INTEIRAS (começam com `#`). Comentário
    # no fim da linha de código permanece (sobre-inclusão fail-closed — M4).
    def linhas_de_codigo(conteudo)
      conteudo.each_line.reject { |linha| linha.strip.start_with?("#") }
    end

    # Fronteira de palavra: `TimeRecord` casa `TimeRecord.all`, mas NÃO o nome da
    # classe `TimeRecordsController` (não há fronteira entre `d` e `s`).
    def cita_recurso?(linha, recurso)
      linha.match?(/\b#{Regexp.escape(recurso)}\b/)
    end
  end
end
