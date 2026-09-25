# [Funcionalidade] - Spec de Migração

> **[⌂ Home](../../README.md)**

> **TIPO DE SPEC:** Esta é uma spec de **ENGENHARIA REVERSA / MIGRAÇÃO**. Ela documenta o **COMPORTAMENTO REAL do sistema legado** (Intranet), extraído do código-fonte, NÃO um comportamento desejado inventado.

## Problem Statement

[Descreva a funcionalidade do sistema legado em 2-3 frases. Para que serve? Qual o seu papel no fluxo de frequência?]

**EVIDÊNCIA (origem):** [Caminho completo dos arquivos de código-fonte consultados, ex: `/intranet/src/frequencia/...java`]

## Comportamento Observado no Legado (Substitui "Goals")

[Descreva o que o sistema legado faz, com referências ao código]

- [ ] [Comportamento 1 observado — ex: "Ao receber uma batida, o sistema valida se o servidor existe"] — EVIDÊNCIA: `FrequenciaService.java:42`
- [ ] [Comportamento 2 observado] — EVIDÊNCIA: `...`

---

## Fora de Escopo

O que NÃO será migrado nesta funcionalidade (para prevenir escopo creep):

| Funcionalidade | Motivo |
|----------------|--------|
| [Funcionalidade X] | [Por que está fora do escopo, ex: "Já foi migrada em outra feature"] |
| [Funcionalidade Y] | [Por que] |

---

## Requisitos de Comportamento (formato WHEN/THEN/SHALL)

> Cada requisito deve ser **vinculado a uma evidência no código legado** e a um **resultado observado**, não imaginado.

| ID | Requisito (WHEN/THEN/SHALL) | EVIDÊNCIA (arquivo:linha) | Resultado observado | Status |
|----|-----------------------------|---------------------------|---------------------|--------|
| [FEAT]-01 | WHEN [evento] THEN sistema SHALL [comportamento] | `File.java:42` | [Valor/estado real observado] | Pending |
| [FEAT]-02 | WHEN [evento] THEN sistema SHALL [comportamento] | `File.java:88` | [Valor/estado real observado] | Pending |
| [FEAT]-03 | WHEN [edge case] THEN sistema SHALL [tratamento] | `File.java:120` | [Comportamento no edge case] | Pending |

## Casos de Borda (Edge Cases)

> Extraídos do código e do banco, não inventados.

- WHEN [condição limite] THEN sistema SHALL [comportamento no legado] — EVIDÊNCIA: `file:line`
- WHEN [erro] THEN sistema SHALL [tratamento de erro no legado] — EVIDÊNCIA: `file:line`

## Suposições e Perguntas em Aberto

| Suposição / decisão | Padrão escolhido | Racional | Confirmado? | EVIDÊNCIA |
|---------------------|------------------|----------|-------------|-----------|
| [Regra ambígua] | [O que faremos] | [Por quê] | [y/n] | `file:line` |

**Perguntas em aberto:** [Lista ou "nenhuma — todas resolvidas"]

---

## Critérios de Equivalência (para o Verifier)

> A validação da migração consistirá em provar que o **novo sistema** produz os mesmos resultados que o **legado** para as mesmas entradas.

| Requisito | Legado produz | Novo sistema DEVE produzir | Teste de caracterização (arquivo) |
|-----------|---------------|---------------------------|-----------------------------------|
| [FEAT]-01 | [Resultado do legado] | [Mesmo resultado] | `spec/frequencia/..._spec.rb` |
| [FEAT]-02 | [Resultado do legado] | [Mesmo resultado] | `spec/frequencia/..._spec.rb` |

---

## Critérios de Sucesso da Migração

- [ ] Todo requisito de comportamento tem uma evidência no código legado.
- [ ] Todo requisito tem um teste de equivalência (novo produz = legado produz).
- [ ] O Verifier confirmou PASS em `validacao-migracao.md`.

---
**Última atualização:** [YYYY-MM-DD]
