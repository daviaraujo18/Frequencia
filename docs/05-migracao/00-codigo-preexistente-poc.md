# Código Preexistente da PoC — `api-ponto/` (Frequência)

> **[⌂ Home](../README.md)**

## Propósito

Registrar a descoberta crítica de que **a PoC do sistema Frequência já está implementada em código** (Ruby on Rails 8) e está preservada no histórico git da pasta `frequencia/`, embora tenha sido removida do diretório de trabalho.

> **DECISÃO:** Este documento atualiza o entendimento do estado do projeto. A PoC não é uma hipótese — é código concreto. Isso impacta fortemente as Fases 4, 6 e 7 do framework.

## Descoberta

**Data:** 2026-08-04
**Local:** `/home/wilker/Documentos/TJPI/Integracao/frequencia/.git`
**Comando de verificação:** `cd frequencia && git status` → 3316 arquivos listados como `deleted:`

### Evidências

- `git ls-tree -r HEAD --name-only | grep "api-ponto/" | wc -l` → **3316 arquivos**
- `git show HEAD:api-ponto/config/routes.rb` → retorna `Rails.application.routes.draw do ... end` com **11 endpoints namespace `presenca`**
- `git show HEAD:api-ponto/app/controllers/presenca/validar_frequentador_controller.rb` → controller Ruby **100% implementado**, com `CryptoDes.decrypt`, `User.ativos.find_by`, `bcrypt authenticate`, e mensagens `USUARIO_SENHA_INVALIDOS` (encontra-se documentado em `PRD-POC-API-PONTO.md` §8.1)
- Commit do repo: `61b70cf feat: Add Rails API Ponto, EstacaoPonto documentation, and sprint plan`
- Documentação em `frequencia/SPRINT-PLAN.md` confirma **Sprints 1 a 5 concluídas; Sprint 6 parcial**
- Documentação em `frequencia/PRD-POC-API-PONTO.md`informa que foram feitos 25 testes automatizados, 0 falhas

### Síntese da Stack da PoC

| Camada | Tecnologia | Evidência |
|--------|-----------|-----------|
| Framework | Ruby on Rails 8 | `Gemfile` (git) |
| Banco | PostgreSQL | `config/database.yml` (git) |
| Senhas | `has_secure_password` (bcrypt) | controllers + models |
| Cripto legacy | OpenSSL DES/CBC/PKCS5 com chave `"cryp:gpf"` | `app/services/crypto_des.rb` (git) |
| Testes | `bin/rails test` (default Minitest) | 25 testes, 0 falhas (per SPRINT-PLAN §6) |
| Containers | Dockerfile + Kamal (deploy.yml) | `.kamal/` e `Dockerfile` no git |

### Endpoints Implementados (confirmado via `routes.rb`)

| Método | Endpoint | Controller | PRD ref |
|--------|----------|-----------|---------|
| GET | `/presenca/ValidarFrequentador` | `validar_frequentador` | §8.1 |
| GET | `/presenca/DynFrequentadoresEstacao` | `dyn_frequentadores_estacao` | §8.2 |
| GET | `/presenca/DynHashFrequentadoresEstacao` | `dyn_hash_frequentadores_estacao` | §8.3 |
| GET | `/presenca/CarregaRelogioAtual` | `carrega_relogio_atual` | §8.4 |
| POST | `/presenca/ajax/SincronizarRegistrosPonto` | `sincronizar_registros_ponto` | §8.5 |
| GET | `/presenca/InicializarPonto` | `inicializar_ponto` | §8.6 |
| GET | `/presenca/IniciarPonto` | `iniciar_ponto` | — |
| GET | `/presenca/PontoDePresenca` | `ponto_de_presenca` | — |
| GET | `/presenca/Frequentador` | `frequentador` | — |
| GET | `/presenca/AdicioneEstacao` | `adicione_estacao` | heartbeat |
| GET | `/presenca/ProblemaRegistro` | `problema_registro` | — |

### Arquitetura Ruby da PoC (estrutura confirmada no git)

```
api-ponto/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   └── presenca/
│   │       ├── adicione_estacao_controller.rb
│   │       ├── carrega_relogio_atual_controller.rb
│   │       ├── dyn_frequentadores_estacao_controller.rb
│   │       ├── dyn_hash_frequentadores_estacao_controller.rb
│   │       ├── frequentador_controller.rb
│   │       ├── inicializar_ponto_controller.rb
│   │       ├── iniciar_ponto_controller.rb
│   │       ├── ponto_de_presenca_controller.rb
│   │       ├── problema_registro_controller.rb
│   │       ├── sincronizar_registros_ponto_controller.rb
│   │       └── validar_frequentador_controller.rb
│   ├── jobs/application_job.rb
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── time_record.rb
│   │   └── user.rb
│   ├── services/
│   │   ├── crypto_des.rb                # DES/CBC/PKCS5 + UrlBase64 compat estação
│   │   └── frequentadores_serializer.rb  # Serialização + MD5 hash
│   └── views/presenca/ponto_de_presenca/index.html.erb
├── config/
│   ├── routes.rb                        # namespace :presenca
│   ├── database.yml
│   ├── deploy.yml (Kamal)
│   └── environments/{development,production,test}.rb
├── db/
│   ├── cache_schema.rb
│   └── (migrations)
└── test/                                # 25 testes Minitest
```

