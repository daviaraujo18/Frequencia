# ADR-0005: Destino da PoC `api-ponto/` (Sistema Frequência)

> **[⌂ Home](../README.md)**

## Status

Aceito — Alternativa C escolhida pelo gestor em 04/08/2026

## Contexto

Em 04/08/2026, durante a Fase 1 (Inventário) do framework de migração, ao ler os documentos pré-existentes em `frequencia/` (`PRD-POC-API-PONTO.md`, `SPRINT-PLAN.md`, `documentacao-estacao-ponto.md`), descobriu-se que:

1. A equipe já elaborou um **PRD completo** (652 linhas) para uma PoC Rails 8 substituindo o módulo Presença da Intranet.
2. A **SPRINT-PLAN** descreve 6 sprints (48 tasks), com **Sprints 1–5 marcadas como concluídas** (25 testes Minitest, 0 falhas) e **Sprint 6 parcial** (integração com a EstaçãoPonto real).
3. O commit `61b70cf` do repositório `frequencia/` introduziu **3316 arquivos** sob `api-ponto/` (código Rails completo).
4. No working tree atual, todos esses 3316 arquivos constam como `deleted:` no `git status` — provavelmente remoção acidental.

### Evidências

- `git -C frequencia ls-tree -r HEAD --name-only | grep "api-ponto/" | wc -l` → 3316
- `git show HEAD:api-ponto/config/routes.rb` → expõe 11 endpoints sob namespace `presenca`, batendo 1:1 com o PRD §8
- `git show HEAD:api-ponto/app/controllers/presenca/validar_frequentador_controller.rb` → controller Ruby implementado com `CryptoDes.decrypt`, `User.ativos.find_by`, bcrypt, mensagens `USUARIO_SENHA_INVALIDOS`

### Por que isso importa

Esta é uma decisão de alto impacto sobre **como** a migração será executada:

- Se a PoC for **base do Frequência**, reduzem-se drasticamente o escopo da Fase 4 (Arquitetura Alvo) e da Fase 7 (Plano de Implementação) — muito código já existe.
- Se a PoC for **apenas referência**, o trabalho de Fase 4 e 7 é refeito, mas pode-se abandonar débitos herdados (DES hardcoded, `User` local, `codAtivacao` fixo).
- O cronograma, estimativas de esforço, riscos e rollback da Fase 9 mudam substancialmente.

## Alternativas Consideradas

### Alternativa A: Restaurar a PoC (`git restore`) e usá-la como base do Frequência

- **Descrição:** Executar `git restore api-ponto/` no repositório `frequencia/` (ou mover para o diretório destino definitivo, e.g. `frequencia/api-ponto/` ou um repositório separado). A partir daí, todas as novas funcionalidades são construídas incrementalmente sobre essa base, aplicando-se o ciclo Spec-Driven (ADR-0004) para evolução.
- **Prós:**
  - Economiza meses de desenvolvimento — 11 endpoints já estão funcionais e testados (25 testes Minitest).
  - Mantém compatibilidade real com a EstaçãoPonto (validada empiricalmente via curl na Sprint 6).
  - Sprint 6 já documentou ajustes práticos de ambiente (`host.docker.internal`, `mkdirs` fix, retornar `text/html` em endpoints WebView).
  - Diminui o risco da Fase 6 (Plano de Compatibilidade) — o Adapter já foi provado.
  - Herda o conhecimento já consolidado da equipe sobre o protocolo DES-UrlBase64.
- **Contras:**
  - Herda dívidos técnicos:
    - `User` local sem integração com Pessoas (viola ADR-0001 — precisa refatorar depois).
    - `codAtivacao` fixo `"poc-ativacao-001"` — inviável para produção.
    - DES hardcoded `"cryp:gpf"` — safety debt (mantido por compatibilidade com estação).
    - Scala: ainda não cobre jornadas, escalas, férias, banco de horas, cálculos, fechamento, relatórios, prédios permitidos, fotos, auto-update.
  - Decisões arquiteturais implícitas na PoC podem precisar revisão (uso de Rails 8 `--api`, ausência de camada de domínio explícita, etc.).
  - Sem estrutura DDD (camada de domínio, agregados) — adequação futurareq trabalhosa.

### Alternativa B: Manter a PoC apenas como referência arquitetural

- **Descrição:** Não restaurar `api-ponto/`. A PoC funciona como spike exploratório comprovando viabilidade técnica. O Frequência real será reescrito do zero num novo repositório.
- **Prós:**
  - Liberdade total para desenhar DDD completo (bounded contexts, agregados, value objects) do dia 1.
  - Sem herdar dívidos da PoC (DES, `codAtivacao` fixo, modelagem cadastral acoplada).
  - Stack pode evoluir (ex. trocar Rails 8 por outra coisa, se fizer sentido — improvável mas possível).
  - Esclarece separação entre spikes e produção.
- **Contras:**
  - Desperdício de trabalho já pago e testado (3316 arquivos, 25 testes).
  - Reimplementação de endpoints que já funcionam com estação real via curl.
  - Aumenta cronograma da migração em semanas/meses.
  - Perde os aprendizados práticos da Sprint 6 (ajustes de Docker, WebView, jQuery stub).

### Alternativa C: Restaurar como base, mas em repositório novo + refactoring arquitetural

- **Descrição:** Restaurar a PoC, mas migrá-la para um novo repositório `frequencia-sistema/` (não o atual `frequencia/` que é só documentação). Estrutura em camadas DDD desde o início: controllers compatíveis legados → application services → domain → infrastructure. Refatorações: `User` → cache local de Pessoas (ADR-0001); `codAtivacao` fixo → auth de estação real; DES → wrapper histórico mantido, mas com possibilidade de AES no futuro.
- **Prós:**
  - Combina reuso de código validado com liberdade arquitetural.
  - Separação clara entre PoC (spike) e Frequência (produção).
  - Caminho incremental para evoluir sem Big Bang.
  - Resolve débitos progressivamente ao longo das fases 7 e 8.
