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

---

### 2026-09-29 — Config lida só de credentials quebra em CI limpo (o `master.key` não é versionado)

**Contexto:** Tarefa 29.2 (Sprint 29), débito B1 do review final. O CI precisa do banco do espelho `frequencia_pessoas_espelho_test`, e o bloco `pessoas` do `config/database.yml` lia `Rails.application.credentials.dig(:pessoas_db, ...)` para host/usuário/senha/porta.
**Problema:** o `credentials.yml.enc` é versionado, mas o `master.key` **não** (corretamente ignorado). Em CI limpo — ou em qualquer máquina sem a chave — `credentials.dig(:pessoas_db, :username)` devolve `nil`, o Postgres recebe **usuário vazio** e a conexão falha **antes de qualquer teste rodar**, com um erro que parece problema de banco e não de configuração. O bloco `pessoas` era o único do arquivo sem fallback por ENV.
**Solução:** `ENV.fetch("PESSOAS_DB_*", Rails.application.credentials.dig(...))` — ENV com precedência, credentials como fallback. Mesmo padrão que o próprio arquivo já usava no bloco `intranet_*` (produção). Verificado nos dois sentidos: sem ENV conecta como o usuário das credentials; com ENV, o usuário passa a ser o da variável (a sobreposição funciona).
**Lição:** **credencial que só existe em `credentials.yml.enc` é um beco sem saída em CI.** Todo bloco de `database.yml` que precise rodar em runner limpo deve aceitar override por ENV (`ENV.fetch("X", credentials...)`). Ao adicionar um serviço externo à suíte, teste o caminho "sem `master.key`" — é o cenário do CI, e ele falha de um jeito que se disfarça de problema de banco.

---

### 2026-09-29 — Suíte que depende de banco auxiliar não preparado: `skip` explícito em vez de erro de conexão

**Contexto:** Tarefa 29.2 (Sprint 29). Os testes do espelho Pessoas (`test/support/pessoas_espelho_helper.rb` e 3 arquivos que o incluem) leem um banco separado (`frequencia_pessoas_espelho_test`) com schema carregado à parte (`RAILS_ENV=test bin/rails test:pessoas_schema:load`).
**Problema:** sem esse banco — CI limpo, máquina nova, clone recém-feito — os testes explodiam com `PG::UndefinedTable`, **19 erros** que pareciam falha de código. Um erro de conexão esconde o problema real ("falta um passo de setup") e polui o sinal da suíte; um amigo desenvolvedor conclui que "a suíte está quebrada".
**Solução:** guarda `skip_sem_espelho!` chamada no `setup` dos testes afetados: se a conexão falhar ou as tabelas não existirem, `skip` com o comando exato do setup na mensagem. Verificado: com as tabelas removidas → **19 skips, 0 erros**; com o banco → roda normalmente, **0 skips**. O `skip` mantém o sinal honesto de cobertura.
**Lição:** teste que depende de banco/serviço auxiliar deve detectar a ausência e **pular com o motivo**, nunca estourar erro de infraestrutura. `skip` aparece no relatório e diz o que fazer; `PG::UndefinedTable` parece bug. Combine com o preparo correto no CI — o skip é rede de segurança, não substituto do setup.

---

### 2026-09-29 — Validação de auth do Postgres em CI tem de rodar no CONTAINER: o `pg_hba` local (`trust`) engana

**Contexto:** Bloco de esteira da Sprint 29 — passo "Create the Pessoas mirror test database" do `ci.yml` + bloco `pessoas` de test do `database.yml`. A "correção do falso-verde" havia sido validada **na máquina do dev**, onde "com ENV o usuário passou a ser o da variável" foi tido como prova suficiente de que o setup funcionaria no runner.
**Problema:** a validação no dev usou o `.pg_hba.conf` **local**, que tem `trust` no loopback e **não exercita** a rota de rede nem a auth do runner. A imagem oficial do Postgres (`postgres`/`postgres:17`) aplica, após o entrypoint, `host all all all scram-sha-256` — as linhas `trust` de loopback do initdb são substituídas. Conexões do runner chegam pelo bridge como `172.17.0.1` (comprovado com `inet_client_addr()`), ou seja, caem na regra **scram**. Resultado: a role `app.frequencia` criada **sem senha** (`CREATE ROLE ... LOGIN`, `rolpassword = NULL`) + `PESSOAS_DB_PASSWORD: ""` faziam o `test:pessoas_schema:load` abortar com `fe_sendauth: no password supplied` (**EXIT=1**). O CI estava **vermelho como escrito** e a falha só apareceria no primeiro push — a etapa "antes" nunca tinha sido executada num runner.
**Solução:** re-validar a sequência (`CREATE ROLE` → `createdb` → `test:pessoas_schema:load`) **dentro de um container `postgres:17` oficial**, com o env exato do CI. A correção escolhida foi a de menor superfície: dar senha explícita à role (`CREATE ROLE "app.frequencia" LOGIN PASSWORD 'app'`) e passar a mesma em `PESSOAS_DB_PASSWORD`. Após a correção: `db:test:prepare` EXIT=0, `test:pessoas_schema:load` EXIT=0 e os testes do espelho **19 runs/68 assertions/0 skips** contra o container. `POSTGRES_HOST_AUTH_METHOD: trust` também resolveria, mas trocar a auth do cluster inteiro é superfície maior que a senha de uma role.
**Lição:** **a máquina do dev não é o CI.** Validação de esteira que dependa de auth de Postgres, rota de rede ou preparo de banco auxiliar deve ser executada num container oficial **equivalente ao `services:` do workflow** (mesma imagem, mesmas ENV), lendo as conexões pelo bridge — o `trust` do loopback local esconde exatamente o caso `scram-sha-256` que o runner impõe. Corrija a auth preferindo a mudança de menor superfície (senha da role, não a auth do cluster) e mantenha o gate `psql ... | grep -q 1` sem `|| true` — ele é o que impede o CI de ficar verde sem preparar o banco.

