# DUV-001 — Segurança do endpoint `/utils/find` no Pessoas

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Status

RESOLVIDA (2026-08-04) — ver `## Resolução`

## Dúvida

O endpoint `POST /utils/find` (em `pessoas2/app/controllers/utils_controller.rb:49-55`) é uma busca genérica que usa `Kernel.const_get(params['model'])` para recuperar qualquer model a partir do parâmetro de URL. Isso parece uma **vulnerabilidade de segurança** (falha de autorização / exposição indevida de qualquer tabela).

```ruby
def find
  valores = nil
  valores = Kernel.const_get(params['model']).all unless params['model'].blank?
  campos = nil
  campos = Kernel.const_get(params['model']).column_names.sort - ['id', 'created_at', 'updated_at'] unless params['model'].blank?
  render json: { valores: valores, campos: campos }
end
```

## Origem

- `08-pessoas/01-analise-inicial.md:28`

## Por que importa

- **Não usar** como integração Frequência ↔ Pessoas.
- Potencial falha de segurança (qualquer model pode ser enumerado/exibido sem autorização).
- Pode precisar de correção imediata ou ao menos não ser utilizado como API.

## Hipóteses de Resposta

1. É usado apenas em admin interno e já é autenticado/autorizado por `authenticate :user` + autorização de controller.
2. É legado e será desativado.
3. É uma falha real a corrigir.

## Como Resolver

- [ ] Verificar autenticação/autorização do `UtilsController` (ApplicationController / roles).
- [ ] Confirmar com o time do Pessoas o uso pretendido.
- [ ] Decidir: desativar, restringir a whitelist de models, ou criar API canônica separada (ver ADR-0006).

## Resolução

**Resolvida por inspeção de código (2026-08-04).**

- **Rota:** `pessoas2/config/routes.rb:899` → `post "utils/find", to: "utils#find"`.
- **Autenticação:** `UtilsController < ApplicationController` que tem `before_action :authenticate_user!` (`app/controllers/application_controller.rb:15`) via Devise → **é necessário login válido**.
- **CSRF:** `protect_from_forgery with: :exception` + `skip_before_action :verify_authenticity_token` (l.14-16 do ApplicationController) → **token CSRF não é exigido**.
- **Autorização:** o `UtilsController` **não** tem `load_and_authorize_resource` nem chamada específica a `authorize!`/CanCan; o único guard é a autenticação. Nenhum `skip_before_action`/`only` no controller.
- **Vulnerabilidade confirmada (mas mitigada pelo login):** `Kernel.const_get(params['model']).all` (utils_controller.rb:51-53) permite a **qualquer usuário autenticado** enumerar/expor `.all` de **qualquer model** da aplicação, sem autorização por role. Não há whitelist de models.

**Decisão para a migração:**
1. **NÃO usar** `/utils/find` como integração Frequência ↔ Pessoas (confirmado o risco de autorização). Vale também para `/utils/pessoa_info` (acoplado à Intranet via `SticapiClient::Intranet`).
2. Seguir o **ADR-0006** (proposto): criar namespace canônico `/api/v1/integracoes/` no Pessoas com endpoints específicos + token/JWT.
3. Recomendar ao time do Pessoas corrigir `/utils/find` (whitelist de models ou remover) — fora do escopo do Frequência.

**Referências:** `docs/01-inventario/00-indice.md`, ADR-0006, `docs/08-pessoas/01-analise-inicial.md:28`.