- **Contras:**
  - Trabalho de setup (novo repositório, migração de código, ajuste de paths).
  - Pode parecer burocrático na fase de transição.
  - Possível divergência temporária entre a PoC (referência) e o sistema em produção.

## Decisão

> **ADOTAMOS A ALTERNATIVA C:** Restaurar a PoC em **novo repositório** + refactoring arquitetural incremental.

**Decisão confirmada pelo gestor do projeto em 04/08/2026.**

### Etapas de Execução da Decisão (alto nível — serão detalhadas na Fase 7)

1. **Restaurar `api-ponto/`** do git HEAD de `frequencia/` para um diretório temporário (não deixar em `frequencia/api-ponto/`, pois `frequencia/` é apenas documentação).
2. **Criar novo repositório** destino (nome provisório: `frequencia-sistema` — será confirmado).
3. **Migrar o código** da PoC restaurada para o novo repositório, preservando histórico git (ou iniciando histórico novo com commit de importação).
4. **Estrutura DDD alvo** (aplicada incrementalmente, não big-bang):
   ```
   frequencia-sistema/
   ├── app/
   │   ├── controllers/presenca/       # MANTÉM: camada de compatibilidade (Adapter, ADR-0003)
   │   ├── controllers/api/v1/         # NOVO: API REST canônica do Frequência
   │   ├── models/                     # TimeRecord (interno); User → refatorar para cache Pessoas
   │   ├── services/                   # crypto_des (legacy compat), frequentadores_serializer (legacy compat)
   │   ├── domain/                     # NOVO: agregados, entidades, value objects, serviços de domínio
   │   ├── application/                # NOVO: casos de uso (orquestração)
   │   └── infrastructure/            # NOVO: clients Pessoas API, eventos, persistence adapters
   ├── config/
   ├── db/
   └── test/  (também spec/ se migrarmos para RSpec)
   ```
5. **Década de refatoramentos transformados em funcionalidades Spec-Driven** (ADR-0004):
   - **FR-LEGADO-DEBT-01:** Substituir `User` local por **cache Pessoas** (ver ADR-0001). Spec → design → tasks → execute.
   - **FR-LEGADO-DEBT-02:** Substituir `codAtivacao` fixo por **auth real de estação**.
   - **FR-LEGADO-DEBT-03:** Logger estruturado (substituir `System.out.println` em controllers).
   - **FR-LEGADO-DEBT-04:** Criação da camada `domain/` para futuras funcionalidades reais (jornada, escala, etc.).
   - DES `"cryp:gpf"` MANTIDO por compatibilidade com EstaçãoPonto legada — só revisitar quando a estação for atualizada (não priorizar).

## Consequências

### Positivas

- Aceleração da Fase 7 (Plano de Implementação) — muitas tarefas já estão parcialmente feitas.
- Risco da Fase 6 significativamente mitigado — Adapter validado empiricamente.
- Framework de migração ganha corpo concreto desde o início.

### Negativas / Trade-offs

- Necessidade de conduzir refactoring da PoC pós-restauração em trilho incremental (não destrutivo).
- Documentação do ADR-0001 ainda requer detalhamento sobre como o `User` se tornará cache do Pessoas.
- Possível distração: revisar PoC pode consumir tokens sem critério. **Restrição:** usar Spec-Driven para conduzir mudanças pontuais, nunca reescrever de uma vez.

### Neutras

- Decisão específica sobre nome do repositório destino (e.g. `frequencia-sistema`, `frequencia-app`) fica para etapa posterior. **Sugestão atual:** `frequencia-sistema` (denota "o sistema Frequência", evitando ambiguidade com a pasta `frequencia/` atual que é só documentação).
- Time pode optar por RSpec em vez de Minitest durante o setup do novo repositório — será uma decisão operacional interna (não arquitetural).

## Compliance

- Independentemente da alternativa escolhida, todas as funcionalidades do Frequência devem seguir o ciclo Spec-Driven (ADR-0004) com `docs/specs/features/[funcionalidade]/`.
- Nenhuma feature migrada da PoC para o Frequência pode ser aceita sem spec.md + validacao-migracao.md.
- A eventual restauração não elimina a necessidade de Fase 1 (Inventário) e Fase 2 (Engenharia Reversa) da Intranet — a PoC NÃO cobre as regras de negócio do legado (jornadas, escalas, cálculos, etc.).
- **NOVO (pós-decisão):** Todo novo repositório do Frequência deve manter o namespace `presenca` em controllers compatíveis para atender ADR-0003 até estrangulamento completo. Nenhuma removing dessa camada pode ser feita sem um novo ADR.
- **NOVO:** A camada `domain/` do novo repositório não pode depender de Rails (ActiveRecord, ActionController) — regra de Clean Architecture para preparar futuro desacoplamento.

## Notas

- ADRs relacionados: 0001 (Pessoas integração), 0002 (Strangler Fig), 0003 (Compatibilidade EstaçãoPonto), 0004 (Spec-Driven).
- Documentos de suporte: `docs/05-migracao/00-codigo-preexistente-poc.md`, `docs/07-estacao-ponto/02-endpoints-consumidos.md`.
- Análise arquitetural da PoC atual (`git show HEAD:api-ponto/...`) será feita APÓS a decisão, para não consumir contexto desnecessariamente.
- Worker dir do `frequencia/` tem `.git` ativo; `git restore api-ponto/` traria todos os arquivos do HEAD de volta ao working tree.
