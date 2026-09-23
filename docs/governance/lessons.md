# Lições Aprendidas

> Registro de conhecimento operacional que emerge durante a implementação
> e que **não é coberto** pela documentação existente (iteration, quality, inception, ADRs).
> Ver skill `lessons-protocol` para critérios de registro.

---

### 2026-09-10 — Rolify `scopify` não cria scopes dinâmicos por nome de role

**Contexto:** Task 23.4 (Sprint 23) — instalação da gem rolify e configuração do model Role.
**Problema:** Assumi que `scopify` no model Role criaria scopes dinâmicos como `Role.admin`, `Role.gestor`, etc. (padrão que aparece em exemplos da gem). Os testes falharam com `NoMethodError` — um custo de ~30min de investigação.
**Solução:** `scopify` apenas estende o model com `Rolify::Adapter::Scopes`, habilitando 3 scopes fixos: `global` (roles sem resource), `class_scoped` (resource_type sem resource_id) e `instance_scoped` (resource_type + resource_id). Se precisar de `Role.por_nome`, defina um scope explícito ou use `Role.find_by!(name:)`.
**Lição:** Antes de testar métodos/semânticas de uma gem, leia o código-fonte da versão instalada — documentação e exemplos de blogs podem descrever versões/APIs antigas.

---

### 2026-09-10 — Rota customizada para controller Devise precisa de `devise_scope`

**Contexto:** Task 23.6 (Sprint 23) — mapeamento de `DELETE /logout` para `Users::SessionsController#destroy` (Devise).
**Problema:** Uma rota plain (`delete "logout", to: "users/sessions#destroy"`) quebrou com `NoMethodError: undefined method 'name' for nil` no destroy — `DeviseController#devise_mapping` lê `request.env["devise.mapping"]`, que só é setado por rotas geradas dentro de `devise_for`/`devise_scope`.
**Solução:** Envolver a rota em `devise_scope :user do ... end` (`constraints` interno que seta o mapping no request).
**Lição:** Toda rota que aponta para um controller Devise (mesmo action herdada) deve nascer dentro de `devise_scope :scope`, senão `devise_mapping` é nil e helpers como `resource_name` explodem com `nil.name`.

---

### 2026-09-10 — Coexistência sessão legada × Warden: skip `verify_signed_out_user` no destroy

**Contexto:** Task 23.6 (Sprint 23) — transição do login admin (`session[:user_id]`) para Devise/Warden.
**Problema:** Usuário logado pelo fluxo legado (só `session[:user_id]`, Warden vazio) não conseguia deslogar: o `verify_signed_out_user` (prepend_before_action) do `Devise::SessionsController#destroy` detectava "já deslogado" (Warden vazio) e abortava ANTES de limpar `session[:user_id]`.
**Solução:** `skip_before_action :verify_signed_out_user, only: :destroy` no controller custom + sincronizar `session[:user_id]` no `create` (via `super` com bloco) para que os dois mecanismos coexistam durante a transição.
**Lição:** Ao migrar de uma sessão manual para Devise em modo coexistência, o controller custom deve ser o ponto de sincronização — `verify_signed_out_user` assume que o Warden é a única fonte de sessão e aborta o logout em sessões legadas.

---

### 2026-09-21 — Ambiente real usa Ruby 3.4.2 (mise) apesar de `.tool-versions` apontar ruby-4.0.0 (missing)

**Contexto:** Task 24.1 (Sprint 24) — `bundle install` de novas gems no `Frequencia/api-ponto`.
**Problema:** `.ruby-version`/`.tool-versions` declaram `ruby-4.0.0`, mas o mise não tem essa versão instalada (`missing`); os docs do projeto citam "Ruby 4.0.0/Rails 8.0.4". Seguir as versões declaradas levaria a tentar instalar um Ruby inexistente ou a conclusões erradas de compatibilidade.
**Solução:** Verificar o ambiente real antes de qualquer comando: `bundle env` mostra Ruby 3.4.2 (mise) e `Gem Home`/`Gem Path` em `vendor/bundle/ruby/3.4.0` (config `path` em `~/.bundle/config`). Com isso, `bundle install`/`bundle exec` usam o vendor bundle correto; o Rails resolvido no lock foi 8.0.5 (satisfaz `~> 8.0.4`), sem conflito com as 4 gems novas (pagy 9.4.0, ransack 4.4.1, simple_form 5.4.1, zutils 4.0.0).
**Lição:** Antes de instalar gems, rodar testes ou avaliar compatibilidade no Frequencia, confira `bundle env` (Ruby real e Gem Home) — `.ruby-version`, `.tool-versions` e versões citadas nos docs podem estar defasados em relação ao ambiente executável.

