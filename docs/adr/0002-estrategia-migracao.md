# ADR-0002: Estratégia de Migração — Strangler Fig Pattern

> **[⌂ Home](../README.md)**

## Status

Aceito

## Contexto

Precisamos substituir o módulo de Frequência do sistema legado **Intranet (Java 6 + MySQL 5)** por um novo sistema **Frequência (Ruby on Rails)**. A **EstaçãoPonto** (aplicação desktop em centenas de unidades) envia batidas para a Intranet.

O risco de uma migração Big Bang é inaceitável:
- Centenas de estações podem parar de funcionar.
- O processamento de frequência de milhares de servidores pode ser comprometido.
- Rollback seria complexo e demorado.

## Alternativas Consideradas

### Alternativa A: Big Bang

- **Descrição:** Desenvolver todo o sistema Frequência, migrar todos os dados de uma vez, desligar a Intranet e atualizar todas as EstaçãoPonto simultaneamente.
- **Prós:**
  - Simplicidade de planejamento (uma única migração).
  - Sem necessidade de manter dois sistemas em paralelo.
- **Contras:**
  - ⚠️ RISCO ALTÍSSIMO: Qualquer problema paralisa o registro de ponto do Tribunal.
  - Janela de migração enorme (dias/semanas).
  - Rollback praticamente inviável.
  - Atualizar centenas de EstaçãoPonto simultaneamente é logisticamente complexo.

### Alternativa B: Strangler Fig Pattern (Escolhida)

- **Descrição:** Criar o Frequência em paralelo com a Intranet. Um proxy reverso (ou gateway) decide para onde cada requisição vai. Funcionalidades são migradas uma a uma. A EstaçãoPonto continua apontando para o mesmo endpoint (o proxy decide o destino).
- **Prós:**
  - Risco controlado: cada funcionalidade é migrada e testada individualmente.
  - Rollback simples: basta reverter a rota no proxy.
  - A EstaçãoPonto não precisa ser alterada durante a maior parte da migração.
  - Permite teste com dados reais em paralelo.
- **Contras:**
  - Complexidade operacional (manter dois sistemas, proxy, consistência de dados).
  - Mais lento que Big Bang (migração gradual).
  - Necessidade de sincronizar dados entre Intranet e Frequência durante a migração.

### Alternativa C: Migração Incremental Sem Proxy

- **Descrição:** Alterar a EstaçãoPonto para enviar para o Frequência diretamente. O Frequência processa algumas funcionalidades e delega outras para a Intranet.
- **Prós:**
  - Sem necessidade de proxy.
- **Contras:**
  - A EstaçãoPonto precisaria ser alterada múltiplas vezes (uma para cada endpoint).
  - Complexidade de lógica de delegação no Frequência.
  - Acoplamento do Frequência com a Intranet.

## Decisão

> **Escolhemos o Strangler Fig Pattern com proxy reverso.**

A migração será feita em 3 estágios:

### Estágio 1: Sombra (Shadow Mode)
- O Frequência é implantado e recebe **cópia** de todas as requisições que a Intranet recebe.
- Nada é processado "para valer" no Frequência ainda.
- Validamos se o Frequência interpreta corretamente as requisições.
- Coletamos métricas de acurácia comparando resultados.

### Estágio 2: Estrangulamento Parcial
- Funcionalidades de **baixo risco** são migradas primeiro (consultas, relatórios, etc.).
- O proxy redireciona apenas essas requisições para o Frequência.
- Funcionalidades de **alto risco** (registro de batidas, cálculos) permanecem na Intranet.

### Estágio 3: Estrangulamento Total
- Todas as funcionalidades são migradas para o Frequência.
- O proxy para de redirecionar para a Intranet.
- A Intranet é mantida apenas para consulta histórica.
- A EstaçãoPonto tem seu endpoint alterado (agora aponta para o Frequência diretamente).
- Finalmente, a Intranet é desligada.

### Proxy Reverso
O proxy será implementado com **Nginx + Lua (OpenResty)** ou **HAProxy** com regras de roteamento, ou um **gateway Ruby (Rack middleware)** no próprio Frequência que faz o roteamento.

Isso será detalhado no ADR específico (ADR-0004).

## Consequências

### Positivas

- Risco drasticamente reduzido.
- Rollback trivial (reverter rota no proxy).
- Validação contínua com dados reais.
- A EstaçãoPonto não precisa ser alterada até o estágio final.

### Negativas / Trade-offs

- **Maior complexidade inicial:** Precisamos do proxy, da lógica de shadow mode e da sincronização de dados.
- **Custo operacional:** Dois sistemas rodando simultaneamente por um período.
- **Sincronização de dados:** Dados cadastrais (do Pessoas) e dados de frequência (da Intranet) precisam estar disponíveis no Frequência durante a migração. Isso exige uma estratégia de migração de dados.

### Neutras

- O time precisa aprender a operar o proxy.
- A migração levará mais tempo no calendário, mas com menos risco.

## Compliance

- Toda nova funcionalidade do Frequência deve ser implantada por trás do proxy (nunca exposta diretamente).
- O Frequência nunca deve ser a única fonte de verdade até que o estrangulamento esteja completo.
- Testes de sombra devem ser automatizados.

## Notas

- Requer ADR sobre a Migração de Dados (como sincronizar dados históricos da Intranet para o Frequência).
- Requer ADR sobre o Gateway/Proxy (estratégia de roteamento).
- ADR-0001 define a integração com Pessoas, que é pré-requisito.
