# Estação Ponto — Índice

> **[⌂ Home](../README.md)**

## Propósito

Reúne toda a documentação sobre a aplicação desktop **EstaçãoPonto** (JavaFX + SDK Nitgen) que se comunica com a Intranet e, no futuro, com o sistema Frequência.

## Conteúdo

| # | Documento | Status | Descrição |
|---|-----------|--------|-----------|
| 01 | `01-resumo-arquitetura.md` | ✅ | Síntese da arquitetura (extraída da doc pré-existente) |
| 02 | `02-endpoints-consumidos.md` | ✅ | API que a EstaçãoPonto chama na Intranet (e que deverá ser mantida pelo Frequência) |
| 03 | `03-regras-negocio.md` | 🔄 | Regras de negócio da EstaçãoPonto (18 regras, parcialmente a registrar) |
| 04 | `04-dependencias-tecnicas.md` | ❌ | Dependências (Nitgen SDK, JNA, Bouncy Castle, etc.) |
| 05 | `05-problemas-seguranca.md` | ❌ | Vulnerabilidades e débitos técnicos críticos |
| 06 | `DUV-002-contratos-ep11-ep12.md` | ✅ Resolvida | Contrato dos endpoints EP-11 (`Frequentador`) e EP-12 (`ProblemaRegistro`) (realocada de `duvidas/`) |
| 07 | `DUV-003-predios-permitidos.md` | ✅ Resolvida | Se a EstaçãoPonto ainda chama EP-07 (`PrediosPermitidos`) (realocada de `duvidas/`) |
| 08 | `DUV-004-prescenza-vs-presenca.md` | ✅ Resolvida | Path `/prescenza/` vs `/presenca/` (realocada de `duvidas/`) |

## Fonte Documental Principal

**`/frequencia/documentacao-estacao-ponto.md`** — 1773 linhas, 19 etapas, engenharia reversa completa da EstaçãoPonto. Esse arquivo é a **fonte canônica** sobre o cliente desktop; os arquivos deste diretório são **sínteses** para consumo rápido do agente de migração, sem repetir o conteúdo integral.

## Legenda

- ✅ Completo
- 🔄 Em andamento
- ❌ Pendente
- 🚫 Não se aplica

---
**Próximo passo:** ler `01-resumo-arquitetura.md` antes de avançar para a Fase 1 detalhada da Intranet.