---

### 2026-09-29 — Código de saída de ferramenta com precedência interna pode MASCARAR a checagem que você ligou (Brakeman: exit 3 esconde 8/9)

**Contexto:** Chore do fork do CI (Sprint 29). O ruling M2 ligou as flags anti-drift `--ensure-ignore-notes` (exit 8) e `--ensure-no-obsolete-ignore-entries` (exit 9) no `bin/brakeman` para tornar o ledger `config/brakeman.ignore` um registro auditável. As flags estavam **corretamente injetadas** e provadas funcionais — em isolation.
**Problema:** no Brakeman 8.0.5, `Commandline#regular_report` avalia `exit_on_warn` (exit 3) **antes** das checagens anti-drift (`commandline.rb:150` vs `:158`/`:163`). Com **qualquer** warning não-ignorado vivo (o `Medium` EOLRails, time bomb do bump), o processo **sempre** sai 3 — e o sinal da política some: nota vazia → 3 (esperado 8), entrada obsoleta → 3 (esperado 9). As **mensagens** eram impressas, só o **código** era mascarado. Efeito: um ledger com nota faltando ou entrada obsoleta **passava despercebido** — a salvaguarda ficava cega exatamente por causa do warning que ela não deveria silenciar. Isso só apareceu **após** dar sinal aos exits manualmente (mutando o ledger e medindo o código); a leitura do código do binstub não bastava.
**Solução:** o binstub passou a capturar a saída, reemití-la verbatim e promover o exit ao código **prescrito** (8/9) quando detecta o padrão de falha de política — sem remover o EOLRails do scan (`-x`/`--no-exit-on-warn` seriam silenciadores). Cuidado de implementação crítico: o `ensure` do wrapper não pode engolir exceção — a primeira versão capturava só `SystemExit` e um crash inesperado cairia no `ensure` com `exit(real_exit=0)`, virando **verde-por-engano** (o anti-padrão da sprint); a versão final tem `rescue StandardError => real_exit=1`.
**Lição:** **flag ligada ≠ flag com sinal.** Antes de confiar num código de saída como gate, **mutar a condição que ele detecta e medir o exit real** — não inferir da leitura do código. Quando uma ferramenta tem precedência interna entre códigos de saída, códigos de menor prioridade ficam inalcançáveis justamente no estado normal (com outros warnings presentes). Ao escrever um wrapper que reatribui exit codes, garanta que o caminho de exceção **preserve fail-safe** (nunca 0).

---

### 2026-09-29 — Fork de CI para outro provedor: medir o registry/imagem alvo, e não criar a branch de `develop` cegamente quando o fork depende de trabalho não-mergado

