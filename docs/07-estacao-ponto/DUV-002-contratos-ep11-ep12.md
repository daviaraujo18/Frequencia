# DUV-002 — Contratos dos endpoints EP-11 (`Frequentador`) e EP-12 (`ProblemaRegistro`)

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-04) — ver `## Resolução`

## Dúvida

O PRD (`PRD-POC-API-PONTO.md`) e a documentação da EstaçãoPonto (`documentacao-estacao-ponto.md`) **não detalham** o contrato (parâmetros, formato de resposta, finalidade) dos endpoints:
- `GET /presenca/Frequentador` (EP-11)
- `GET /presenca/ProblemaRegistro` (EP-12)

No entanto, ambos aparecem declarados em `routes.rb` da PoC (`api-ponto/config/routes.rb`).

## Origem

- `07-estacao-ponto/02-endpoints-consumidos.md:114`

## Por que importa

- Precisamos saber o que a EstaçãoPonto espera (ou se a EstaçãoPonto sequer chama esses endpoints) para garantir compatibilidade total do Adapter (ADR-0003).
- Se a EstaçãoPonto não os chama, podem ser descartados do Matamento obrigatório.

## Ações de Investigação

- [ ] Ler implementação na PoC: `git show HEAD:api-ponto/app/controllers/presenca/frequentador_controller.rb` e `.../problema_registro_controller.rb`.
- [ ] Procurar referência nos fluxos da EstaçãoPonto (`documentacao-estacao-ponto.md`) se esses endpoints são usados.
- [ ] Confirmar com a Intranet legada o que esses endpoints fazem hoje.

## Resolução

**Resolvida por inspeção da PoC (git HEAD de `frequencia/`) e do código da EstaçãoPonto (2026-08-04).**

**1) Conceito-chave:** `Frequentador` e `ProblemaRegistro` **NÃO são APIs JSON** consumidas pela EstaçãoPonto — são **páginas HTML embutidas** carregadas no WebEngine JavaFX (telas exibidas ao usuário na interface da estação).

**2) Implementação na PoC (stubs placeholders):**
- `GET /presenca/Frequentador` → `app/controllers/presenca/frequentador_controller.rb#show` retorna HTML placeholder (`<h1>Frequentador</h1><p>Tipo: #{params[:type]}</p>`), sem lógica real.
- `GET /presenca/ProblemaRegistro` → `app/controllers/presenca/problema_registro_controller.rb#show` retorna `"OK"` (string fixa).
- Rotas: `api-ponto/config/routes.rb:13,15` dentro do `namespace :presenca`.

**3) Uso real na EstaçãoPonto:**
- **EP-11 `Frequentador`** (`IntranetURLs.CADASTRO_FREQUENTADOR = /presenca/Frequentador?type=create`):
  - `view/TelaPonto.java:94` — `webEngine.load(...Frequentador?type=explore)` (tela de explorar frequentadores).
  - `listeners/ChangeUrlListener.java:39-49` — intercepta `Frequentador?type=create` (ativa botão "Cadastrar Digital") e `?type=update` (ativa "Atualizar Digital"). É uma **tela de cadastro/atualização de digital** do frequentador.
- **EP-12 `ProblemaRegistro`** (`IntranetURLs.PROBLEMA_REGISTRO = /presenca/ProblemaRegistro`):
  - `listeners/Operacao.java:94` — `webEngine.load(PROBLEMA_REGISTRO)` é carregado quando o código de ativação/registro da máquina **não é reconhecido** (fluxo `RECUPERAR_CODIGO_ATIVACAO`, else l.92-94). É uma **tela de erro** exibida ao usuário quando a estação não está registrada.

**4) Decisão para a migração:**
- Não são contrato sensível para a **batida de ponto** (que usa `PontoDePresenca`).
- Para **compatibilidade total de UX** do Adapter, o Frequência deve servir **páginas HTML mínimas** que réplicam:
  - `Frequentador` — tela de explorar/cadastrar/atualizar frequentador+digital (o placeholder da PoC não permite fluxo de cadastro funcional);
  - `ProblemaRegistro` — tela de erro de registro.
- Marcar como **dívida de feature** (ADR-0005/0004) — não bloqueia a fase inicial de integração de batida.

**Referências:** `docs/07-estacao-ponto/02-endpoints-consumidos.md:114`, ADR-0003, ADR-0005.
