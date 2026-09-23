# Pessoas — Índice

> **[⌂ Home](../README.md)**

## Propósito

Documentação do sistema **Pessoas** (`pessoas2/`) no contexto da migração: como o Frequência se integra com ele como fonte de dados cadastrais (conforme ADR-0001).

## Conteúdo

| # | Documento | Status | Descrição |
|---|-----------|--------|-----------|
| 01 | `01-analise-inicial.md` | ✅ | Análise técnico-arquitetural do Pessoas como fonte de dados para o Frequência |
| 02 | `DUV-001-utils-find-seguranca.md` | ✅ Resolvida | Segurança do endpoint `/utils/find` no Pessoas (realocada de `duvidas/`) |
| 03 | `02-sticapi-client.md` | ❌ | Mapeamento da gem `sticapi_client` (cliente do Pessoas para a Intranet legada) |
| 04 | `03-api-proposta-frequencia.md` | ❌ | Proposta de namespace `/api/v1/integracoes/` no Pessoas para Frequência |

## Resumo de Alto Nível

- **Stack:** Ruby on Rails (versão não confirmada, presumed 7+), PostgreSQL, Devise, Sidekiq, ActiveStorage, paper_trail, acts_as_tenant, Cucumber + RSpec
- **Madurez:** muito alta — 270+ controllers, integração eSocial completa
- **Pessoa model:** contém `cpf`, `nome`, `nascimento`, `foto`, `foto_biometria` (FOTO, não fingerprint)
- **Vinculo model:** contém `matricula`, `cargo`, `lotacao`, `vinculo_estado`, `afastamentos`
- **API atual:** endpoints em `/utils/*` e `/pessoas/:id/...` voltados para UI — não há namespace canônico para integrações externas
- **SticapiClient::Intranet:** gem interna que o Pessoas usa para chamar a Intranet legada — dívida quando a Intranet for desligada

## Pontos Críticos (ver `01-analise-inicial.md`)

1. **`Pessoa.da_ativa` scope** — substitui parcialmente `DynFrequentadoresEstacao`, mas pode não cobrir TODOS os tipos de vínculo (verificar flag `vinculo_da_ativa: true` em tipos relevantes)
2. **`/utils/find` é vulnerabilidade de segurança** — busca genérica por qualquer model — não usar para integração Frequência
3. **`/utils/pessoa_info` depende da Intranet legada** via `SticapiClient::Intranet` — não usar para Frequência
4. **`foto_biometria` é FOTO biométrica** (não impressão digital/fingerprint) — útil para display, mas NÃO é o `digitais_hash` da Estação
5. **Need de criar namespace `/api/v1/integracoes/`** no Pessoas (não no Frequência) — será proposto como ADR-0006 futuro

## Decisão Recomendada para Fase 4

Criar ADR-0006 "API Pessoas → Frequência: Exposição e Contrato" definindo:
- Endpoints canônicos no Pessoas para Frequência (e outros sistemas)
- Auth service-to-service (token/JWT)
- Eventos de mudança cadastral (lotação, cargo, situação)

## Legenda

- ✅ Completo / 🔄 Em andamento / ❌ Pendente / 🚫 Não se aplica

---
**Última atualização:** 2026-08-04
