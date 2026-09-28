# Dúvidas dos Domínios — Fase 1 (módulo presenca)

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

> **Estado (2026-08-05):** todas as DUV-005..013 foram **RESOLVIDAS** por inspeção de código e seus arquivos movidos para `09-intranet/`. Ver a seção Resolução de cada arquivo.

## Resumo por documento-fonte

| Domínio | Doc | Qtd itens | IDs no doc |
|---------|-----|-----------|------------|
| Regime/Jornada/Horário | `02-regime-jornada.md` | 10 (Q1..Q10) | Q1-Q10 |
| Cálculo Diário | `03-calculo-diario.md` | 14 (D1..D15, faltando 13/14) | D1-D12, D15 |
| Direitos/Afastamentos/Férias | `04-direitos-afastamentos.md` | 12 (D1..D12) | D1-D12 |
| Banco de Horas/Fechamento | `05-banco-horas-fechamento.md` | 9 | DIVERG-001..004, AMBIG-001..003, BUG-001, DEAD-CODE-001/002 |

## Dúvidas priorizadas → DUV (arquivos em `09-intranet/`)

| DUV | Dúvida (resumo) | Origem | Status |
|-----|-----------------|--------|--------|
| DUV-005 | Motor de cálculo duplicado v1×v2 — qual é o oficial? (prod. usa v2, UI/desconsiderar usa v1) | `03-calculo-diario.md` D3 | ✅ Resolvida |
| DUV-006 | Divergência `segsAcumulavelMensal` (campo inexistente no bean) — método morto em DAO | `05-banco-horas-fechamento.md` DIVERG-001 | ✅ Resolvida |
| DUV-007 | Divergência `calculoDiario_id` (campo inexistente) — método morto em DAO | DIVERG-002 | ✅ Resolvida |
| DUV-008 | Divergência `orgao` (campo comentado, DAO referencia) + mes String/int | DIVERG-003 | ✅ Resolvida |
| DUV-009 | `DebitoRemanescenteNegociado` código morto (referencia módulo aproc) | DIVERG-004/DEAD-CODE-001 | ✅ Resolvida |
| DUV-010 | `finalizado` do RegistroMensal nunca setado true — lock de mês nunca efetivado | AMBIG-001 | ✅ Resolvida |
| DUV-011 | Bug `cont=+valor.getNumeroHora()` (deveria ser `+=`) — soma corrompida | BUG-001 | ✅ Resolvida |
| DUV-012 | Corte temporal 01/12/2018 (Old vs New) + GCET + limites — regras de histórico a confirmar | `03-calculo-diario.md` seção 3 | ✅ Resolvida |
| DUV-013 | Corte 26/10/2022 faltas compensáveis (10→12) + `Calendar.MONDAY` bug | `03-calculo-diario.md` D9 | ✅ Resolvida |

## Critério de seleção para DUV individual

Nem toda dúvida virou DUV próprio (muitas são triviais/validação de código). Foram promovidas a DUV as que impactam **decisão de migração, resultado financeiro/cálculo, ou reconciliação de esquema BD×classes**.

## Dúvidas não promovidas (mantidas apenas no doc-fonte)
- Q1/Q2/Q3/Q5/Q7/Q8/Q9 (regime) — comportamento de UI/modalidades legadas, registrar como nota de migração.
- D1/D5/D6/D7/D8/D10/D11/D15 (cálculo) — regras temporais e code smells já documentados no doc-fonte.
- D1/D3/D4/D6/D7/D9/D12 (direitos) etc.

---
**Última atualização:** 2026-08-04
