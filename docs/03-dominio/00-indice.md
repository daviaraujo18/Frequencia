# Mapeamento de Domínio — Frequência

> **[⌂ Home](../README.md)**

## Propósito

Este diretório contém a modelagem do domínio de **Frequência**, seguindo os princípios de Domain-Driven Design (DDD).

## Conteúdo

| # | Documento | Status | Descrição |
|---|-----------|--------|-----------|
| 01 | `01-linguagem-ubiqua.md` | ✅ Completo | Glossário do domínio |
| 02 | `02-bounded-contexts.md` | ✅ Completo | Contextos delimitados |
| 03 | `03-agregados.md` | ✅ Completo | Agregados e raízes |
| 04 | `04-entidades-value-objects.md` | ✅ Completo | Entidades e objetos de valor |
| 05 | `05-eventos-dominio.md` | ✅ Completo | Eventos do domínio |
| 06 | `06-servicos-dominio.md` | ✅ Completo | Serviços de domínio |
| 07 | `07-casos-uso.md` | ✅ Completo | Casos de uso priorizados |

## Bounded Contexts (Propostos)

```
┌──────────────────────────────────────────────────┐
│                  PESSOAS                          │
│  Autoridade: dados cadastrais dos servidores      │
│  Matrícula, nome, e-mail, lotação, cargo          │
└──────────────────┬───────────────────────────────┘
                   │ API REST + Eventos
                   ▼
┌──────────────────────────────────────────────────┐
│                FREQUÊNCIA                         │
│  Autoridade: regras de ponto eletrônico           │
│  Batidas, jornadas, escalas, banco de horas       │
└──────────────────┬───────────────────────────────┘
                   │ API (interface compatível)
                   ▼
┌──────────────────────────────────────────────────┐
│              ESTAÇÃO PONTO                        │
│  Captura biométrica e envio de batidas            │
└──────────────────────────────────────────────────┘
```

---
**Fase 3 (DDD) CONCLUÍDA (2026-08-05).** Todos os documentos do mapa de domínio foram preenchidos a partir dos fluxos da Fase 2 (A–D). Contextos: PESSOAS (provedor), FREQUÊNCIA (núcleo), ESTAÇÃO PONTO (Open Host Service). Ver `09-intranet/fluxos/` para a base de evidência.