---

### 2026-09-21 — `bundle exec rails` falha neste ambiente — usar os binstubs `bin/*`

**Contexto:** Task 23.10 (Sprint 23) — execução da suíte no `Frequencia/api-ponto` (Ruby 3.4.2 via mise, vendor bundle em `vendor/bundle/ruby/3.4.0`).
**Problema:** `bundle exec rails test`/`ruby -e` falham com `invalid switch in RUBYOPT: -e` (RuntimeError vindo do shim do mise/RubyGems wrapper), enquanto a lição anterior orientava usar `bundle exec`. `bundle env`, `bundle exec true` e `bundle exec rake` funcionam; o problema atinge o re-exec do `rails`/`ruby` pelo bundler.
**Solução:** Usar diretamente os binstubs do projeto: `bin/rails test`, `bin/rubocop <arquivos>`, `bin/rake` — todos funcionam e resolvem o bundle correto (`Bundler.setup` interno). Para validações pontuais de Ruby, evitar `bundle exec ruby -e` (falha) e rodar o script via `bin/rails runner` quando precisar do bundle.
**Lição:** No Frequencia, prefira SEMPRE `bin/*` (binstubs versionados no repo) a `bundle exec`; se um comando `bundle exec X` falhar com `invalid switch in RUBYOPT`, não investigue o shim — troque para `bin/X` e siga.

---

### 2026-09-23 — No ransack 4.4.x, os métodos `ransackable_*` são métodos de CLASSE, não de instância

**Contexto:** Task 24.6 (Sprint 24) — smoke test de carga conjunta das 4 gems; verificação de que a whitelist `ransackable_attributes` permanecia na gem (RN04 — whitelist real é escopo da Sprint 25).
**Problema:** `User.instance_method(:ransackable_attributes)` lançou `undefined method` erroneamente sugerindo que o método nem existia — na verdade ele existe, mas como método de classe (definido em `class << self` no `Ransack::Adapters::ActiveRecord::Base::ClassMethods`, `lib/ransack/adapters/active_record/base.rb`, com memoização `@ransackable_attributes ||=`).
**Solução:** Usar `User.method(:ransackable_attributes).source_location` para provar que a implementação vem da gem (e não de `app/models/`). Para a lista de atributos buscáveis: `User.ransackable_attributes` (sem instância).
**Lição:** Ao escrever testes de contrato sobre `ransackable_*` (whitelist, Sprint 25), consulte-os via método de classe (`Model.method(:ransackable_attributes)`/`Model.ransackable_attributes`), nunca `instance_method` — e lembre que a sobrescrita de whitelist também é em nível de classe.

---

### 2026-09-23 — Timing side-channel em endpoint `paranoid` do Devise: equalizar queries com phantom work, não tempo artificial

**Contexto:** Bug 10 (Sprint 23, 4ª rodada Bug Finder) — `POST /u/password` com `config.paranoid = true` e ActionMailer desmontado: email conhecido executa 5 queries e levanta/captura `NameError`; email desconhecido executa 1 query (SELECT miss). Delta de ~1-2ms permite enumerar contas por timing, mesmo com status/flash idênticos (B8/Bug 9).
**Problema:** Corrigir "dormindo" um tempo fixo (constant-time com `sleep`) adicionaria latência artificial a TODOS os requests legítimos e não replica a assinatura de I/O; a assinatura observável é o número/tipo de queries, não um tempo absoluto.
**Solução:** Phantom work no caminho mais barato: `Devise.token_generator.generate` (replica o SELECT por `reset_password_token` do caminho conhecido) + `transaction(requires_new: true)` com `update_all` em registro inexistente (`id = -1` → UPDATE de 0 linhas, SAVEPOINT/UPDATE/RELEASE). Resultado: mesma contagem de queries (5 = 5), zero dados alterados, sem latência artificial. Teste trava a invariante contando `sql.active_record` via `ActiveSupport::Notifications`.
**Lição:** Para neutralizar timing side-channel em endpoints paranoid, iguale a ASSINATURA DE I/O (queries), não o tempo com `sleep`; UPDATE em `id` inexistente é o "dummy write" inócuo perfeito (0 linhas, mesmas queries de transação). O custo do raise/rescue que não é replicado fica documentado como delta residual de µs.

---