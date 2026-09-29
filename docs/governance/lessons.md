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
---

### 2026-09-25 — Binstub `bin/brakeman` com `--ensure-latest` sai 0 sem escanear

**Contexto:** Tarefa 29.1 (Sprint 29) — validação de segurança registrada como "Brakeman OK" em três rodadas.
**Problema:** O binstub força `--ensure-latest`; com a gem instalada abaixo da última versão publicada, o Brakeman imprime só o aviso de versão e sai com código 0 **sem executar o scan** (nem `-o arquivo` é criado). O gate parece verde, mas não faz nada.
**Solução:** Até o chore de pipeline corrigir o binstub, validar com `RUBYOPT= bundle exec brakeman` (ou conferir que o relatório foi gerado) e registrar a contagem real de warnings (baseline: 4 pré-existentes).
**Lição:** Um gate de segurança só vale como evidência se produzir saída de scan (relatório/contagem de warnings); "exit 0" sozinho não prova execução.

---

### 2026-09-25 — Copiar trechos do schema.rb do Pessoas2 (Rails 6) para o Frequencia (Rails 8)

**Contexto:** Task 29.0 (Sprint 29), schema de teste do espelho Pessoas (ADR-0006).
**Problema:** Os `add_foreign_key` copiados literalmente falharam com `column "tipos_vinculo_id" referenced in foreign key constraint does not exist`. O `schema.rb` do Pessoas2 omite `column:` quando a coluna segue as inflexões **dele** (`tipos_vinculo` → `tipo_vinculo_id`); o Frequencia não tem essas inflexões e infere outro nome. Além disso, sem `ActiveRecord::Schema[6.0]` o Rails 8 cria `datetime` com precisão 6, diferente do banco real.
**Solução:** `column:` explícito em todas as FKs copiadas e `ActiveRecord::Schema[6.0].define`. O teste de divergência compara os blocos `create_table` byte a byte e as FKs por tabela e coluna.
**Lição:** Schema copiado entre apps com Rails e inflexões diferentes não é portável literalmente: fixe a versão de compatibilidade do `Schema[...]` e torne explícito tudo o que depende de inflexão. Obs.: o projeto usa Minitest 6, sem `minitest/mock` (`Object#stub` não existe); prefira dados reais ou injeção de dependência.

---

### 2026-09-29 — `bin/rails runner` em `RAILS_ENV=test` deixa lixo no banco de teste e falsifica o mutation testing

**Contexto:** Tarefa 29.2 (Sprint 29) — verificação manual independente do Bug 12 (`valid?` do model × `insert_all!` no banco) via `bin/rails runner` em `RAILS_ENV=test`.
**Problema:** O runner **não** roda dentro da transação do teste, então os registros criados persistem em `api_ponto_test`. `gestores_individuais` e `gestor_individual_gerenciados` **não têm arquivo de fixture**, logo `fixtures :all` (que faz DELETE + insert apenas das tabelas com fixture) não as limpa. O resultado foi 1 gestor e 2 vínculos órfãos apontando para `user_id=1` (os `users` de fixture são recriados com outros ids). Pior: na rodada de mutation testing seguinte, **todos** os testes falharam com `RuntimeError: Foreign key violations found in your fixture data` — 17 e 21 **erros** com 0 assertions, que pareciam mutações mortas mas eram só o banco sujo. Um mutation testing que "mata" a mutação por erro de carga não prova nada.
**Solução:** Limpar as tabelas sem fixture (`DELETE FROM` direto) antes de rodar a suíte; e, ao fazer mutation testing, **provar o baseline verde imediatamente antes de mutar** — uma mutação "pega" aparece como **1 falha limpa** (com assertions contadas), não como erro em massa com 0 assertions. Preferir `bin/rails test` com um teste dedicado (dentro da transação) a `bin/rails runner` para verificação de comportamento; se usar o runner, limpar depois.
**Lição:** Tabela sem arquivo de fixture não é limpa por `fixtures :all` — é estado persistente no banco de teste. Antes de confiar num resultado negativo de mutation testing, confira que o baseline estava verde e que a falha é `Failure` (com assertions), não `Error` de carga: sujeira de banco imita mutação morta.

---

### 2026-09-29 — `uniqueness` com `conditions:` valida o registro NOVO por inteiro: não espelha índice UNIQUE parcial