**Contexto:** Chore de fork do CI do Frequencia (GitHub Actions → GitLab, remote de produção). Dois tropeços concretos.
**Problema 1 (imagem):** o modelo `pessoas2/.gitlab-ci.yml` usa `registry.gitlab.tjpi.jus.br/...`, mas o registry institucional **não resolve fora da rede da instituição** (`Could not resolve host`, medido) e não havia imagem publicada para a versão real do Ruby do projeto. Copiar o modelo cegamente daria um CI que não baixa a imagem.
**Problema 2 (branch base):** o protocolo AGILE manda criar a chore a partir de `develop`. Mas o `.gitlab-ci.yml` referencia flags (`--ensure-ignore-notes`), o ledger `config/brakeman.ignore`, o passo do banco espelho no `ci.yml` e o `ENV.fetch` do bloco `pessoas` — **tudo isso só existe** na branch de feature da sprint (19 commits à frente de `develop`; `develop` não tem nenhum). Criar de `develop` geraria um CI que chama flags/arquivos inexistentes.
**Solução:** (1) documentar a imagem real como dívida e usar `ruby:3.3.8-slim` (versão **medida**, não a `.ruby-version` que dizia `4.0.0` inexistente); (2) criar a branch a partir do HEAD da feature e **registrar o desvio** com o merge target correto (`feature/demanda-29-...`, não `develop`). Também: o fork **torna visível** o débito pré-existente de lint (RuboCop exit 1, 77 offenses em 17 arquivos) — não mascarar com `|| true`; registrar como débito.
**Lição:** ao fork-ar CI entre provedores, **valide a imagem/registry de destino por execução** (não por cópia do modelo) e **verifique a base da branch** contra o que o artefato referencia — um fork é acoplado a tudo que ele invoca. Se o protocolo manda `develop` mas a dependência não está lá, o desvio é a decisão correta, **desde que registrado** (merge target explícito). E um fork que ativa gates adormecidos revela débito pré-existente: o certo é **torná-lo visível e rastrear**, nunca silenciar.

---

### 2026-09-29 — Fork de CI: um gate vermelho num stage ANTERIOR impede o stage seguinte de rodar (fail-fast do GitLab)

**Contexto:** Chore do fork do CI (Sprint 29). O `.gitlab-ci.yml` tinha 3 stages sequenciais `security` (Brakeman, exit 3 por design — `Medium` EOLRails) → `quality` (RuboCop, exit 1 por 77 offenses pré-existentes) → `test` (o OBJETIVO da chore: criar o banco espelho + rodar a suíte).
**Problema:** por default o GitLab é **fail-fast** — "if any job fails, the pipeline is marked as failed and jobs in later stages do not start". Como os dois primeiros saem vermelhos (débito pré-existente que o próprio fork tornou visível), o stage **`test` NUNCA executava**. O pipeline ficava vermelho e o passo que a chore existia para entregar nem rodava: o objetivo declarado **não era atendido**, e o modo de falha era invisível ("parece que o CI existe, mas o test não roda"). Antes de existir `.gitlab-ci.yml`, o problema também não aparecia — foi o fork que o criou.
**Solução:** `allow_failure: true` em `security` e `quality` (o job RODA, a saída fica no log, só não bloqueia a esteira), com DONO + PRAZO + critério binário de remoção registrados. **Verificado nos dois sentidos** com `gitlab-ci-local@4.75.1` (engine que implementa a semântica do GitLab): com `allow_failure` → `test` executa (marker presente, pipeline 0); sem → `test` não executa (pipeline 1). O arquivo real passou no `json schema validated`.
**Lição:** **ao projetar um pipeline multi-stage, o estado de saída dos jobs ANTERIORES é parte do contrato do job que você quer garantir.** Um gate vermelho "conhecido" num stage inicial não é só um vermelho a mais: ele **desliga silenciosamente** todos os stages seguintes. Ao criar/forçar um CI que ativa gates adormecidos, sempre pergunte "o que roda DEPOIS dos gates que vão falhar, e ele ainda roda?" — e prove com a semântica de fail-fast (ou por `allow_failure` consciente, ou por `needs: []`). `allow_failure` num scan de segurança só é honesto com dono, prazo e critério de remoção explícitos; senão vira papel de parede.

---

### 2026-09-29 — Fork de CI: `localhost` NÃO alcança o `services:` no executor docker do GitLab (services resolvem por ALIAS; não há forwarding de porta)

