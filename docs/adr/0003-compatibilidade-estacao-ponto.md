# ADR-0003: Compatibilidade com a EstaçãoPonto

> **[⌂ Home](../README.md)**

## Status

Aceito

## Contexto

A **EstaçãoPonto** é uma aplicação desktop instalada em centenas de unidades do Tribunal. Ela se comunica com a **Intranet** para:
1. Autenticar/identificar o servidor (captura biométrica).
2. Enviar registros de batida (data/hora, matrícula, dispositivo).
3. (Possivelmente) consultar dados do servidor para exibição.

O problema é que a EstaçãoPonto tem **forte acoplamento** com a Intranet:
- Conhece o endpoint específico (URL + porta).
- Conhece o formato das requisições/respostas (JSON, XML, ou formato proprietário).
- Pode ter lógica de fallback, timeout, reconexão específica para a Intranet.

O sistema de atualização automática é simples e pouco confiável, o que torna arriscado distribuir uma nova versão do cliente.

**Objetivo:** Alterar o mínimo possível na EstaçãoPonto. Idealmente, apenas o endpoint ou a camada de comunicação.

## Alternativas Consideradas

### Alternativa A: Alterar Apenas o Endpoint na EstaçãoPonto

- **Descrição:** Configurar (manualmente ou via atualização remota) a EstaçãoPonto para apontar para o novo sistema Frequência, que expõe **exatamente a mesma interface** da Intranet.
- **Prós:**
  - Alteração mínima no software da estação (só a URL).
  - Sem necessidade de middleware adicional.
- **Contras:**
  - Requer acesso a centenas de estações para alterar a configuração.
  - Se a interface da Intranet for complexa (SOAP, RMI, protocolo proprietário), replicá-la no Frequência pode ser inviável ou de alto risco.
  - Sem sistema de atualização confiável, a alteração depende de visitas presenciais.

### Alternativa B: Camada de Compatibilidade (Adapter/Facade)

- **Descrição:** Criar um serviço intermediário (adaptador) que expõe **exatamente a mesma interface** que a Intranet expunha. Esse adaptador recebe as requisições da EstaçãoPonto e as traduz para as chamadas internas do Frequência (ou da Intranet, durante a migração).
- **Prós:**
  - A EstaçãoPonto não precisa ser alterada (zero mudança no cliente).
  - O adaptador pode rotear para a Intranet ou Frequência conforme a funcionalidade (suporte ao Strangler Fig).
  - Pode ser implantado como um proxy na mesma rede da Intranet, usando o mesmo IP/porta.
  - Ideal para migração gradual.
- **Contras:**
  - Complexidade adicional (um serviço a mais para manter).
  - Precisa replicar fielmente o protocolo da Intranet.
  - Ponto adicional de falha.

### Alternativa C: Cliente Adaptador Local na EstaçãoPonto

- **Descrição:** Instalar um pequeno agente/service em cada estação que recebe as requisições da EstaçãoPonto (em 127.0.0.1) e as redireciona para o Frequência, traduzindo o protocolo.
- **Prós:**
  - A EstaçãoPonto não precisa ser alterada (apenas o endpoint local).
  - Isolamento: cada estação é independente.
- **Contras:**
  - Precisa ser instalado em centenas de máquinas (mesmo problema de distribuição).
  - Mais complexo operacionalmente.

### Alternativa D: Proxy Reverso (Nginx/HAProxy)

- **Descrição:** Colocar um proxy reverso na frente da Intranet que roteia requisições para a Intranet ou Frequência baseado em regras (URL, header, corpo). A EstaçãoPonto continua apontando para o mesmo IP (que agora é o proxy).
- **Prós:**
  - Zero alteração na EstaçãoPonto (o IP/porta não muda).
  - Suporte nativo ao Strangler Fig (roteamento por regra).
  - Tecnologia madura (Nginx, HAProxy).
  - Pode ser implantado sem alterar a rede (só redirecionar o DNS ou colocar na frente do balanceador).
- **Contras:**
  - Se o protocolo for binário ou proprietário, o proxy pode não conseguir inspecionar o conteúdo para roteamento.
  - Ponto adicional de falha (resolvido com alta disponibilidade).

## Decisão

> **Escolhemos uma combinação das Alternativas B e D: Camada de Compatibilidade + Proxy Reverso.**

A estratégia será:

1. **Proxy Reverso (Nginx)** colocado na frente do endpoint atual da Intranet.
2. Durante o Strangler Fig, o proxy roteia requisições para a Intranet ou para o **Adapter de Compatibilidade**, conforme a funcionalidade migrada ou não.
3. O **Adapter de Compatibilidade** é um serviço Ruby (Rack/Sinatra) que:
   - Expõe exatamente o mesmo endpoint que a Intranet expunha.
   - Traduz o protocolo legado para chamadas internas do Frequência (ou Intranet, conforme o caso).
4. Quando toda a funcionalidade estiver migrada:
   - O proxy roteia 100% para o Adapter.
   - O Adapter se comunica apenas com o Frequência.
   - A Intranet pode ser desligada.
5. **Opcionalmente**, quando a migração estiver estável, a EstaçãoPonto pode ser reconfigurada para apontar diretamente para o Adapter (eliminando o proxy).

### Por que não apenas o proxy?
Se o protocolo da Intranet for complexo (SOAP, RMI, ou binário), um proxy simples (Nginx) pode não conseguir fazer o roteamento inteligente baseado no conteúdo. O Adapter garante a tradução completa.

### Por que o Adapter em vez de replicar a interface no Frequência?
Manter a interface legada dentro do Frequência poluiria o domínio com código de compatibilidade. O Adapter é uma camada separada que pode ser descartada quando a EstaçãoPonto for atualizada ou descontinuada.

## Consequências

### Positivas

- Zero alterações na EstaçãoPonto durante toda a migração.
- Suporte completo ao Strangler Fig Pattern.
- Separação de responsabilidades: o Adapter lida com o "lixo" do protocolo legado; o Frequência mantém um design limpo.
- O Adapter pode ser descartado quando a EstaçãoPonto for substituída.

### Negativas / Trade-offs

- **Um serviço extra** (Adapter) para desenvolver e manter.
- **Complexidade de debug:** Se algo der errado, pode ser no proxy, no adapter, ou no Frequência.
- **Latência adicional:** Duas hops extras (Proxy → Adapter → Frequência) em vez de uma.
- **Risco de incompatibilidade:** Se o protocolo legado não for completamente compreendido, podem haver surpresas.

### Neutras

- O Adapter pode ser implantado no mesmo processo que o Frequência (como um middleware Rack) ou como um serviço separado. A decisão será tomada durante a implementação (ADR futuro).

## Compliance

- Nenhuma alteração na EstaçãoPonto sem autorização explícita do gestor do projeto.
- Toda requisição da EstaçãoPonto deve ser logada (request/response) durante a migração para auditoria.
- O Adapter deve ter testes de contrato contra o comportamento real da Intranet.

## Notas

- ADR-0002: Estratégia de Migração (Strangler Fig) — dependência.
- A engenharia reversa da EstaçãoPonto (Fase 1/2) precisa identificar o protocolo exato usado.
- Se o protocolo for HTTP/REST simples, o proxy pode ser suficiente e o Adapter pode ser simplificado.