**Contexto:** Tarefa 29.2 (Sprint 29) — índice UNIQUE **parcial** em `(gestor_individual_id, user_id) WHERE ativo` (decidido para permitir histórico de re-vínculo) acompanhado da validação equivalente no model.
**Problema:** `validates :user_id, uniqueness: { scope: :gestor_individual_id, conditions: -> { where(ativo: true) } }` — o `conditions` filtra as linhas **existentes** na query, mas a validação continua rodando para **qualquer** registro novo, inclusive um que seja ele próprio inativo. Resultado: um vínculo novo `ativo: false` (histórico legado) era barrado com "User já está em uso" quando o par já tinha um ativo — **embora o índice parcial do banco o aceitasse** (`insert_all!` passava). Validação e constraint discordavam num quadrante, e os testes não cobriam esse lado (só testavam criar inativo quando *não* havia ativo).
**Solução:** `if: :ativo?` na validação, para que ela só rode quando o próprio registro é ativo — espelhando o predicado do índice. Cobrir os **4 quadrantes** pelos **dois lados** (validação Rails e `insert_all!`): ativo/ativo (barra), ativo/inativo (passa), inativo/ativo (passa — era o furo), inativo/inativo (passa).
**Lição:** Ao reproduzir um índice UNIQUE **parcial** em validação de model, o predicado do índice tem de valer para **ambos** os lados da comparação. `conditions:` só restringe o conjunto de linhas consultadas; quem decide *se* a validação roda é o `if:`/`unless:`. Índice parcial sem validação espelhada (ou vice-versa) gera divergência silenciosa que só aparece no quadrante não testado.

---

### 2026-09-29 — Validação de invariante deve rodar no EVENTO, não em todo save (senão "algema" o registro)

**Contexto:** Tarefa 29.2 (Sprint 29) — `validate :gestor_user_nao_e_gerido_ativo` em `GestorIndividual`, guardando o invariante "o login do gestor não pode ser um gerido ativo dele" (Bug 15).
**Problema:** a validação rodava em **todo** `save`. Quando um vínculo de auto-gerência "tardia" já estava persistido (criado por upsert/`insert_all!`, o caminho documentado da importação), o gestor virava um registro **inoperante**: `update!(nome:)`/`update!(orgao:)` e até `desativar!` (que usa `update!`) levantavam `RecordInvalid`, deixando `ativo=true` para sempre. O estado era **auto-perpetuante** — não havia caminho de recuperação pela aplicação (só `update_column`/SQL escapo). Um único dado ruim transformava o registro em intocável.
**Solução:** restringir o gatilho ao evento que muda o invariante: `validate :gestor_user_nao_e_gerido_ativo, if: -> { new_record? || will_save_change_to_gestor_user_id? }`. Renomear um gestor não cria nem desfaz auto-gerência, logo não deve revalidar. Efeito colateral positivo: elimina o `+1 SELECT` que a validação custava em todo save (o `exists?` só roda quando o login é (re)definido).
**Lição:** validação que depende de estado externo (outra tabela, associação) deve ser **event-scoped** (`will_save_change_to_X?` / `new_record?`). Rodá-la em todo save cria um modo de falha pior que o bug original: o registro fica impossível de corrigir pela própria aplicação. Sempre dê um caminho de recuperação in-app (aqui, `desativar!` precisava continuar funcionando) e teste explicitamente "edição de campo irrelevante ao invariante deve passar".

---

### 2026-09-29 — Invariante cruzando duas tabelas: os DOIS lados devem concordar sobre os 4 quadrantes de `ativo`

**Contexto:** Tarefa 29.2 (Sprint 29) — invariante de auto-gerência guardado em dois models (`GestorIndividual` e `GestorIndividualGerenciado`), porque um `CHECK` no Postgres não pode consultar outra tabela. O concern `Desativavel` centralizou `desativar!`/`ativo?`/`scope :ativos`, mas **não** alcança as validações de invariante — a regra ficou duplicada.
**Problema:** a correção do Bug 12 (`if: :ativo?` na validação de **par**) foi aplicada só de um lado. A validação de **auto-gerência do vínculo** ficou sem o filtro, então os dois lados **discordavam** sobre o mesmo vínculo inativo: o lado do gestor o ignorava (promover ex-gerido é legítimo desde o Bug 15) e o índice do banco também, mas o lado do vínculo o **barrava** — a importação da 29.3 falharia ao reconciliar o vínculo histórico via ActiveRecord, embora o banco o aceitasse (`insert_all!` OK). Três rodadas seguidas de Bug Finder acharam a mesma classe de bug, cada vez num eixo diferente (par, auto-gerência, agora entre os dois lados).
**Solução:** aplicar o mesmo `if: :ativo?` no lado do vínculo, fixando o invariante como *"nenhum vínculo ATIVO liga o gestor a si mesmo"* — idêntico nos dois models e no índice. Testar os **4 quadrantes de `ativo`** (ativo/ativo, ativo/inativo, inativo/ativo, inativo/inativo) **pelos dois lados** (validação Rails de cada model + `insert_all!` no banco).
**Lição:** ao guardar um invariante em mais de um ponto (validação de model A, validação de model B, constraint de banco), o único jeito de não gerar divergência silenciosa é declarar a regra **uma vez** e cobrir a matriz inteira nos dois lados. Divergência aparece sempre no quadrante que ninguém testou — e o caminho que falha é o da importação, não o do usuário.

