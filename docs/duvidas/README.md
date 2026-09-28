# Dúvidas — Registro e Rastreamento

> **[⌂ Home](../README.md)**

## Propósito

Diretório de **rastreamento/índice** das dúvidas (🤔 DÚVIDA) identificadas durante a migração do módulo de Frequência. Cada dúvida tem um identificador único (DUV-NNN) e referência cruzada ao documento de origem.

> **Regra:** Toda vez que uma análise deparar com uma dúvida, registra-se aqui no README. Quando resolvida, marca-se `STATUS: RESOLVIDA` e **move-se o arquivo para a pasta temática correspondente** (conforme o domínio), mantendo o rastreamento neste índice. Este diretório guarda **somente este README** — os arquivos vivem nas pastas temáticas.

## Índice de Dúvidas (todas resolvidas ✅)

> **Os arquivos `.md` de cada DUV foram realocados para as pastas temáticas de destino** (coluna "Local atual"). Consulte o arquivo para ver a seção `## Resolução`.

| ID | Dúvida | Origem | Status | Local atual |
|----|--------|--------|--------|-------------|
| DUV-001 | Endpoint `/utils/find` do Pessoas é uma busca genérica de qualquer model — falha de segurança? | `08-pessoas/01-analise-inicial.md:28` | ✅ Resolvida | `08-pessoas/DUV-001-utils-find-seguranca.md` |
| DUV-002 | Contratos dos endpoints EP-11 (`Frequentador`) e EP-12 (`ProblemaRegistro`) | `07-estacao-ponto/02-endpoints-consumidos.md:114` | ✅ Resolvida | `07-estacao-ponto/DUV-002-contratos-ep11-ep12.md` |
| DUV-003 | A PoC não implementa EP-07 (`PrediosPermitidos`) — a EstaçãoPonto ainda o chama? | `07-estacao-ponto/02-endpoints-consumidos.md:115` | ✅ Resolvida | `07-estacao-ponto/DUV-003-predios-permitidos.md` |
| DUV-004 | Path `/prescenza/` vs `/presenca/` — typo histórico? | `07-estacao-ponto/03-validacao-compatibilidade-des.md:89` | ✅ Resolvida | `07-estacao-ponto/DUV-004-prescenza-vs-presenca.md` |
| DUV-005 | Motor de cálculo duplicado v1×v2 — qual é o oficial? | `01-inventario/03-calculo-diario.md` (D3) | ✅ Resolvida | `09-intranet/DUV-005-motor-calculo-v1-v2.md` |
| DUV-006 | Campo `segsAcumulavelMensal` inexistente no bean — método morto | `01-inventario/05-banco-horas-fechamento.md` (DIVERG-001) | ✅ Resolvida | `09-intranet/DUV-006-campo-segsacumulavelmensal.md` |
| DUV-007 | Campo `calculoDiario_id` inexistente em `RetificadorDeBancoHoras` — método morto | `01-inventario/05-banco-horas-fechamento.md` (DIVERG-002) | ✅ Resolvida | `09-intranet/DUV-007-campo-calculodiario-id.md` |
| DUV-008 | Campo `orgao` (comentado) + `mes`/`ano` int/String em `RelatorioFrequenciaFinal` | `01-inventario/05-banco-horas-fechamento.md` (DIVERG-003) | ✅ Resolvida | `09-intranet/DUV-008-campo-orgao-relatoriofinal.md` |
| DUV-009 | `DebitoRemanescenteNegociado` código morto (referencia módulo aproc) | `01-inventario/05-banco-horas-fechamento.md` (DIVERG-004) | ✅ Resolvida | `09-intranet/DUV-009-debito-remanescente-morto.md` |
| DUV-010 | `finalizado` do RegistroMensalFrequencia nunca setado true — lock de mês | `01-inventario/05-banco-horas-fechamento.md` (AMBIG-001) | ✅ Resolvida | `09-intranet/DUV-010-finalizado-nunca-setado.md` |
| DUV-011 | Bug `cont=+valor.getNumeroHora()` (deveria ser `+=`) | `01-inventario/05-banco-horas-fechamento.md` (BUG-001) | ✅ Resolvida | `09-intranet/DUV-011-bug-cont-valor-retroativo.md` |
| DUV-012 | Cortes temporais do cálculo (01/12/2018, 01/05/2017, GCET, 26/10/2022) | `01-inventario/03-calculo-diario.md` (seção 3) | ✅ Resolvida | `09-intranet/DUV-012-cortes-temporais-calculo.md` |
| DUV-013 | Faltas compensáveis/ano 10→12 (corte 26/10/2022) + bug `Calendar.MONDAY` | `01-inventario/03-calculo-diario.md` (D9/D8) | ✅ Resolvida | `09-intranet/DUV-013-faltas-compensaveis.md` |

## Estado Geral

> **2026-08-05:** **todas as DUV-001..013 estão RESOLVIDAS.** A DUV-001 foi resolvida por inspeção de segurança do Pessoas; a DUV-002/003/004 por inspeção da EstaçãoPonto/PoC; e as DUV-005..013 por inspeção exaustiva do código do módulo `presenca` da Intranet (motor de cálculo, esquema e fechamento). Cada arquivo, na pasta temática, contém a seção `## Resolução` com a evidência (arquivo:linha).

## Mapeamento de pastas temáticas

| Domínio | Pasta |
|---------|-------|
| Pessoas | `08-pessoas/` |
| EstaçãoPonto | `07-estacao-ponto/` |
| Intranet — módulo presenca | `09-intranet/` |

> **Nota:** Dúvidas de domínio consolidadas também em `01-inventario/07-duvidas-domains.md` (com critério de seleção para promoção a DUV).

---
**Última atualização:** 2026-08-05
