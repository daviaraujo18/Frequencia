# Pessoas — Análise Inicial da API para Integração com Frequência

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Análise técnico-arquitetural do sistema **Pessoas** (`pessoas2/`) como fonte de dados cadastrais para o Frequência (conforme ADR-0001). Valida se já há API exposta, qual o nível de maturidade, e o que precisa ser construído/adaptado.

> **CONTEXTO:** Frequência precisa de dados cadastrais dos servidores (matrícula, nome, lotação, cargo, situação funcional, eventualmente foto). O ADR-0001决定foi por **API REST + Eventos**, NÃO compartilhamento de banco. Esta análise confirma ou desafia essa decisão.

## Maturidade do Projeto

**Muito alta.** O sistema Pessoas é um projeto Rails completo, com **270+ controllers** individuais (listados em `pessoas2/app/controllers/`), Gemfile com `sticapi_client`, Devise, Sidekiq, Crono,RSpec/Cucumber, kamal, ActiveStorage, paper_trail, acts_as_tenant, esocial integration.

## Endpoints Relevantes Disponíveis (valida ADR-0001)

> **EVIDÊNCIA:** `pessoas2/config/routes.rb` (939 linhas)

| Endpoint | Método | Função | Relevância Frequência |
|----------|--------|--------|----------------------|
| `/utils/pessoas` | GET/POST | Busca pessoa por CPF/nome (autocompletes) | 🟡 Auxiliar |
| `/utils/pessoas_da_ativa` | GET | Pessoas com vínculo ativo (`.da_ativa` scope) | 🟢 **Crítico** — substitui listagem de frequentadores |
| `/utils/vinculos_efetivos` | GET/POST | Vínculos efetivos por CPF/nome | 🟡 Auxiliar |
| `/utils/pessoa_info` | GET | Busca dados via Intranet (`SticapiClient::Intranet`) | 🟡 Acoplamento com Intranet — ver NOTA |
| `/utils/find` | POST | Busca genérica por model — **FORA DE ESCOPO** pois expõe qualquer model via `Kernel.const_get` (risco de segurança) | 🔴 NÃO usar |
| `pessoas/:id/json_vinculos` | GET | JSON de vínculos da pessoa | 🟡 |
| `pessoas/:id/ficha_funcional` (em `vinculos` ou `pessoas`) | GET | Ficha funcional | 🟡 Algumas rotas |
| `pessoas/:id/foto_biometria` | GET | **Foto biométrica** da pessoa | 🟢 Crítico para display na estação |

> **🤔 DÚVIDA:** `/utils/find` (linha 49-55 do `utils_controller.rb`) é uma busca genérica de qualquer model passando o nome como parâmetro — falha de segurança potencial. **Não usar** para integração Frequência ↔ Pessoas. Provavelmente será desativado ou autenticado.

## Modelo `Pessoa` — Campos Disponíveis

> **EVIDÊNCIA:** `pessoas2/app/models/pessoa.rb` (1067 linhas) e `db/schema.rb`

Atributos diretamente em `pessoa`:
- `cpf` (NF, unique, presença)
- `nome` (NF, presença)
- `nascimento` (validado)
- `username` (vinculado a `User`)
- `foto` (ActiveStorage attached) — foto 3x4 com crop
- `foto_biometria` (ActiveStorage attached) — **foto biométrica** (não é fingerprint/digital!)
- `foto_biometria_binario` (binary column — armazenamento adicional)
- `sexo_id`, `raca_id`, `estado_civil_id`, `grau_instrucao_id`, etc. (belongs_to)
- `email_institucional` (has_one)

**Importante — NÃO existe `digitais_hash` no Pessoas.** Esse dado é da estação Nitgen (FIR format), e fica ou na Intranet (legado) ou na futura tabela do Frequência. **NÃO será migrado para o Pessoas** (não é dado cadastral).

## Modelo `Vinculo` — Campos Disponíveis

> **EVIDÊNCIA:** `pessoas2/app/models/vinculo.rb:165-489`

- `matricula` (string, uniqueness validado)
- `matricula_esocial` (string, uniqueness)
- `inicio`, `fim` (datas do vínculo)
- `pessoa` (belongs_to), `cargo` (belongs_to), `cargo_magistrado` (belongs_to)
- `configuracao_cadastro` → `tipo_vinculo` (chain de TIPO do vínculo — decisivo para "da ativa" ou não)
- `lotacoes` (has_many) → controla lotação atual do servidor
- `vinculo_estado` (belongs_to) — estado atual (e.g. "em_exercicio", "homologado")
- `vinculos_vantagens` (has_many) — gratificações
- `afastamentos` (has_many) — **dado crucial para a EstaçãoPonto atualizαr digitais conforme afastamentos**
- `cargo`, `cargo_magistrado`, `unidade_ativa` via lotação

Scopes úteis já implementados (em `Pessoa` e acessíveis via `Vinculo`):
- `Pessoa.da_ativa` → pessoas com vínculo da ativa ( cobertura do Pessoas para consultas do Frequência)
- `Pessoa.com_vinculo_ativo_presente_intranet` → pessoas presentes na Intranet com vínculo ativo
- `Pessoa.com_vinculo_ativo_da_ativa_presente_intranet` → ainda mais restritivo

## ⚠️ Descoberta Crítica — `SticapiClient::Intranet`