**Contexto:** Chore do fork do CI (Sprint 29). O `.gitlab-ci.yml` foi adaptado do `ci.yml` de GitHub e manteve `localhost` em `pg_isready`, `psql` e `createdb`. O `ci.yml` de GitHub funciona com `localhost` porque declara `ports: 5432:5432` no service — **é a publicação de porta que faz `localhost` funcionar lá**. Essa linha **não foi carregada** para o GitLab.
**Problema:** no executor docker do GitLab, os `services:` são publicados na rede do runner e resolvidos por **hostname/alias** (a diretiva `alias:`), **sem forwarding de porta para `localhost`**. No primeiro job real, `until pg_isready -h localhost` **pendura o job até o timeout** e o `test` nunca roda — o exato objetivo da chore. O `alias: postgres` estava declarado e **não usado**. Junto disso, faltavam `DATABASE_URL` (o `test.primary` não tem host/usuário no `database.yml`; sem a URL o `db:test:prepare` falha EXIT=1) e `PGPASSWORD` (contra a imagem oficial `scram-sha-256`, `createdb` trava no prompt e `psql` nega).
**Solução:** usar o **alias** (`-h postgres`, `DATABASE_URL=...@postgres:5432`, `PESSOAS_DB_HOST=postgres`) e trazer `DATABASE_URL` + `PGPASSWORD` do `ci.yml`. **Provado com Docker real**: rede própria + `--network-alias postgres` + `postgres:17` **sem publicar porta** + container `ruby:3.3.8-slim` na mesma rede → `localhost:5432` recusado (`pg_isready` EXIT=2), `postgres:5432` ok (EXIT=0). A sequência completa do job (`pg_isready` → role → `createdb` → `grep -q 1` → `db:test:prepare` → `test:pessoas_schema:load` → espelho 19/68/0) ficou toda verde por alias.
**Lição (duas):**
1. **`gitlab-ci-local` NÃO expõe este bug** — ele publica as portas em `localhost`, semântica divergente do executor docker real. A prova anterior passou e **não valia** para este aspecto. Para semântica de rede de services, a prova tem de ser **Docker real com rede própria e sem publicar porta**.
2. Ao fork-ar CI entre provedores, **cada suposição de rede/ambiente do arquivo original precisa ser re-verificada, não herdada** — `ports:` de um provedor vira `alias` no outro; variáveis como `DATABASE_URL`/`PGPASSWORD` que "funcionavam" podem não ter sido percebidas por estarem num job que nunca rodou. E **um comentário que afirma uma garantia falsa é pior que nenhum**: o comentário dizia que o `|| true` do `CREATE ROLE` cobria a falha de auth, quando ele usa o MESMO caminho de autenticação e falharia junto — a cobertura real era `PGPASSWORD` + `until pg_isready` + o `createdb -O` em cascata.

---

### 2026-09-30 — Monorepo: o GitLab só lê `.gitlab-ci.yml` na RAIZ do repo (validar conteúdo ≠ validar que a ferramenta o encontraria)

**Contexto:** Chore do fork do CI (Sprint 29). O `.gitlab-ci.yml` foi criado em `api-ponto/.gitlab-ci.yml`, seguindo o modelo `pessoas2/.gitlab-ci.yml`. Validamos o YAML, o schema do GitLab (`gitlab-ci-local`), a sequência do job `test` em container, o fail-fast, etc.
**Problema:** o repositório `Frequencia` é um **MONOREPO** — a raiz git contém `api-ponto/` (app Rails), `docs/`, `PRD-*.md`, `SPRINT-PLAN.md`. O **GitLab só lê o `.gitlab-ci.yml` na raiz do repositório**; **não há descoberta automática em subpasta**. Logo o pipeline **nunca foi criado**: o stage `test` não "falhou" — **não existia**. Toda a validação de conteúdo era real, mas o arquivo não era lido pela ferramenta. O modelo `pessoas2` **não se aplicava**: é um app Rails **único na raiz** (não é monorepo), com o arquivo na raiz e sem `cd`.
**Solução:** mover para a raiz (`Frequencia/.gitlab-ci.yml`) + **`cd api-ponto` no `before_script` global** (o `before_script` e o `script` rodam no mesmo shell, então o `cd` persiste e todos os comandos relativos a `api-ponto/` continuam válidos). Provado: sem `cd`, `bin/brakeman`/`bin/rails` da raiz → **EXIT=127**; com `cd`, a sequência do `test` roda (db:test:prepare EXIT=0, load EXIT=0, espelho 19/68/0). Comentário no topo do arquivo explica o monorepo e o `cd`.
**Lição (a mais importante da sessão):** **validar o CONTEÚDO de um artefato não é validar que a ferramenta o LERIA no lugar certo.** Esta foi a **quarta variação do mesmo erro de método** nesta sessão, e todas passaram pelo mesmo furo: a validação media algo *parecido* com a condição real, mas não a condição real.
1. Validar a auth do Postgres **no dev** (loopback `trust`) em vez de no container `scram`.
2. Validar o job no **`gitlab-ci-local`**, que publica porta em `localhost` (semântica divergente do executor real) — a prova passou e não valia.
3. Confiar no **`--ensure-latest`** que saía 0 **sem escanear** (gate que passa sem executar).
4. Validar um **arquivo que o GitLab não lê** (subpasta de monorepo).
> Regra prática: antes de "provar" o funcionamento, pergunte **"esta prova exercita a MESMA condição do ambiente real — inclusive ONDE a ferramenta procura o artefato e COMO ela resolve a rede?"**. Se não, é uma prova de conteúdo, não de integração. Para arquivos de configuração de ferramenta, a primeira verificação é de **descoberta/localização**, não de sintaxe. E: **um modelo copiado de outro projeto só vale se a ESTRUTURA do repositório for a mesma** (monorepo ≠ app único na raiz).
