# Inventário do Sistema Legado (Intranet)

> **[⌂ Home](../README.md)**

## Propósito

Este diretório contém o mapeamento completo do sistema **Intranet (Java 6 + MySQL 5)**, com foco no módulo **Frequência**.

## Conteúdo

| # | Documento | Status | Descrição |
|---|-----------|--------|-----------|
| 01 | `01-estrutura-projetos.md` | ✅ Completo | Estrutura de diretórios e arquivos dos projetos (Intranet, EstaçãoPonto, Pessoas) |
| 02 | `02-regime-jornada.md` | ✅ Completo | Domínio Regime/Jornada/Horário (módulo presenca) |
| 03 | `03-calculo-diario.md` | ✅ Completo | Domínio Cálculo Diário de Frequência (motor v1/v2) |
| 04 | `04-direitos-afastamentos.md` | ✅ Completo | Domínio Direitos/Afastamentos/Férias/Dias Excepcionais |
| 05 | `05-banco-horas-fechamento.md` | ✅ Completo | Domínio Banco de Horas/Fechamento/Retificador/Relatório Final |
| 06 | `06-tabelas-banco.md` | ✅ Completo | Inventário consolidado de tabelas/entidades do módulo (19 tabelas + 1 view, FKs, heranças, observações de migração); schema físico reconciliado |
| 07 | `07-duvidas-domains.md` | ✅ Completo | Dúvidas (DUV-005+) extraídas dos 4 domínios |
| 08 | `08-coleta-schema.md` | ✅ Executado | Roteiro SQL read-only (`SHOW CREATE TABLE`) p/ extrair o schema físico |
| 09 | `09-schema-confirmado.md` | ✅ Completo | Schema físico real confirmado (22 tabelas) + reconciliação com os beans JPA (resolve DUV-006/007/008) |
| 99 | `00-indice-modulo-presenca.md` | ✅ Completo | Visão geral do módulo presenca (em `09-intranet/`) |

## Legenda

- ✅ Completo
- 🔄 Em andamento
- ❌ Pendente
- 🚫 Não se aplica

---
**Fase 1 — Inventário do módulo Frequência CONCLUÍDO (2026-08-05).** A PoC `api-ponto/` NÃO cobre os domínios 02-05 (cálculos, jornadas, direitos, banco de horas, fechamento) — ver `09-intranet/00-indice-modulo-presenca.md`. As dúvidas dos domínios (DUV-001..013) foram **resolvidas e realocadas**. ADR-0005 (ACEITO) definiu o destino da PoC. **Schema físico coletado do MySQL (`intranet`) e registrado em `09-schema-confirmado.md`** (22 tabelas `presenca_*`, FKs, índices, reconciliação com beans → resolve DUV-006/007/008). ◆ Pendências de validação: confirmar estrutura idêntica em produção e a view `presenca_frequentadorestacao` (não existe no banco local).