> **EVIDÊNCIA:** `pessoas2/app/controllers/utils_controller.rb:61-95` (`pessoa_info` action)

O Pessoas **ainda consome a Intranet legada** via gem interna `sticapi_client` (v3.5.3). Em `utils/pessoa_info`, o Pessoas busca dados na Intranet via:

```ruby
pessoas = SticapiClient::Intranet.pessoa_info(cpf: ...)
pessoas = SticapiClient::Intranet.pre_pessoa_info(cpf: ...) unless pessoas.any?
```

O `SticapiClient::Intranet.unblock_user` e `block_user` também são chamados (linhas 561-566 do `pessoa.rb`) para ativar/desativar usuários na Intranet.

### Implicações para a Migração

1. **🔒 ADR-0001 ganha reforço:** A gem `sticapi_client` é um **wrapper** que o Pessoas usa para chamar a Intranet. Quando a Intranet for desligada, esse wrapper precisará ser refatorado ou removido — mas é problema do Pessoas, não do Frequência. O Frequência se integra com Pessoas via API **do Pessoas**, NÃO se acopla à Intranet.

2. **🟡 Pendência futura:** Quando a Intranet for desligada, o `SticapiClient::Intranet` precisará ser substituído — possivelmente herdandoesses endpoints no Frequência (e.g. `unblock_user` no Frequência com API Pessoas para autenticação). **Não é prioridade agora**, mas é uma dívida a rastrear.

3. **🟢 Recomenda-se expor endpoints no Pessoas** explicitamente para o Frequência (ver seção "Próximos Passos" abaixo), em vez de usar o `utils_controller` que é para UI.

## Riscos

- ⚠️ `utils_controller.rb` é voltado para UI interna (busca autocomplete, JSON para select2). **Não é API canônica**. Para Frequência ↔ Pessoas, é recomendável criar namespace `/api/v1/...` no Pessoas dedicado a integrações externas.
- ⚠️ `Pessoa.da_ativa` depende de `tipos_vinculo: { vinculo_da_ativa: true }` — flag configurada por tipo de vínculo. Precisamos validar se TODOS os servidores que batem ponto têm um `tipo_vinculo` marcado como `vinculo_da_ativa: true`. Caso contrário, o Frequência não conseguirá listá-los via este scope.
- ⚠️ `SticapiClient::Intranet` ainda ativo — dívida para quando a Intranet for desligada (`unblock_user`, `block_user`, `pessoa_info`, `pre_pessoa_info`).
- ⚠️ Autenticação de API: `routes.rb` mostra `devise_for :users, path: "u"` — todas as rotas estão implicitamente autenticadas. Para Frequência consumir, será necessário expor endpoints via token (e.g., JWT) ou incluir uma auth separada para service-to-service.

## Decisão Recomendada (não ADR ainda)

Não mudar ADR-0001, mas registrar uma **expansão** em ADR futuro (ex. ADR-0006 "API Pessoa→Frequência: Exposição e Contrato") que defina:

1. **Criar no Pessoas** um namespace `/api/v1/integracoes/...` para uso externo (service-to-service), autenticado com token/jwt.
2. **Endpoints mínimos a criar/adaptar no Pessoas:**
   - `GET /api/v1/servidores_ativos` → substitui teoricamente o `DynFrequentadoresEstacao` da Intranet
   - `GET /api/v1/servidores/:cpf` → dados cadastrais individuais
   - `GET /api/v1/servidores/:cpf/vinculo_ativo` → matrícula, cargo, lotação atual, situação funcional
   - `GET /api/v1/servidores/:cpf/foto_biometria` → foto para display na estação (substitui foto cache da Intranet)
   - **Event stream:** webhook ou tópico para mudanças cadastrais (lotação, cargo, situação) — Frequência atualiza cache local
3. **Contrato do cache local no Frequência** (model `ServidorCache` em `app/infrastructure/`):
   - `pessoa_id`, `cpf`, `matricula`, `nome`, `cargo`, `lotacao`, `situacao_funcional`, `foto_url`, `updated_at`, `pessoas_event_id`
   - TTL opcional + invalidação por evento

## Próximos Passos

1. Confirmar com o gestor do Pessoas se o padrão `Pessoa.da_ativa` cobre todos os frequentadores esperados (validação de dados reais).
2. Abrir pendência para criar namespace `/api/v1/integracoes/` no Pessoas (não no Frequência) — será um ADR-0006 depois da Fase 1 detalhada da Intranet.
3. Em paralelo à Fase 1 da Intranet, mapear **que campos da `Pessoa`/`Vinculo` correspondem ao retorno legado** de `DynFrequentadoresEstacao`:
   - Legado retorno: `<id>;<matricula>;<nome>;<digitalHash>;;false;N;0`
   - Pessoas equivalente: `pessoa.id`, `vinculo.matricula`, `pessoa.nome`, `??? (digitalHash)`, `false (isAdmin)`, `sexo.codigo` (campo "N" no legado = não informado), `lotacao.unidade.id` (predioId)
   - `digitalHash` **NÃO existe no Pessoas** — continua sendo/storage do Frequência

--
**Última atualização:** 2026-08-04
**Refs:** ADR-0001 (`docs/adr/0001-integracao-pessoas-frequencia.md`), `docs/06-integracoes/` (virá)
