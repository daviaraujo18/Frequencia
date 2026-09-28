# Framework de Migração

> **[⌂ Home](../README.md)**

## Filosofia

Este framework adota uma abordagem **evolutiva**, **orientada a risco** e **baseada em evidências**. Cada fase só começa quando a anterior tem seus critérios de aceite satisfeitos. O objetivo é **reduzir surpresas** em produção.

## As 10 Fases

```
Fase 0: Preparação      → Estrutura do projeto OpenCode
Fase 1: Inventário      → Mapeamento completo do legado
Fase 2: Engenharia Reversa → Descoberta de fluxos e regras
Fase 3: Mapeamento de Domínio → Bounded Contexts, Agregados, Eventos
Fase 4: Arquitetura Alvo → Design do novo sistema (Rails + DDD)
Fase 5: Estratégia de Migração → Big Bang vs Strangler Fig vs Incremental
Fase 6: Plano de Compatibilidade → Adaptação da EstaçãoPonto
Fase 7: Plano de Implementação → Entregas independentes e implantáveis
Fase 8: Plano de Testes → Estratégia completa de qualidade
Fase 9: Plano de Implantação → Produção, rollback, observabilidade
```

---

## Fase 0 — Preparação

### Objetivo
Estabelecer toda a estrutura de diretórios, convenções, ferramentas e o arcabouço do projeto OpenCode para dar suporte a todas as fases seguintes.

### Entregáveis
- [x] Estrutura de diretórios criada (`/docs`, `/prompts`, `/tasks`, `/context`)
- [x] Documento de visão geral (este arquivo)
- [x] Framework de migração documentado
- [ ] Inventário inicial dos diretórios dos projetos legados
- [ ] Configuração do OpenCode (se aplicável)

### Critérios de Aceite
- Qualquer arquivo Markdown relevante encontra-se em um diretório adequado.
- As convenções de documentação estão definidas e acessíveis.
- O time sabe exatamente onde registrar cada descoberta.

### Riscos
- Baixo. Apenas organização, sem impacto em sistemas reais.

### Estratégia
- Começar pequeno, evoluir a estrutura conforme necessário.
- Não criar arquivos vazios "para depois". Criar apenas quando houver conteúdo.

---

## Fase 1 — Inventário

### Objetivo
Mapear **completamente** o sistema Intranet (módulo Frequência): classes, pacotes, controllers, serviços, entidades, banco de dados, procedures, jobs, integrações, APIs, filas, serviços externos.

### Entregáveis
- [ ] Mapa de pacotes/classes do módulo Frequência
- [ ] Diagrama de entidades do banco de dados
- [ ] Lista de stored procedures e funções
- [ ] Mapa de dependências entre classes
- [ ] Inventário de integrações (o que chama o que)
- [ ] Documentação do schema do banco (tabelas, colunas, índices, FKs)
- [ ] Mapa da EstaçãoPonto: tecnologia, protocolo, formato das requisições

### Critérios de Aceite
- Toda classe Java do módulo Frequência está listada.
- Toda tabela MySQL do módulo Frequência está documentada.
- Toda integração conhecida está mapeada.
- O formato de comunicação da EstaçãoPonto com a Intranet está documentado.

### Riscos
- Médio. Pode haver código não versionado ou documentação desatualizada. Exige acesso ao ambiente real.

### Estratégia
- Trabalhar por camada: primeiro banco, depois backend (Java), depois frontend (se houver).
- Usar ferramentas de scraping/reflection para gerar inventário automaticamente.
- Entrevistar desenvolvedores que conhecem o sistema.

---

## Fase 2 — Engenharia Reversa

### Objetivo
Descobrir os **fluxos completos** de:
- Registro de batida (ponto eletrônico)
- Processamento das batidas (cálculo de horas)
- Jornadas, horários, escalas
- Direitos, afastamentos, férias
- Banco de horas
- Cálculos (horas extras, noturno, etc.)
- Fechamento de frequência
- Regras de negócio ocultas
- Dependências ocultas e acoplamentos

### Entregáveis
- [ ] Diagramas de sequência para cada fluxo principal
- [ ] Diagrama de atividades para processamento de batidas
- [ ] Mapa de dependências entre funcionalidades
- [ ] Documentação de cada regra de negócio encontrada (com referência ao código-fonte)
- [ ] Mapa de estados da batida/frequência

### Critérios de Aceite
- Cada regra de negócio identificada tem um documento associado com a evidência (caminho do arquivo, linha).
- Os fluxos principais estão diagramados.
- Regras implícitas (hard-coded, sem documentação) estão registradas como PENDÊNCIA.

### Riscos
- Alto. Regras de negócio ocultas podem não ser encontradas até a fase de testes de migração. Risco de assumir comportamento incorreto.

### Estratégia
- Rastrear chamadas no código: controller → service → DAO → banco.
- Executar queries reais (modo leitura) contra o banco de produção para entender dados.
- Criar testes de caracterização (characterization tests) no código legado para congelar comportamento antes de alterar.
- Trabalhar em pequenos fluxos, um de cada vez.

---

## Fase 3 — Mapeamento de Domínio (DDD)

### Objetivo
Identificar os **Bounded Contexts**, **Agregados**, **Entidades**, **Value Objects**, **Eventos de Domínio**, **Serviços de Domínio** e **Casos de Uso** do módulo de Frequência.

### Entregáveis
- [ ] Diagrama de Bounded Contexts
- [ ] Mapa de Agregados com raízes identificadas
- [ ] Lista de Entidades e Value Objects
- [ ] Catálogo de Eventos de Domínio
- [ ] Definição dos Serviços de Domínio
- [ ] Casos de Uso priorizados

