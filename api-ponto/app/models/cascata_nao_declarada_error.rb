# Tarefa 33.1 (Sprint 33) — Camada 1 (runtime): erro levantado pelo guard
# `Admin::ApplicationController#verificar_postura_cascata` no modo
# `FREQUENCIA_CASCATA_ENFORCEMENT=raise` quando um controller `Admin::*` NÃO
# declara sua postura perante a cascata de autorização de frequência.
#
# Declarar postura é uma das duas opções:
#   - `:coberto`    → `include FrequenciaAuthorization` (o concern é o opt-in);
#   - `:dispensado` → `fora_da_cascata_justificativa("motivo")` na classe.
#
# Fail-closed: um controller novo que leia frequência e esqueça de declarar é
# barrado em runtime — não passa silenciosamente pelo `check_authorization` com
# um mero `authorize! :read, :all` (causa-raiz do Bug 🔴1 da Sprint 30).
class CascataNaoDeclaradaError < StandardError; end
