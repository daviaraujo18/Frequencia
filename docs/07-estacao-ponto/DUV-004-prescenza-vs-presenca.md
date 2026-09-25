# DUV-004 — Path `/prescenza/` (com "z") vs `/presenca/`

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-04) — ver `## Resolução`

## Dúvida

A documentação (`SPRINT-PLAN.md`, `PRD-POC-API-PONTO.md`, `documentacao-estacao-ponto.md`) mistura dois grafias para o mesmo namespace:
- `/presenca/...` (correto, usado na PoC `routes.rb`)
- `/prescenza/...` (com "z", aparece em alguns trechos, ex. fluxos da EstaçãoPonto)

Pode ser um **typo histórico** no código Java da EstaçãoPonto, ou um **path real** que o cliente desktop usa.

## Origem

- `07-estacao-ponto/03-validacao-compatibilidade-des.md:89`

## Por que importa

- Se a EstaçãoPonto realmente chama `/prescenza/...` (com "z"), o Adapter do Frequência precisa responder **nos dois paths** (alias), caso contrário a estação falha.
- Determina se precisamos de rota adicional ou não.

## Como Resolver

- [ ] Confirmar em `estacaoPonto/src/main/java/core/IntranetURLs.java` qual path é realmente usado.
- [ ] Verificar se a poC já responde em `/prescenza/` (não deveria, pois `routes.rb` só tem `/presenca/`).
- [ ] Se necessário, adicionar alias de rota no Frequência.

## Resolução

**Resolvida por busca exaustiva no código da EstaçãoPonto (2026-08-04).**

- Busca por `prescenza` (case-insensitive) em **todo** o diretório `estacaoPonto/` (Java, resources, etc.) → **0 ocorrências**. O path com "z" **NÃO existe** em nenhum lugar do código.
- Todos os paths reais usam **`/presenca/`**:
  - `core/IntranetURLs.java` — `BASE_URL + "/presenca/..."` (InicializarPonto, Frequentador, PontoDePresenca, IniciarPonto, ProblemaRegistro) — l.12-23.
  - `core/PrediosPermitidosService.java:17` — `"/presenca/PrediosPermitidos/"`.
  - `listeners/Operacao.java:51` — `engine.getLocation().contains("presenca/PontoDePresenca")`; `:100` — `"presenca/RecuperarCodigoAtivacao"`.
  - `listeners/ChangeUrlListener.java` — `presenca/IniciarPonto` (l.72).

**Conclusão:** `/prescenza/` (com "z") é **apenas um typo na documentação** (SPRINT-PLAN/PRD/documentação-estacao-ponto), **não** é um path real chamado pela EstaçãoPonto.

**Decisão para a migração:** o Adapter do Frequência precisa responder apenas em **`/presenca/`**. **NÃO é necessário** criar alias `/prescenza/`. Pode-se corrigir o typo na documentação (itens 2-5 do `SPRINT-PLAN.md` / `PRD-POC-API-PONTO.md` / `documentacao-estacao-ponto.md`) para evitar confusão futura.

**Referências:** `docs/07-estacao-ponto/03-validacao-compatibilidade-des.md:89`, ADR-0003.