### Critérios de Aceite
- A separação entre os contextos Pessoas, Frequência e EstaçãoPonto está claramente definida.
- Cada agregado tem uma raiz identificada.
- Eventos de domínio estão nomeados e descritos.

### Riscos
- Médio. Pode haver acoplamento não intencional entre contextos que precisa ser desfeito.

### Estratégia
- Usar os fluxos da Fase 2 para extrair a linguagem ubíqua.
- Validar com especialistas de negócio (RH) se a terminologia está correta.
- Aplicar Event Storming simplificado (documentado, não necessariamente workshop presencial).

---

## Fase 4 — Arquitetura Alvo

### Objetivo
Projetar a arquitetura do sistema **Frequência** em Ruby on Rails, aplicando DDD e Clean Architecture.

### Entregáveis
- [ ] Diagrama de camadas (Controllers, Services, Models, Domain, Infrastructure)
- [ ] Definição de API (endpoints, formato, versionamento)
- [ ] Estrutura de diretórios do projeto Rails
- [ ] Definição de autenticação/autorização
- [ ] Estratégia de integração com Pessoas (API vs Eventos)
- [ ] Estratégia de integração com EstaçãoPonto (camada de compatibilidade)
- [ ] Definição de jobs, filas, processamento assíncrono
- [ ] ADR das decisões arquiteturais

### Critérios de Aceite
- A arquitetura está documentada e aprovada pelo time.
- A separação entre domínio e infraestrutura está clara.
- A API de compatibilidade com a EstaçãoPonto está especificada.

### Riscos
- Médio. Decisões erradas aqui geram retrabalho. É crítico ter um entendimento sólido do domínio (Fase 3) antes de projetar.

### Estratégia
- Usar Rails API-only (sem views, sem assets).
- Aplicar o padrão de Services para orquestração.
- Repository pattern para abstrair persistência.
- Eventos via Active Job + Sidekiq/Redis.
- Integração síncrona com Pessoas via API REST (consulta), eventos assíncronos para mudanças cadastrais.

---

## Fase 5 — Estratégia de Migração

### Objetivo
Definir **como** a migração será feita: Big Bang, Strangler Fig ou migração incremental.

### Entregáveis
- [ ] Documento de estratégia de migração (com justificativa técnica)
- [ ] Mapa de dependências entre funcionalidades para ordenação da migração
- [ ] Definição de como lidar com dados existentes (migração de dados)

### Critérios de Aceite
- A estratégia está documentada, justificada e aprovada.
- Há um plano claro de rollback para cada etapa.

### Riscos
- Alto. Uma estratégia errada pode parar o Tribunal (impacto em centenas de unidades).
- A EstaçãoPonto está instalada em centenas de máquinas — alterações são custosas.

### Estratégia Recomendada (a priori)
**Strangler Fig Pattern** com migração incremental por funcionalidade.
- Criar o novo sistema Frequência em paralelo.
- Roteamento: usar um proxy reverso/gateway que decide se a requisição vai para a Intranet ou para o Frequência.
- Cada funcionalidade é migrada individualmente e testada com dados reais.
- A EstaçãoPonto é a última peça a ser migrada (apenas endpoint).

---

## Fase 6 — Plano de Compatibilidade (EstaçãoPonto)

### Objetivo
Garantir que a EstaçãoPonto continue funcionando com o **mínimo de alterações** possível.

### Entregáveis
- [ ] Análise do protocolo de comunicação da EstaçãoPonto
- [ ] Documentação da interface atual (endpoints, headers, payloads)
- [ ] Proposta de solução (adaptador, gateway, proxy, etc.)
- [ ] Plano de atualização da EstaçãoPonto (ou prova de que não é necessária)

### Critérios de Aceite
- A solução escolhida está documentada com prós e contras.
- O impacto na EstaçãoPonto é mínimo (idealmente zero alterações no cliente desktop).

### Alternativas a Avaliar
1. **Alterar endpoint** — configuração remota ou manual em cada estação.
2. **Criar gateway/adaptador** — serviço intermediário que traduz protocolos.
3. **Proxy reverso** — Nginx/HAProxy que redireciona sem alterar o cliente.
4. **Camada de compatibilidade** — serviço que expõe exatamente a mesma API da Intranet.
5. **Replicação de API** — duplicar a API no Frequência.
6. **Cliente adaptador local** — pequeno agente na estação que substitui o cliente.

---

## Fase 7 — Plano de Implementação

### Objetivo
Dividir a construção do sistema Frequência em **pequenas entregas independentes e implantáveis**.

### Entregáveis
- [ ] Backlog priorizado de entregas
- [ ] Roadmap de implementação
- [ ] Definição de milestones

### Critérios de Aceite
- Cada entrega é autônoma (não depende de outra entrega futura para funcionar).
- Cada entrega pode ser testada isoladamente.
- Cada entrega pode ser implantada em produção sem quebrar o sistema atual.

---

## Fase 8 — Plano de Testes

### Objetivo
Criar uma estratégia completa de testes que garanta a corretude da migração.

### Entregáveis
- [ ] Estratégia de testes unitários (RSpec)
- [ ] Estratégia de testes de integração
- [ ] Testes de contrato (Pact) para integrações
- [ ] Testes de regressão (comparar saída do legado vs novo)
- [ ] Plano de homologação
- [ ] Testes de migração de dados
- [ ] Testes de rollback

---

## Fase 9 — Plano de Implantação

### Objetivo
Planejar a ida para produção com segurança e observabilidade.

### Entregáveis
- [ ] Pipeline de CI/CD
- [ ] Playbook de implantação
- [ ] Playbook de rollback
- [ ] Configuração de monitoramento
- [ ] Dashboard de métricas
- [ ] Estratégia de logging
- [ ] Plano de comunicação com usuários
