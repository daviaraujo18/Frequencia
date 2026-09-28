# Estrutura dos Projetos

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Mapeamento inicial da estrutura de diretórios de todos os sistemas envolvidos na migração.

## Intranet (Legado — Java 6 + MySQL 5)

**Diretório:** `/home/wilker/Documentos/TJPI/Integracao/intranet/`

### Estrutura de Alto Nível

```
intranet/
├── CHANGELOG
├── Dockerfile
├── README.docker.md
├── README.md
├── ant/                  # Scripts de build Ant
├── dev-notes.txt         # Notas de desenvolvimento
├── doc/                  # Documentação
├── docker-compose.yml
├── docs/
├── lib/                  # Bibliotecas/dependências
├── logs/
├── scripts/              # Scripts auxiliares
├── src/                  # Código-fonte Java
├── test/                 # Testes
├── tomcat/               # Configuração do Tomcat
└── web/                  # Recursos web (JSP, HTML, etc.)
```

**Status:** Pendente exploração profunda.
**Próximo passo:** Explorar `src/` para identificar pacotes e módulos, especialmente o módulo Frequência.

### EVIDÊNCIA
- Estrutura observada em 03/08/2026.
- `Dockerfile` e `docker-compose.yml` indicam que o sistema roda em container.
- `ant/` indica build via Apache Ant (compatível com Java 6).
- `tomcat/` sugere deploy em Apache Tomcat.

---

## Pessoas (Novo RH — Ruby on Rails)

**Diretório:** `/home/wilker/Documentos/TJPI/Integracao/pessoas2/`

### Estrutura de Alto Nível

```
pessoas2/
├── Gemfile / Gemfile.lock
├── Procfile / Procfile.dev
├── Rakefile
├── app/                  # Código-fonte Rails (models, controllers, etc.)
├── bin/
├── config/               # Configurações (database, routes, etc.)
├── config.ru
├── coverage/
├── db/                   # Migrations, schema
├── doc/ / docs/
├── features/             # Cucumber/Capybara tests
├── lib/
├── log/
├── node_modules/
├── public/
├── resources/
├── script/ / scripts/
├── spec/                 # RSpec tests
├── storage/
├── tmp/
└── vendor/
```

**Status:** Sistema ativo, não requer exploração aprofundada para esta migração.
**Observação:** O Frequência se integrará com este sistema via API REST + Eventos (ver ADR-0001).

---

## EstaçãoPonto (Desktop — Java)

**Diretório:** `/home/wilker/Documentos/TJPI/Integracao/estacaoPonto/`

### Estrutura de Alto Nível

```
estacaoPonto/
├── TestCrypto.class / TestCrypto.java  # Criptografia (evidência)
├── docker/
├── docs/
├── lib/
├── outros/
├── pom.xml              # Build Maven
├── readme.txt
├── run.sh               # Script de execução
├── src/                 # Código-fonte Java
└── target/              # Build output
```

**Status:** Pendente exploração profunda.
**⚠️ RISCO:** Presença de `TestCrypto.java/class` indica uso de criptografia na comunicação. Isso pode ser crítico para a camada de compatibilidade.
**Próximo passo:** Analisar `pom.xml` para dependências e explorar `src/` para o módulo de comunicação.

---

## Frequência (Novo Sistema — Especificação + PoC Rails 8)

**Diretório:** `/home/wilker/Documentos/TJPI/Integracao/frequencia/`

### Estrutura de Alto Nível (working tree observado em 2026-08-04)

```
frequencia/
├── PRD-POC-API-PONTO.md          # Documento de requisitos/API da PoC (652 linhas)
├── SPRINT-PLAN.md                # Planejamento de sprint (6 sprints, 48 tasks)
├── documentacao-estacao-ponto.md # Documentação da EstaçãoPonto (1773 linhas, 19 etapas)
└── opencode.json                 # Configuração OpenCode
```

### ⚠️ Atualização Importante (2026-08-04)

**Descoberta:** o working tree está incompleto. O git HEAD contém **3316 arquivos** do projeto Rails `api-ponto/` (a PoC mencionada no `SPRINT-PLAN.md`), mas todos aparecem como `deleted` no `git status`. Provavelmente foram removidos acidentalmente.

