# DUV-003 — Endpoint `PrediosPermitidos` (EP-07)

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-04) — ver `## Resolução`

## Dúvida

A **PoC `api-ponto/` não implementa** o endpoint `GET /presenca/PrediosPermitidos/` (EP-07), que na Intranet legada retorna a lista de prédios autorizados para a estação (formato `"<id1>;<id2>;..."` separado por `;`).

A documentação da EstaçãoPonto (`documentacao-estacao-ponto.md`) indica que existe um `PrediosPermitidosService` no cliente desktop, ou seja, a **EstaçãoPonto aparentemente chama esse endpoint**.

A questão é: **a EstaçãoPonto ainda chama `PrediosPermitidos` hoje, ou é funcionalidade obsoleta?** Se chamar, o Frequência precisa implementar esse endpoint para compatibilidade completa.

## Origem

- `07-estacao-ponto/02-endpoints-consumidos.md:115`

## Por que importa

- O PRD colocou `PrediosPermitidos` como **fora de escopo** da PoC.
- Mas se a EstaçãoPonto ainda o consome, o Adapter (ADR-0003) do Frequência precisará implementá-lo, senão a estação pode falhar ao inicializar ou ao bater ponto.

## Hipóteses

1. A EstaçãoPonto chama `PrediosPermitidos` na inicialização (via `PrediosPermitidosService`) — precisamos replicar.
2. A EstaçãoPonto trata a ausência/erro desse endpoint de forma degradada (não é bloqueante).
3. É funcionalidade legada não mais utilizada pela versão atual do cliente.

## Como Resolver

- [ ] Verificar no código `estacaoPonto/src/main/java/core/PrediosPermitidosService.java` se e como o endpoint é chamado.
- [ ] Confirmar o comportamento em caso de falha/ausência.
- [ ] Decidir se a PoC/Frequência deve implementar EP-07.

## Resolução

**Resolvida por inspeção do código da EstaçãoPonto (2026-08-04).**

**1) A EstaçãoPonto AINDA chama `PrediosPermitidos`:**
- `core/PrediosPermitidosService.java:17` — `GET {base}/presenca/PrediosPermitidos/?codAtivacao=<codAtivacao>` (l.29,39-40); retorna o corpo como `String`.
- `listeners/Operacao.java:54-73` — enum `RECUPERAR_PREDIOS_PERMITIDOS("prediosPermitidos")` executa o service e seta `MainController.INSTANCE.prediosIds = prediosPermitidosIDs`.
- **Quando:** disparado no fluxo de inicialização, **logo após `downloadFrequentadores`** (`Operacao.java:39`), que ocorre quando a página HTML do intranet injeta a operação `prediosPermitidos` no WebEngine da estação.

**2) Como o resultado é usado (não é bloqueante):**
- `core/leitura/VerificacaoDigitalService.java:47-68`:
  - Se o prédio de trabalho do frequentador (`localTrabalho`) pertence a `prediosIds.split(";")` → `EventoLeitura.DIGITAL_RECONHECIDA` (batida normal).
  - Se **não** pertence → `EventoLeitura.DIGITAL_RECONHECIDA_RESSALVA_PREDIO` (digital reconhecida **com ressalva de prédio** — a batida é aceita com ressalva, **não bloqueada**).

**3) Comportamento em caso de falha/ausência do endpoint:**
- `PrediosPermitidosService.java:52-56` — em exceção, faz `LogAplicacao.e` e **retorna `""` (string vazia)**.
- Com `prediosIds = ""`, `"".split(";")` gera array `[""]`; `localTrabalho.equals("")` é falso → cai no `!definido` → `DIGITAL_RECONHECIDA_RESSALVA_PREDIO`.
- **Ou seja: a falha/ausência degrada para "ressalva de prédio", não bloqueia a batida.**

**4) Risco adicional mapeado (nota de migração, não da DUV):**
- `MainController.java:65` — `public String prediosIds;` **sem valor inicial** (`null`).
- Se a verificação digital ocorrer antes de `RECUPERAR_PREDIOS_PERMITIDOS` rodar, `VerificacaoDigitalService.java:50` (`prediosIds.toString()`) lançaria `NullPointerException`. Hipótese: na prática o fluxo dispara a operação antes da verificação; validar no Adapter.

**5) Decisão para a migração:**
- Para **compatibilidade completa** do Adapter, o Frequência deve implementar **EP-07** `GET /presenca/PrediosPermitidos/?codAtivacao=` retornando a lista de prédios da estação no formato **`"id1;id2;..."`** (separado por `;`).
- Porém, a ausência temporária **não bloqueia** a batida (degrade para ressalva de prédio) → pode ser implementado como dívida/feature de curto prazo, não impedimento crítico.

**Referências:** `docs/07-estacao-ponto/02-endpoints-consumidos.md:115`, ADR-0003.
