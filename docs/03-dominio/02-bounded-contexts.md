# Bounded Contexts — Frequência

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Delimitar os **contextos delimitados** (bounded contexts) do domínio, suas **fronteiras**, suas **autoridades** e os **padrões de integração** entre eles. Base para a arquitetura alvo (Fase 4) e para o ADR-0001 (integração Pessoas ↔ Frequência).

> **Contextos identificados:** **PESSOAS** (autoridade cadastral), **FREQUÊNCIA** (autoridade de ponto) e **ESTAÇÃO PONTO** (captura biométrica). O módulo `presenca` legado mistura várias responsabilidades que o DDD separará.

---

## Visão Geral (Context Map)

```
                ┌──────────────────────────────────────────────────┐
   SHARED/       │                     PESSOAS                      │
   ACL            │  Autoridade: cadastro de servidores              │
   ◀────────────  │  Matrícula, nome, lotação, vínculo, cargo        │
                └───────────────────────┬──────────────────────────┘
                                        │  (Customer/Supplier? → Frequência consome)
                                        ▼  API REST + Eventos (ADR-0001/0006)
                ┌──────────────────────────────────────────────────┐
                │                   FREQUÊNCIA *Ubiguitous*          │
                │  Autoridade: ponto eletrônico (núcleo do domínio)  │
                │  Batidas, regimes, cálculo, banco de horas,        │
                │  fechamento, gestão de registro                    │
                └───────────────────────┬──────────────────────────┘
                                        │  (Open Host Service — contratos EP-01..EP-12)
                                        ▼  API compatível (ADR-0003)
                ┌──────────────────────────────────────────────────┐
                │               ESTAÇÃO PONTO (conformed)           │
                │  Captura biométrica e envio de lotes de batidas   │
                └──────────────────────────────────────────────────┘
```

**Legenda do Context Map:**
- **PESSOAS → FREQUÊNCIA:** **Supplier/Customer** ou **Conformist** — Freqüência consome dados cadastrais (frequentador, lotação) da Pessoas pela API canônica; Pessoas é provedor.
- **FREQUÊNCIA → ESTAÇÃO PONTO:** **Open Host Service (OHS) + Published Language** — Frequência expõe contratos compatíveis (EP-01..12), a Estação Ponto é **Conformist** (não muda; adere ao contrato). ADR-0003.

---

## Contexto: PESSOAS (provedor)

- **Autoridade:** matrícula, nome, CPF, cargo, **vínculo**, **lotação atual** (`lotacaoEpoca`), gestores de órgão.
- **Entidades relevantes p/ Frequência:** `Vinculado`, `Vinculo`, `Orgao`, `Predio`, `User` (usuário).
- **O que pertence (se mantém no Pessoas):** cadastro, lotação, vínculo, gestor do órgão, prédios.
- **Integração:** API canônica `/api/v1/integracoes/` (ADR-0006, **proposto**) + eventos de mudança cadastral.
- **Evidência de dependência:** `RegistroFrequencia.lotacaoEpoca` (`@ManyToOne Orgao`); `Frequentador.cadastrador/vinculado`; `podeDesconsiderarFrequencia` usa `usuario.isGestorOrgao(...)`; `PreVinculadoServices` (tjpi) para intervenções.

> ⚠️ **NOTA (anticorrupção):** o legado acopla Frequência ao Pessoas via Hibernate (`@ManyToOne` direto a `Orgao`, `Vinculado`, `User`) e via módulo `tjpi` (intervenções). No alvo, **Frequência manterá apenas IDs/refs** e buscará detalhes pela API — ver `02-arquitetura/` (Fase 4).

---

## Contexto: FREQUÊNCIA (núcleo — coração do domínio)

- **Autoridade exclusiva:** batidas, regimes/jornadas, cálculo diário, banco de horas, fechamento mensal, relatório definitivo, gestão de registro, estações (cadastro), retificador, valores retroativos.
- **É o contexto "rich"**: todas as regras de negócio de ponto vivem aqui (ver `01-linguagem-ubiqua.md`, fluxos A–D).
- **Subdomínios internos (dentro do contexto):**
  | Subdomínio | Responsabilidade | Fluxo/Doc |
  |------------|------------------|-----------|
  | **Captura/Ingestão** | Receber lotes da estação, validar estação, persistir lote bruto, processar em job | Fluxo A |
  | **Regime/Jornada** | Modalidades, expedientes, períodos a cumprir, direitos/dias excepcionais | `02-regime-jornada.md`, `04-direitos-afastamentos.md` |
  | **Cálculo** | Transformar batidas em `CalculoDiario` (motor v2) | Fluxo B |
  | **Banco de horas/Fechamento** | Consolidação mensal, saldo, retificador | Fluxo C |
  | **Gestão de Registro** | Manual/errata, desconsiderar, autorizações | Fluxo D |

- **Entidades-raiz (agregados):** ver `03-agregados.md`.

---

## Contexto: ESTAÇÃO PONTO (captura)

- **Autoridade:** leitura biométrica, fila local de batidas offline, horário local, envio via HTTP.
- **Não tem regra de negócio de frequência** — apenas captura e transporta batidas com o timestamp da estação.
- **Integração:** consome os contratos EP-01..EP-12 expostos pela Frequência (Open Host Service). **Zero alterações no desktop** (ADR-0003).
- **Evidência:** `07-estacao-ponto/02-endpoints-consumidos.md`; fluxo A (EP-05 `SincronizarRegistrosPonto`).

---

## Fronteiras claras (o que NÃO pertence ao Frequência)

| Responsabilidade | Contexto correto | Justificativa |
|------------------|------------------|---------------|
| Cadastro/lotação/vínculo do servidor | PESSOAS | Autoridade cadastral (ADR-0001) |
| Autorização de usuário/gestor | PESSOAS (roles) | `GestorIndividualServices`, `usuario.isGestorOrgao` |
| Intervenções passivas (auditoria de RH) | PESSOAS/tjpi (serviço externo) | `PreVinculadoServices.novaIntervencaoPassiva` — hoje cross-module |
| Captura biométrica | ESTAÇÃO PONTO | hardware local |

---

## Anti-corruption Layers (ACL) necessárias (débito a resolver na Fase 4)

1. **ACL Pessoas→Frequência:** substituir `@ManyToOne` direto (Orgao, Vinculado, User, Predio) por **IDs locais** + busca via API canônica (ADR-0006) com cache de materialized view `presenca_frequentadorestacao` (view legada).
2. **ACL EstaçãoPonto→Frequência:** expor contratos compatíveis (EP-01..12) sem expor modelo interno de domínio — camada de **adapter/presentação** no Frequência (ADR-0003).
3. **ACL tjpi (intervenções):** extrair `novaintervencaoPassiva` para serviço de domínio no contexto certo (provável PESSOAS/RH), com evento de domínio.

---

## Regras de integração (resumo)

| Par | Padrão DDD | Mecanismo | ADR |
|-----|-----------|-----------|-----|
| Pessoas → Frequência | Supplier/Customer (Customer) | API REST canônica + eventos | ADR-0001, ADR-0006 (proposto) |
| Frequência → Pessoas (consulta gestor) | conformist | API de consulta | ADR-0006 |
| Frequência → EstaçãoPonto | Open Host Service | Contratos compatíveis EP-01..12 | ADR-0003 |

---
**Última atualização:** 2026-08-05
**Fase:** 3 — Mapeamento de Domínio (DDD)
