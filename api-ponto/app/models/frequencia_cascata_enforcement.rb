# Tarefa 33.1 (Sprint 33) — Camada 1 (runtime): ponto ÚNICO de leitura da flag
# que controla o ENFORCEMENT da declaração de postura de cascata.
#
# É irmão de `FrequenciaAutorizacaoCascata` (29.7): aquele decide se a CASCATA
# vale (`FREQUENCIA_AUTORIZACAO_CASCATA`); este decide se o GUARD que exige
# DECLARAÇÃO de postura por controller (em `Admin::ApplicationController`)
# falha-closed (`raise`) ou apenas avisa (`log`). As duas flags são
# DESACOPLADAS de propósito (D2/R4 do plano da 33): o contrato de declaração não
# fica refém do estado da cascata nem das roles da 30.9b.
#
# A variável `FREQUENCIA_CASCATA_ENFORCEMENT` aceita (case/whitespace-insensitive):
#   - LIGAR    (raise/levantar/on/true/1/yes/enabled/ativo/strict) → `:raise`
#     (fail-closed: o guard levanta `CascataNaoDeclaradaError` quando um
#     controller admin não declara postura);
#   - OBSERVAR (log/warn/avisar/observar/shadow/off/false/0/no/disabled) → `:log`
#     (fail-open: só `Rails.logger.warn`, o guard NÃO levanta);
#   - ausente/vazia                      → default por ambiente (abaixo);
#   - NÃO reconhecido (ex.: "lg", "tru") → `:raise` + um `Rails.logger.warn`.
#     Um valor ambíguo NUNCA deve desligar o gate em silêncio (fail-closed):
#     era a armadilha de "on"/"true"/"1" caírem em `:log` (bug_report_33_1).
#
# Default: `:raise` em test/CI (gate duro — um controller novo sem postura
# QUEBRA a suíte); `:log` no 1º deploy de produção (apenas observa; após um
# ciclo sem WARN o dev flipa para `raise`).
#
# O valor é lido a cada chamada (não memoizado no carregamento): assim a flag
# pode ser trocada em runtime e os testes exercitam os dois modos sem reiniciar
# o processo — mesmo contrato de `FrequenciaAutorizacaoCascata`.
class FrequenciaCascataEnforcement
  VARIAVEL = "FREQUENCIA_CASCATA_ENFORCEMENT".freeze

  # Valores textuais que LIGAM o modo fail-closed (levantar).
  VALORES_RAISE = %w[raise levantar on true 1 yes enabled ativo strict].freeze

  # Valores textuais que mantêm o modo OBSERVAÇÃO (só WARN; não levanta).
  VALORES_LOG = %w[log warn avisar observar shadow off false 0 no disabled].freeze

  class << self
    # `:log` | `:raise` — ver bloco de decisão no topo.
    def modo
      valor = ENV[VARIAVEL].to_s.strip.downcase
      return padrao if valor.empty?
      return :raise if VALORES_RAISE.include?(valor)
      return :log if VALORES_LOG.include?(valor)

      # Valor NÃO reconhecido → fail-closed + aviso alto. Desligar o gate em
      # silêncio por um valor ambíguo ("on"/"true"/"1"/typo) é uma armadilha de
      # confiança falsa num guard de autorização (bug_report_33_1).
      Rails.logger.warn(
        "#{VARIAVEL}=#{valor.inspect} não reconhecido — assumindo fail-closed (`raise`). " \
        "Valores válidos: ligar=#{VALORES_RAISE.join('/')} | observar=#{VALORES_LOG.join('/')}"
      )
      :raise
    end

    # Fail-open: o guard só emite `Rails.logger.warn` (não levanta).
    def log?
      modo == :log
    end

    # Fail-closed: o guard levanta `CascataNaoDeclaradaError`.
    def raise?
      modo == :raise
    end

    private

    # Sem valor explícito na ENV: test/CI → `:raise` (gate duro); os demais
    # ambientes (1º deploy de produção, dev) → `:log` (só observa).
    def padrao
      Rails.env.test? || ci_ligado? ? :raise : :log
    end

    # `CI` só conta como LIGADO se for truthy ("1"/"true") — `CI=false`/`CI=0`
    # (comuns em CI que exporta a var sempre) NÃO devem virar `:raise`.
    def ci_ligado?
      %w[1 true].include?(ENV["CI"].to_s.strip.downcase)
    end
  end
end