## Impacto para a Migração

### O que muda no framework

1. **Fase 4 (Arquitetura Alvo)** — parcialmente **já existe**. A arquitetura Rails 8 API com namespace `presenca` está implementada. Precisamos avaliar se atende ao longo prazo ou se será a base do sistema Frequência definitivo.

2. **Fase 6 (Plano de Compatibilidade EstaçãoPonto)** — o **Adapter já está construído**. Os 6 endpoints documentados em `PRD-POC-API-PONTO.md` §8 estão implementados exatamente no padrão legado (URLs `/presenca/...`, mensagem string pura, formato serializado com apóstrofo). Isso significa que **estamos muito mais adiantados** para o ADR-0003.

3. **Fase 7 (Plano de Implementação)** — a `SPRINT-PLAN.md` já está organizada em 6 sprints (48 tasks), com Sprints 1 a 5 marcadas concluídas.

4. **ADR-0003 (Compatibilidade EstaçãoPonto)** — a alternativa B (Camada de Compatibilidade) está **validada empiricamente**, pois a PoC substituiu a Intranet com sucesso via curl.

### ADRs potencialmente impactados

- **ADR-0001** (Integração Pessoas-Frequência): A PoC usa model `User` local com `digitais_hash`, sem consumir API do Pessoas. Para produtização, será necessário substituir o model local por integração com Pessoas conforme ADR-0001.
- **ADR-0002** (Strangler Fig): A PoC é exatamente o "novo sistema" do estágio 1 (sombra). Os endpoints batem 1:1 com o que a Intranet oferece.
- **ADR-0003** (Adapter EstaçãoPonto): A PoC confirma a viabilidade da camada de compatibilidade. O Adapter é o próprio `app/controllers/presenca/`.
- **ADR-0004** (Spec-Driven): A PoC não seguiu o ciclo Spec-Driven (foi feita antes). Para evoluir para produção, novas features devem seguir o ciclo.

## Riscos

- ⚠️ **PoC != Produção:** o PRD lista explicitamente como fora de escopo: relatórios, banco de horas, jornadas, escalas, férias, afastamentos, prédios permitidos, código de ativação dinâmico, cache de fotos, auto-update, etc. **Tudo o que existe na Intranet além de "registrar batida" ainda precisa ser migrado.**
- ⚠️ **Modelagem cadastral divergente:** A PoC tem `User` local (matrícula, senha, digital, status). O ADR-0001 determina que `Pessoas` é a autoridade cadastral. A migração para produção exigirá desacoplar o `User` da PoC, deixando-o apenas como **cache local** de dados do Pessoas.
- ⚠️ **Auth por `codAtivacao` fixo** (`poc-ativacao-001`) — inviável em produção. Precisa ser substituído por autenticação real de estação.
- ⚠️ **DES hardcoded `"cryp:gpf"`** — security debt mantido por compatibilidade. Revisar na produtização (ver ADR futuro).
- ⚠️ **Cobertura de testes da PoC** — 25 testes cobrem o "happy path" dos endpoints. Falta testes de contrato com a EstaçãoPonto real (Sprint 6 pendente).
- ⚠️ **Estado atual do working tree:** o `git status` mostra os arquivos como `deleted`. Isso sugere que alguém removeu o código da pasta. **NÃO devemos simplesmente `git restore` sem entender quanto dessa PoC ainda é apropriada reaproveitar.** Precisamos de uma decisão de_workspace_ explicitada (próxima sessão).

## Pendências

- [ ] **DECIDIR:** restaurar `api-ponto/` do git para o working tree ou mantê-lo apenas como referência documental?
- [ ] Auditar a PoC ponto-a-ponto contra o PRD: confirmar que está consistente e o que está divergente.
- [ ] Verificar compatibilidade DES-UrlBase64 Ruby ↔ Java (a `CryptoDes` da PoC vs `CryptoUtils.java` da estação).
- [ ] Identificar lacunas críticas para produtização (listar recursos da Intranet não cobertos pela PoC).
- [ ] Decidir: a PoC se torna a base do Frequência definitivo (incrementada) ou ela é só prova de conceito e teremos um novo repositório?

## Próximos Passos Sugeridos

1. **Resposta do usuário** sobre o destino da PoC: descartar / restaurar como base do Frequência / manter como referência arquitetural.
2. Tendo a resposta acima, atualizar o ADR-0005 (status) e seguir para Fase 1 detalhada (Inventário do módulo Intranet Frequência) com foco no que a PoC **não** cobre.

---
**Última atualização:** 2026-08-04