**EVIDÊNCIA:**
- `git -C frequencia ls-tree -r HEAD --name-only | grep "api-ponto/" | wc -l` → `3316`
- `git -C frequencia status | grep -c "^	deleted:"` → `3316`
- `git show HEAD:api-ponto/config/routes.rb` → retorna `Rails.application.routes.draw do ... end` com 11 endpoints em namespace `presenca`

**Implicação:** a PoC está **completamente implementada no git** e foi validada (Sprints 1–5 do SPRINT-PLAN marcadas concluídas, 25 testes Minitest, 0 falhas). Sprint 6 (integração com Estação JavaFX real) parcialmente concluída.

**Ver:** `docs/05-migracao/00-codigo-preexistente-poc.md` para análise completa.

### Estrutura da PoC (`api-ponto/` no git HEAD)

```
api-ponto/                       # Ruby on Rails 8 (api_only)
├── app/
│   ├── controllers/presenca/    # 11 controllers (ValidarFrequentador, DynFrequentadores, etc.)
│   ├── jobs/application_job.rb
│   ├── models/                  # User + TimeRecord + ApplicationRecord
│   ├── services/                # crypto_des.rb + frequentadores_serializer.rb
│   └── views/presenca/ponto_de_presenca/index.html.erb
├── config/
│   ├── routes.rb                # namespace :presenca com 11 endpoints
│   ├── database.yml             # PostgreSQL
│   └── deploy.yml               # Kamal
└── test/                        # 25 testes Minitest
```

**Status:** PoC implementada; restauração do working tree é decisão pendente.
**Próximo passo:** Decidir com o usuário: (a) `git restore` para usar como base do Frequência, (b) manter apenas como referência arquitetural.

---

## Descobertas

1. **Intranet usa Ant + Tomcat + Docker** — O build legado é Ant (não Maven/Gradle). O deploy é via Tomcat em container Docker.
2. **EstaçãoPonto usa Maven + criptografia DES** — `pom.xml` e `TestCrypto.java` usam DES/CBC com chave fixa `"cryp:gpf"` (ver `docs/07-estacao-ponto/01-resumo-arquitetura.md`).
3. **Frequência já tem PoC Rails 8 IMPLEMENTADA no git** (`api-ponto/`): 11 endpoints, controllers, models, services, 25 testes, Sprint 1–5 concluídas. Working tree acidentalmente vazio da pasta; verificar restauração com o usuário (ver `docs/05-migracao/00-codigo-preexistente-poc.md`).
4. **Pessoas é Rails completo** — Tem RSpec, Cucumber, CI/CD configurado (Procfile). É um projeto maduro.
5. **EstaçãoPonto está completamente documentada** — `documentacao-estacao-ponto.md` (1773 linhas, 19 etapas) cobre arquitetura, regras de negócio, fluxos, UML, débitos técnicos, endpoints consumidos. Síntese em `docs/07-estacao-ponto/01-resumo-arquitetura.md`.

## Pendências

- [ ] **DECIDIR:** restaurar `api-ponto/` do git para o working tree (atualizar ADR-0005).
- [ ] Auditar a PoC contra o PRD ponto-a-ponto (gap analysis).
- [ ] Verificar compatibilidade DES-UrlBase64 entre Ruby (`crypto_des.rb`) e Java (`CryptoUtils.java`).
- [ ] Explorar `intranet/src/` para identificar os pacotes do módulo Frequência (Fase 1 detalhada).
- [ ] Analisar `estacaoPonto/pom.xml` e `TestCrypto.java` para confirmar criptografia (testar cross-implementação).
- [ ] Verificar se `pessoas2/` já expõe API para consulta de servidores (impacta ADR-0001).
- [ ] Investigar contratos dos endpoints EP-11 (`Frequentador`) e EP-12 (`ProblemaRegistro`) — não documentados no PRD.
- [ ] Confirmar se a Intranet ainda expõe `EP-07 PrediosPermitidos` e se a EstaçãoPonto realmente chama.

---
**Última atualização:** 2026-08-04 (correção: PoC `api-ponto/` adicionada após ler docs pré-existentes)
