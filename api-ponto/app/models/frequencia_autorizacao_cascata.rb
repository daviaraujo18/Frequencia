# Tarefa 29.7 (Sprint 29) — rollout da cascata de autorização de frequência.
#
# A cascata em si vive na `AutorizacaoFrequencia` (29.4, PORO de consulta) e no
# `FrequentadoresVisiveis` (29.6, irmão SQL). Esta classe NÃO decide acesso:
# ela só responde "o rollout está ligado?" e emite o log do modo shadow. É o
# ponto único de leitura da feature flag `FREQUENCIA_AUTORIZACAO_CASCATA`
# (Decisão D3 do CTO, 2026-10-02), consumido pela `Ability` (29.7) e pelos
# controllers de frequência, para que a chave da flag e o formato do log
# tenham UMA definição só.
#
# ── Decisão D3 (CTO) — três estados, default OFF ────────────────────────────
# A variável de ambiente `FREQUENCIA_AUTORIZACAO_CASCATA` aceita:
#   - ausente/vazia/qualquer outro valor → `:off`    (comportamento ATUAL — a
#     suíte existente e as telas NÃO mudam; é o default em produção);
#   - "shadow"/"sombra"                 → `:shadow` (só LOGA as negações que a
#     cascata faria, SEM negar — roda 1 ciclo antes de ligar de verdade);
#   - "on"/"1"/"true"/"ligada"          → `:on`     (a cascata passa a valer:
#     a `Ability` restringe a leitura de frequência e os index filtram por
#     `frequentadores_visiveis`).
#
# O valor é lido a cada chamada (não memoizado no carregamento): assim a flag
# pode ser trocada em runtime e os testes podem exercitar os três estados sem
# reiniciar o processo.
class FrequenciaAutorizacaoCascata
  VARIAVEL = "FREQUENCIA_AUTORIZACAO_CASCATA".freeze

  # Valores textuais aceitos para ligar a cascata de verdade.
  VALORES_LIGADA = %w[on 1 true ligada].freeze
  # Valores textuais aceitos para o modo shadow (só log).
  VALORES_SHADOW = %w[shadow sombra].freeze

  class << self
    # `:off` | `:shadow` | `:on` — ver bloco de decisão no topo.
    def modo
      case ENV[VARIAVEL].to_s.strip.downcase
      when *VALORES_LIGADA then :on
      when *VALORES_SHADOW then :shadow
      else :off
      end
    end

    # Cascata valendo de verdade (restringe acesso/listagem).
    def ligada?
      modo == :on
    end

    # Cascata apenas observando (loga negações sem negar).
    def shadow?
      modo == :shadow
    end

    # Modo shadow: registra a decisão que a cascata TOMARIA, por alvo — sem
    # negar nada. Formato pedido pelo critério da 29.7:
    # `usuario, alvo, motivo, decisão`. O `motivo` é o do PORO (`:negado` ou um
    # dos passos 1–5), e a `decisao` é o veredicto projetado (`:negaria` /
    # `:permitiria`).
    #
    # Nível `info` (não `warn`): é observação de rollout, não uma negação
    # efetiva — a negação real (quando a flag estiver `:on`) virá do
    # `CanCan::AccessDenied`/filtro, não daqui.
    def log_shadow(usuario:, alvo:, motivo:, decisao:)
      return unless shadow?

      Rails.logger.info(
        evento: "frequencia_autorizacao_cascata.shadow",
        usuario_id: usuario&.id,
        alvo_tipo: alvo.class.name,
        alvo_id: alvo&.id,
        alvo_cpf: normalizar_cpf(alvo&.cpf),
        motivo: motivo,
        decisao: decisao
      )
    end

    private

    # CPF sem máscara — mesmo formato dos demais pontos de leitura de CPF do
    # domínio (`AutorizacaoFrequencia`/`User`).
    def normalizar_cpf(valor)
      valor.to_s.gsub(/\D/, "").presence
    end
  end
end