---

### 2026-09-29 — `RecordInvalid#message` consulta `activerecord.errors.messages.record_invalid`, não `errors.messages.record_invalid`

**Contexto:** Tarefa 29.2 (Sprint 29), Bug 8 do Bug Finder — `e.message` de qualquer `ActiveRecord::RecordInvalid` do app saía como `"Translation missing: pt-BR.activerecord.errors.messages.record_invalid"`. O CTO promoveu a blocker da 29.3 (é a mensagem que o operador verá quando o upsert da importação falhar).
**Problema:** o palpite natural foi adicionar `record_invalid` em `errors.messages` (o bloco que o `pt-BR.yml` já tinha, com `blank`, `invalid`, `taken` etc.). Um teste que consultava `I18n.t("activerecord.errors.messages.record_invalid", default: nil)` **refutou o palpite**: retornava `nil`. O `ActiveRecord::RecordInvalid` consulta o namespace **`activerecord.`**; o `errors.messages.record_invalid` é apenas fallback do `ActiveModel`, e só funciona se o namespace específico não tiver a chave.
**Solução:** definir a chave **nos dois caminhos** para que concordem independentemente de qual seja consultado — `errors.messages.record_invalid` e `activerecord.errors.messages.record_invalid` (mais `restrict_dependent_destroy`, usada pelo `dependent: :restrict_with_exception`). Verificado em runtime: `e.message` passou a ser `"1 erro impediu este registro de ser salvo: Nome não pode ficar em branco"`.
**Lição:** ao consertar tradução "Translation missing", **não adivinhe o caminho da chave — leia-o da própria mensagem de erro** (ela imprime o caminho completo procurado) e **prove por teste** que a chave resolve com `I18n.t(caminho, default: nil)`. Namespaces de i18n têm fallback em cascata (`activerecord.` → `errors.`), e acertar só o fallback parece funcionar em uns pontos e falhar em outros.

---

---

### 2026-09-29 — Callback de validação NUNCA deve chamar `reload` na instância do chamador

**Contexto:** Tarefa 29.2-D7 (Sprint 29). O Code Reviewer achou que a validação de auto-gerência lia `gestor_individual.gestor_user_id` de uma instância possivelmente **stale** (carregada antes de outra instância salvar o login): `GestorIndividualGerenciado.new(gestor_individual: stale, ...)` gravava auto-gerência. O fix aplicado foi `gestor = gestor.reload if gestor.persisted?` dentro do callback.
**Problema:** o `reload` **muta o objeto do chamador** (`vinculo.gestor_individual.equal?(g) == true`) e **descarta mudanças pendentes**. No caminho normal de escrita (carregar o gestor → resolver o login **sem salvar** → gravar o vínculo — exatamente o fluxo da importação), o `reload` apagava o `gestor_user` recém-atribuído, a validação lia `nil` do banco e o código **gravava um vínculo de auto-gerência ATIVA**: `vinculo.save => true`, `g.changed == []`, auto-gerência no banco. O fix de um falso-positivo criou um falso-negativo **pior** — auto-autorização persistida na cascata da 29.4/29.5. Efeito colateral adicional: atributos pendentes (`nome`, `orgao`) também eram perdidos silenciosamente.
**Solução:** ler o valor do outro lado **sem recarregar a instância** — somar o valor **em memória** (`gestor.gestor_user_id`, cobre o login pendente do chamador) e o valor **no banco** via `Model.where(id:).pick(:coluna)` (cobre o login salvo por outra instância; `pick` não instancia nem muta nada). Custo: 1 query por validação, o mesmo do `reload`. Brinde: `pick` devolve `nil` para registro ausente, eliminando um `ActiveRecord::RecordNotFound` cru que o `reload` levantava quando o gestor fora apagado por outra sessão.
**Lição:** **`reload` dentro de callback de validação é sempre suspeito.** Validação deve ser observadora — não pode mutar o objeto que está sendo validado nem os que recebeu. Quando o invariante precisa "ver o outro lado atualizado", leia o valor com uma query pontual (`pick`/`where(...).exists?`) em vez de recarregar a instância. Testar sempre os dois cenários opostos: valor **pendente em memória** e valor **salvo por outra instância** — um fix que resolve só um dos lados troca o bug de sinal.

---
