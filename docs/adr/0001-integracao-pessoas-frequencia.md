# ADR-0001: Integração entre Pessoas e Frequência

> **[⌂ Home](../README.md)**

## Status

Aceito

## Contexto

O sistema **Pessoas** (Ruby on Rails) é a autoridade dos dados cadastrais dos servidores (matrícula, nome, e-mail, lotação, cargo, situação funcional, etc.). O novo sistema **Frequência** (Ruby on Rails) precisa desses dados para processar regras de ponto eletrônico.

Duas abordagens são possíveis:
1. **Compartilhamento de banco de dados** — Frequência acessa diretamente o banco do Pessoas.
2. **Integração por API/Eventos** — Frequência consulta Pessoas via API REST e é notificado por eventos sobre alterações cadastrais.

## Alternativas Consideradas

### Alternativa A: Compartilhamento de Banco de Dados

- **Descrição:** O Frequência lê diretamente as tabelas do Pessoas (via conexão MySQL ou replicação).
- **Prós:**
  - Baixa latência (acesso direto ao dado).
  - Sem necessidade de desenvolver API.
- **Contras:**
  - Acoplamento físico: mudanças no schema do Pessoas quebram o Frequência.
  - Violação do princípio de Bounded Context (DDD): dois domínios distintos compartilham o mesmo modelo de dados.
  - Dificulta evolução independente dos sistemas.
  - Risco de lock e contenção no banco do Pessoas.

### Alternativa B: API REST Síncrona + Eventos Assíncronos

- **Descrição:** O Frequência consulta dados cadastrais via API REST do Pessoas. Mudanças cadastrais (lotação, cargo) disparam eventos que o Frequência consome.
- **Prós:**
  - Baixo acoplamento: Pessoas e Frequência evoluem independentemente.
  - Cada sistema é autoridade no seu domínio.
  - Facilita testes (mock da API do Pessoas).
  - Permite cache local no Frequência para performance.
- **Contras:**
  - Maior latência na consulta inicial (resolvido com cache).
  - Complexidade adicional (eventos, filas, consistência eventual).
  - Necessidade de desenvolver e manter API no Pessoas.

### Alternativa C: Réplica do Banco do Pessoas

- **Descrição:** Criar uma réplica (MySQL slave ou dump periódico) das tabelas do Pessoas para o Frequência.
- **Prós:**
  - Menor latência que API (dados locais).
  - Sem acoplamento de schema (pode transformar os dados).
- **Contras:**
  - Dados eventualmente inconsistentes (delay da réplica).
  - Complexidade operacional de manter réplica.
  - Ainda expõe o modelo interno do Pessoas.

## Decisão

> **Escolhemos a Alternativa B: API REST + Eventos Assíncronos.**

Justificativa:
1. **Respeita os Bounded Contexts:** Pessoas é autoridade cadastral; Frequência é autoridade de ponto. Cada um tem seu modelo.
2. **Evolução independente:** O schema do Pessoas pode ser alterado sem impacto no Frequência (desde que a API seja preservada).
3. **Padrão comprovado:** É a abordagem recomendada para sistemas que precisam ser desacoplados e escalar independentemente.
4. **Prepara para futuro:** Se outros sistemas (novos) precisarem de dados cadastrais, a API do Pessoas já existirá.

Para performance, o Frequência manterá um **cache local** (tabela espelho) dos dados cadastrais mais consultados, atualizado por eventos assíncronos.

## Consequências

### Positivas

- Desacoplamento completo entre domínios.
- Facilidade para testar o Frequência isoladamente.
- O Pessoas pode evoluir seu schema interno sem quebrar o Frequência.

### Negativas / Trade-offs

- **Maior esforço inicial:** Precisamos desenvolver/adaptar a API do Pessoas (ou usar a existente).
- **Consistência eventual:** Dados cadastrais podem ficar desatualizados no Frequência por alguns segundos/minutos (até o evento ser processado). Isso é aceitável para o domínio de frequência (batidas não dependem de dados cadastrais em tempo real para serem registradas).

### Neutras

- Será necessário implementar fila de eventos (Redis/Sidekiq) no Pessoas ou usar message broker.

## Compliance

- O Frequência NÃO deve consultar tabelas do Pessoas diretamente.
- Toda consulta a dados cadastrais deve passar pela API do Pessoas OU pelo cache local (alimentado por eventos).
- Code reviews devem verificar se há imports ou queries apontando para o banco do Pessoas.

## Notas

- ADR relacionado: ADR-0002 (Integração EstaçãoPonto) — ainda não criado.
- Ver também: [Documento de Integrações](/docs/06-integracoes/integracoes.md)
