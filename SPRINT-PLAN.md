# Plano de Sprints — Sistema Frequência (Rails 8)

> **Fonte única de planejamento deste projeto.** Este arquivo consolida o que antes eram dois documentos separados:
> - Este próprio `SPRINT-PLAN.md` (baseado no `PRD-POC-API-PONTO.md` v1.0) — canal de comunicação com a Estação de Ponto (JavaFX): criptografia, endpoints, biometria, integração Sticapi.
> - `docs/12-plano-implementacao/plano-sprints.md` (baseado em `docs/PRD-FREQUENCIA.md` + casos de uso + ADRs) — telas administrativas, regras de negócio de frequência e integração formal com o Pessoas.
>
> Fundidos em 2026-08-28 para eliminar a ambiguidade de "qual documento seguir". O arquivo `docs/12-plano-implementacao/plano-sprints.md` foi removido — todo o conteúdo relevante está aqui, renumerado para não colidir com as sprints já existentes (as antigas Sprints 1–14 desse documento agora são as Sprints 9–22 abaixo).

---

# Parte 1 — Canal EstaçãoPonto (Protocolo, Criptografia, Sticapi)

## Sprint 1 — Setup e Modelagem

**Objetivo:** Criar o projeto Rails API, configurar banco de dados, implementar modelos e migrações.

| # | Task | Responsabilidade | Critério de Aceitação |
|---|------|------------------|----------------------|
| 1.1 | Criar projeto Rails 8 no modo `--api` com PostgreSQL | Setup inicial | `rails s` sobe sem erros |
| 1.2 | Configurar `database.yml` para PostgreSQL (dev/test/prod) | Setup | `rails db:create` funciona |
| 1.3 | Criar migration `users` com campos: `nome_completo`, `username` (unique), `password_digest`, `status` (integer, default 1), `digitais_hash` (text), `created_at`, `updated_at` | Modelagem | Migração roda sem erros |
| 1.4 | Criar migration `time_records` com campos: `user_id` (FK), `raw_data` (string), `punched_at` (datetime), `authentication_mode` (string), `created_at`, `updated_at` | Modelagem | Migração roda sem erros |
| 1.5 | Adicionar índices: `users.username` (unique), `users.status`, `time_records.user_id`, `time_records.punched_at` | Modelagem | Índices criados no banco |
| 1.6 | Criar model `User` com `has_secure_password`, validações de presença e uniqueness do `username`, scopes `ativos` / `com_digitais` | Modelagem | Testes de model passam |
| 1.7 | Criar model `TimeRecord` com `belongs_to :user`, validações de presença | Modelagem | Testes de model passam |
| 1.8 | Implementar lógica de auto-geração de `username` (formato `nome.sobrenome`, lowercase, sem acentos, sufixo numérico se duplicado) | Modelagem | User.create(nome_completo: "José Silva") → `jose.silva` |
| 1.9 | Configurar seeds com usuário de teste | Setup | `rails db:seed` cria dados iniciais |
| 1.10 | Configurar rotas iniciais em `config/routes.rb` (namespace `presenca`) | Setup | `rails routes` lista os endpoints |

---

## Sprint 2 — Criptografia DES + UrlBase64

**Objetivo:** Implementar a biblioteca de criptografia compatível com a estação JavaFX.

| # | Task | Responsabilidade | Critério de Aceitação |
|---|------|------------------|----------------------|
| 2.1 | Implementar módulo `CryptoDes` em `app/services/crypto_des.rb` com método `decrypt(encoded_text)` que faz: UrlBase64 decode → DES/CBC/PKCS5Padding decrypt (chave `"cryp:gpf"`, IV fixo = chave) | Core | Testes unitários passam |
| 2.2 | Implementar método `encrypt(plain_text)` no `CryptoDes` (DES/CBC + UrlBase64 encode sem padding) | Core | Testes unitários passam |
| 2.3 | Implementar UrlBase64 customizada: `encode` (substitui `+` → `-`, `/` → `_`, remove `=`) e `decode` (inverso) | Core | Testes unitários passam |
| 2.4 | Testar compatibilidade: criptografar string em Ruby, descriptografar em Java (ou vice-versa) com vetor de teste conhecido | Core | Roundtrip funciona |
| 2.5 | Criar testes unitários completos para `CryptoDes` (casos normais, borda, strings vazias, chave inválida) | Testes | `rails test` passa |

---

## Sprint 3 — Endpoints de Autenticação e Relógio

**Objetivo:** Implementar os endpoints `CarregaRelogioAtual`, `ValidarFrequentador` e `InicializarPonto`.

| # | Task | Responsabilidade | Critério de Aceitação |
|---|------|------------------|----------------------|
| 3.1 | Implementar `GET /presenca/CarregaRelogioAtual` → retorna timestamp atual em ms (string pura) | Controller | `curl` retorna `"1782000000000"` |
| 3.2 | Implementar `GET /presenca/ValidarFrequentador` com parâmetros `loginAccessKey`, `plainPassword`, `codAtivacao` | Controller | — |
| 3.3 | No `ValidarFrequentador`: validar `codAtivacao` (fixo `poc-ativacao-001`), descriptografar credenciais via `CryptoDes` | Controller | Código errado → `"USUARIO_SENHA_INVALIDOS"` |
| 3.4 | No `ValidarFrequentador`: buscar usuário por username (case-insensitive), verificar status ativo, verificar senha (bcrypt) | Controller | Credenciais OK → retorna `"<id>"` |
| 3.5 | No `ValidarFrequentador`: retornar `"USUARIO_SENHA_INVALIDOS"` para qualquer falha (genérico) | Controller | Segurança: não revelar qual campo está errado |
| 3.6 | Implementar `GET /presenca/InicializarPonto` com parâmetros `codigoAtivacao`, `codigoUnicoMaquina` → retorna `"OK"` | Controller | `curl` com parâmetros → 200 `"OK"` |
| 3.7 | Testes de integração para todos os endpoints da Sprint 3 | Testes | `rails test` passa |

---

## Sprint 4 — Endpoints de Dados Biométricos

**Objetivo:** Implementar `DynFrequentadoresEstacao` e `DynHashFrequentadoresEstacao` para sincronização biométrica.

| # | Task | Responsabilidade | Critério de Aceitação |
|---|------|------------------|----------------------|
| 4.1 | Implementar `GET /presenca/DynHashFrequentadoresEstacao` → calcular MD5 (hex maiúsculo) dos dados serializados de usuários ativos com digitais | Controller | Retorna 32 caracteres `[A-F0-9]` |
| 4.2 | Implementar lógica de serialização no formato: `<id>;<username>;<nome>;<hash>;;false;N;0'<id>;...` (separador `'`) | Service/Controller | Formato exato compatível com estação |
| 4.3 | Implementar `GET /presenca/DynFrequentadoresEstacao` → retornar string serializada com todos os usuários ativos que possuem `digitais_hash` | Controller | Formato e campos corretos |
| 4.4 | Garantir que usuários com status inativo ou sem `digitais_hash` sejam excluídos do retorno | Controller | Filtro aplicado |
| 4.5 | Criar service `FrequentadoresSerializer` para centralizar a lógica de serialização e cálculo de hash | Service | Separação de responsabilidades |
| 4.6 | Testes de integração para ambos os endpoints | Testes | `rails test` passa |

---

## Sprint 5 — Registro de Batidas e Finalização

**Objetivo:** Implementar `SincronizarRegistrosPonto`, testes ponta a ponta e validação final.

| # | Task | Responsabilidade | Critério de Aceitação |
|---|------|------------------|----------------------|
| 5.1 | Implementar `POST /presenca/ajax/SincronizarRegistrosPonto` com parâmetros `registros` (DES + UrlBase64) e `codAtivacao` | Controller | — |
| 5.2 | Descriptografar `registros` via `CryptoDes`, parsear linhas no formato `<id>-<dd:MM:yyyy:HH:mm:ss>` | Controller | Parse correto |
| 5.3 | Para cada registro: criar `TimeRecord` com `user_id`, `raw_data`, `punched_at` (convertendo dd:MM:yyyy → datetime), `authentication_mode` | Controller | Registros salvos no banco |
| 5.4 | Validar `codAtivacao` (fixo `poc-ativacao-001`) | Controller | Código inválido → rejeita |
| 5.5 | Retornar `"sincronizado"` em caso de sucesso (string pura, sem JSON) | Controller | Resposta exata |
| 5.6 | Lidar com registros de usuários inexistentes ou inativos (ignorar ou rejeitar — definir regra) | Controller | Comportamento definido |
| 5.7 | Testes de integração completos para `SincronizarRegistrosPonto` (lote válido, lote vazio, DES inválido, código ativação errado) | Testes | `rails test` passa |
| 5.8 | Teste de integração ponta a ponta: criar usuário → autenticar → registrar batida → consultar registros | Testes | Fluxo completo validado |
| 5.9 | Testar todos os endpoints com `curl` simulando a estação (scripts de teste) | Validação | Mesmo output da doc |
| 5.10 | Revisar código, garantir conformidade com o PRD (formato retornos, mensagens de erro, etc.) | Qualidade | PRD validado ponto a ponto |

---

## Sprint 6 — Integração com a Estação de Ponto (JavaFX)

**Objetivo:** Conectar a Estação de Ponto real (cliente JavaFX Desktop) à API Rails e validar o fluxo completo de ponta a ponta.

| # | Task | Status | Critério de Aceitação |
|---|------|--------|----------------------|
| 6.1 | Configurar ambiente da Estação de Ponto para apontar para API Rails (host:porta) | ✅ | `config.properties` com `base_intranet_url=http://localhost:3000` |
| 6.2 | Validar fluxo de sincronização de horário: estação chama `CarregaRelogioAtual` e calcula delta local | ✅ (curl) | Endpoint retorna timestamp ms |
| 6.3 | Validar fluxo de download de dados biométricos: estação baixa `DynHashFrequentadoresEstacao` → compara hash → baixa `DynFrequentadoresEstacao` → carrega digitais no IndexSearch | ✅ (curl) | Formato serializado compatível |
| 6.4 | Validar autenticação manual (username + senha): estação criptografa credenciais (DES) → envia `ValidarFrequentador` → recebe ID do usuário | ✅ (curl) | Retorna user ID ou `USUARIO_SENHA_INVALIDOS` |
| 6.5 | Validar batida biométrica completa: reconhecimento local (SDK Nitgen) → geração de registro → envio via `SincronizarRegistrosPonto` → confirmação | ⏳ (requer leitor Nitgen) | — |
| 6.6 | Validar batida manual: autenticação → geração de registro → sincronização | ⏳ (requer estação JavaFX) | — |
| 6.7 | Validar `InicializarPonto`: estação chama endpoint ao iniciar sessão | ✅ (curl) | Retorna `OK` |
| 6.8 | Testar fluxo de erro: credenciais inválidas, usuário inativo, código de ativação incorreto | ✅ (curl) | Mensagens de erro corretas |
| 6.9 | Testar resiliência: estação funcionando offline → registros armazenados localmente → sincronização quando conectar | ⏳ (requer estação JavaFX) | — |
| 6.10 | Registrar resultados e ajustes necessários na API | ✅ | Ver abaixo |

### Resultados da Sprint 6

**Concluído:**
- `config.properties` criado em `~/.local/share/TJPI/EstacaoPonto/config.properties` com `base_intranet_url=http://host.docker.internal:3000`
- `run.sh` atualizado para montar config, adicionar `host.docker.internal:host-gateway` e criar diretórios
- `LocalPaths.createDirs()` corrigido (`mkdir` → `mkdirs`) para criar diretórios aninhados
- Todos os endpoints WebView retornam `text/html` (não mais `text/plain`)
- `PontoDePresenca` com jQuery stub inline (sem dependência de CDN)
- `InicializarPonto` com JavaScript redirect para `PontoDePresenca`
- API permite `host.docker.internal` no ambiente de desenvolvimento
- Station conectando e carregando endpoints ✅
- Compatibilidade de criptografia verificada: DES/CBC/PKCS5Padding com key/IV "cryp:gpf" + URL-safe Base64 (RFC 4648)

**Pendente (requer ambiente completo):**
- Teste de reconhecimento biométrico (requer leitor Nitgen)
- Teste de sincronização offline
- Validação com usuário real marcando ponto

### Como o Usuário Marca o Ponto (baseado em PRD-POC-API-PONTO.md §5.3 e documentacao-estacao-ponto.md)

**Fluxo 1 — Biométrico (reconhecimento de digital):**

```
Usuário coloca dedo no leitor
    ↓
Nitgen SDK captura digital → VerificacaoDigitalService
    ↓
Busca no IndexSearch local (hashes baixados via DynFrequentadoresEstacao)
    ↓
Se ID > 0:
  - ArquivoRegistros.escreverRegistro("id-dd:MM:yyyy:HH:mm:ss")
  - The.inserirJavascript("process('DIGITAL_RECONHECIDA', dados)")
    ↓
JavaScript injeta dados no formulário web (matrícula, nome, foto)
    ↓
A cada 5 minutos (ThreadRelogio.fazerSincronizacao):
  - ArquivoRegistros.lerArquivoSincronizado()
  - The.inserirJavascript("sincronizaPonto('dados','codAtivacao')")
    ↓
JavaScript fetch() → POST /prescenza/ajax/SincronizarRegistrosPonto
    ↓
API Rails: descriptografa (ou aceita plain text) → parse → INSERT time_records
```

**Fluxo 2 — Manual (username + senha):**

```
Usuário clica "Login Manual" na interface Web
    ↓
JavaScript: alert('LOGINMANUAL')
    ↓
OnAlertListener → Operacao.LOGINMANUAL.execute()
    ↓
Verifica conectividade (ConexaoIntranetService → CarregaRelogioAtual)
    ↓
Lê campos accessKey e plainPassword via JS
    ↓
CryptoUtils.encryptDES("cryp:gpf", login/senha)
    ↓
GET /prescenza/ValidarFrequentador?loginAccessKey=...&plainPassword=...&codAtivacao=...
    ↓
API retorna: "<id>" (sucesso) ou "USUARIO_SENHA_INVALIDOS" (falha)
    ↓
Se sucesso: gera registro local "id-dd:MM:yyyy:HH:mm:ss"
    ↓
Sincroniza via SincronizarRegistrosPonto (mesmo fluxo do biométrico)
```

**Armazenamento local de registros (offline):**
- Registros são armazenados criptografados em arquivo local (`regs.txt`)
- Formato: `<id>-<dd:MM:yyyy:HH:mm:ss>` (um por linha)
- Sincronização ocorre a cada 5 minutos ou quando a Intranet solicitar
- Se offline, registros ficam no arquivo até a conexão ser restabelecida

**Endpoints envolvidos no fluxo de marcação:**
| Endpoint | Função | Direção |
|----------|--------|---------|
| `GET /prescenza/CarregaRelogioAtual` | Sincroniza horário (timestamp ms) | Estação → API |
| `GET /prescenza/DynHashFrequentadoresEstacao` | Verifica se há novas digitais (MD5) | Estação → API |
| `GET /prescenza/DynFrequentadoresEstacao` | Baixa dados de usuários com digitais | Estação → API |
| `GET /prescenza/ValidarFrequentador` | Autentica usuário (login/senha DES) | Estação → API |
| `POST /prescenza/ajax/SincronizarRegistrosPonto` | Envia registros de batida (DES ou plain) | Estação → API |
| `GET /prescenza/IniciarPonto` | Inicia sessão no WebView | WebView |
| `GET /prescenza/InicializarPonto` | Redireciona para PontoDePresenca | WebView |
| `GET /prescenza/PontoDePresenca` | Interface principal (HTML + JS) | WebView |
| `GET /prescenza/AdicioneEstacao` | Heartbeat da estação | Estação → API |

**Formato de registro de batida:**
- Texto: `<id>-<dd:MM:yyyy:HH:mm:ss>` (ex: `123-15:7:2026:14:30:45`)
- Armazenado em `time_records.raw_data` (string original)
- `punched_at` (datetime) convertido do formato do texto
- `authentication_mode`: "biometric" ou "manual"

**Referência:** PRD-POC-API-PONTO.md §5.3 (Fluxo Completo: Usuário Marca Ponto)

---

## Sprint 7 — Login Manual na Interface de Ponto (View PontoDePresenca)

**Objetivo:** Adicionar o formulário de login manual (username + senha) na view `PontoDePresenca` para que um usuário cadastrado consiga marcar ponto sem biometria, usando o fluxo de login manual da Estação JavaFX (Operacao.LOGINMANUAL).

**Contexto:** A API Rails já possui todos os endpoints necessários (`ValidarFrequentador`, `SincronizarRegistrosPonto`, `CarregaRelogioAtual`, etc.) e a Estação JavaFX já possui todo o código de captura (`Operacao.LOGINMANUAL` lê `input[name=accessKey]` e `input[name=plainPassword]` via jQuery, criptografa em DES, chama a API). O único gap é a ausência do botão "Login Manual" e do formulário de credenciais na view `ponto_de_presenca/index.html.erb`.

**Fluxo completo do login manual (referência):**

```
Usuário clica em "Login Manual" na view PontoDePresenca
    ↓
JavaScript dispara alert('LOGINMANUAL')
    ↓
Estação JavaFX: OnAlertListener → Operacao.LOGINMANUAL.execute()
    ↓
Estação lê jQuery('input[name=accessKey]').val() e jQuery('input[name=plainPassword]').val()
    ↓
Estação criptografa em DES (chave "cryp:gpf") e chama GET /presenca/ValidarFrequentador
    ↓
API Rails: descriptografa, busca User por username (status=ativo), valida senha (bcrypt)
    ↓
Retorna "<id>" (sucesso) ou "USUARIO_SENHA_INVALIDOS" (falha)
    ↓
Se sucesso: Estação gera registro local "id-dd:MM:yyyy:HH:mm:ss"
    ↓
Estação chama process('DIGITAL_RECONHECIDA', dados) via JS → view atualiza cartão de status e tabela
    ↓
Estação sincroniza via POST /presenca/ajax/SincronizarRegistrosPonto
    ↓
API Rails: armazena TimeRecord com punch_type (auto-alternado por PunchTypeService)
```

**Pré-requisitos já atendidos:**

| Componente | Sprint | Status |
|-----------|--------|--------|
| `User` model (username, senha bcrypt, status ativo) | Sprint 1 | ✅ |
| `ValidarFrequentadorController` (autentica username+senha via DES) | Sprint 3 | ✅ |
| `SincronizarRegistrosPontoController` (recebe e armazena batidas) | Sprint 5 | ✅ |
| `PunchTypeService` (auto-alternação entry/exit) | Sprint A | ✅ |
| `PontoDePresencaController` + view (relógio, status, tabela, funções JS bridge) | Sprint A | ✅ |
| CRUD admin de usuários (`Admin::UsersController`) | Sprint R | ✅ |
| Layout AdminLTE 4 + Bootstrap 5.3 | Sprint A | ✅ |
| Estação JavaFX: `Operacao.LOGINMANUAL` (lê campos via jQuery) | Estação | ✅ |
| Estação JavaFX: `ValidarBatidaManualService` (criptografia DES + chamada à API) | Estação | ✅ |
| Estação JavaFX: `EventoLeitura.DIGITAL_RECONHECIDA` (registro + `process()` via JS) | Estação | ✅ |

| # | Task | Responsabilidade | Critério de Aceitação |
|---|------|------------------|----------------------|
| 7.1 | Adicionar botão "Login Manual" na view `ponto_de_presenca/index.html.erb` que alterna entre a tela principal (biometria) e o formulário de login manual | Frontend | Botão visível na tela principal; ao clicar, exibe o formulário de login e oculta a área de biometria; botão "Cancelar" no formulário volta para a tela principal |
| 7.2 | Adicionar formulário de login manual com campos `input[name=accessKey]` (username) e `input[name=plainPassword]` (senha) na view `ponto_de_presenca/index.html.erb` | Frontend | Campos com os atributos `name` exatos (`accessKey` e `plainPassword`) que a Estação JavaFX lê via `jQuery('input[name=accessKey]').val()` e `jQuery('input[name=plainPassword]').val()` (ver `core/leitura/Operacao.java:53-54`); campo de senha com `type="password"`; labels em português |
| 7.3 | Implementar JavaScript que dispara `alert('LOGINMANUAL')` ao submeter o formulário de login manual | Frontend | `alert('LOGINMANUAL')` disparado ao clicar em "Registrar Ponto" ou ao pressionar Enter; campos não são enviados via form submit (a Estação captura via alert e lê via jQuery); formulário tem `onsubmit="return false"` para evitar POST |
| 7.4 | Implementar função JS `changeMensagemStatus(mensagem)` na view para feedback de erro de login | Frontend | Função global `changeMensagemStatus(mensagem)` exibe mensagem de erro na tela (ex: "Usuário ou Senha Inválidos!"); compatível com a linha comentada em `EventoLeitura.USUARIO_SENHA_INVALIDOS` (Estação JavaFX) que pode ser descomentada para chamar esta função; estilizada com AdminLTE (alert vermelho) |
| 7.5 | Garantir que a função `process('DIGITAL_RECONHECIDA', dados)` já existente lide corretamente com o resultado do login manual bem-sucedido | Frontend | Após login manual bem-sucedido, a Estação chama `process('DIGITAL_RECONHECIDA', dados)` via JS; a função já existe (Sprint A, tarefa A.11) e atualiza o cartão de status e a tabela de batidas; verificar que o formato dos dados enviados pela Estação (matrícula, nome, foto) é compatível com o que a função espera |
| 7.6 | Adicionar estilos CSS para o formulário de login manual (AdminLTE/Bootstrap 5.3) | Frontend | Formulário centralizado, responsivo, com cards do AdminLTE; campos com ícones (user, lock); botão "Registrar Ponto" destacado; botão "Cancelar" secundário; formulário oculto por padrão (display:none) e exibido apenas ao clicar em "Login Manual" |
| 7.7 | Testes de view: renderizar formulário de login manual, verificar presença dos campos com os `name` corretos, verificar botões, verificar toggle | Testes | `rails test` passa; testes cobrem: presença do botão "Login Manual", presença de `input[name=accessKey]` e `input[name=plainPassword]`, presença do botão "Cancelar", função `changeMensagemStatus` definida |
| 7.8 | Teste de integração: cadastrar usuário via admin → chamar `ValidarFrequentador` com credenciais DES → verificar retorno do ID → verificar sincronização da batida com o ID retornado | Testes | Fluxo completo validado: `User.create` → `GET /presenca/ValidarFrequentador?loginAccessKey=DES(user)&plainPassword=DES(senha)&codAtivacao=poc-ativacao-001` → retorna `user.id` → `POST /presenca/ajax/SincronizarRegistrosPonto` com registro `id-dd:MM:yyyy:HH:mm:ss` → `TimeRecord` criado com `user_id` correto |
| 7.9 | Atualizar documentação de integração (`relatorio-interacao-presenca-estacao.md`) descrevendo o formulário de login manual, os campos esperados pela Estação (`accessKey`, `plainPassword`), o fluxo JS (`alert('LOGINMANUAL')`) e a função `changeMensagemStatus` | Documentação | Seção atualizada com IDs dos campos, fluxo JS, e referência ao código da Estação (`Operacao.java:53-54`, `EventoLeitura.java:69-76`) |

---

## Sprint 8 — Integração com Sistema Pessoas via Sticapi (Fundação)

**Objetivo:** Estabelecer a infraestrutura de espelhamento de dados do sistema Pessoas no Frequencia, seguindo o mesmo padrão usado no Pessoas2 (client `sticapi_client`, job de importação com **dois gatilhos**: automático — via Solid Queue recurring, diário à meia-noite — e manual — botão na tela de listagem que agenda o mesmo job). Esta sprint entrega apenas a fundação — o espelhamento de novos campos/dados do Pessoas será feito de forma incremental nas sprints da Parte 2 (Sprint 10 em diante).

**Contexto:** Hoje o "Frequentador" (`User`) é cadastrado manualmente no Frequencia, sem nenhum vínculo com o sistema Pessoas (sem CPF, sem matrícula). O objetivo de longo prazo é que os dados cadastrais do Frequentador sejam espelhados a partir do Pessoas, via `sticapi_client`, e não digitados manualmente. Ver investigação completa do padrão em `pessoas2` (client Sticapi, gem, jobs, botão de reimportação em `unidades_controller.rb`).

**Decisões já tomadas com o usuário:**
- Client: gem `sticapi_client` completa (mesma usada no pessoas2), não um client próprio enxuto.
- Chave de vínculo: novo campo `cpf` em `users`.
- Estratégia: espelhamento incremental — a Sprint 8 monta o esqueleto (auth + 1 campo), sprints seguintes adicionam campos/dados sob demanda.

| # | Task | Responsabilidade | Critério de Aceitação | Status |
|---|------|------------------|----------------------|--------|
| 8.1 | Adicionar `gem "sticapi_client"` ao `Gemfile` e rodar `bundle install` | Setup | Gem instalada; `bundle check` OK | ✅ (gem `4.0.4`, trouxe `devise` como dependência transitiva, não usada) |
| 8.2 | Criar `config/sticapi.yml` (dev/test/prod) com host, porta, usuário e senha da Sticapi | Setup | Credenciais reais fornecidas pelo usuário — **não usar placeholder em produção** | ✅ Credencial real reaproveitada do pessoas2 (usuário `pessoas@sticapps.tjpi`), armazenada em Rails encrypted credentials (`config/credentials.yml.enc` + `config/master.key`), com fallback para `ENV`. Autenticação e uma chamada real (`SticapiClient::Pessoas.paises`) testadas com sucesso. **Achado de segurança durante a implementação, corrigido:** `config/master.key` estava versionado no git (commit `61b70cf`) — removido do rastreamento (`git rm --cached`, ainda não commitado) e a master key + `secret_key_base` foram **rotacionados** (nova key gerada, `credentials.yml.enc` recriado do zero com a senha da Sticapi). Chave antiga permanece no histórico do git mas não decifra mais nada relevante. **Risco residual:** a senha do Sticapi agora existe em dois repositórios (pessoas2 e Frequencia) — considerar credencial dedicada no futuro. **Pendente do usuário:** confirmar o `git rm --cached` de `master.key` (commit) e avisar quem tem clone do repo que sessões antigas serão invalidadas pela rotação do `secret_key_base` |
| 8.3 | Criar migration adicionando `cpf` (string, índice único, nullable) à tabela `users` | Modelagem | Migração roda sem erros; `cpf` aceita `null` (frequentadores ainda não vinculados) | ✅ `db/migrate/20260828130834_add_cpf_to_users.rb`, migrada em dev e test |
| 8.4 | Validar `cpf` no model `User` (formato, uniqueness quando presente, sem obrigatoriedade — mantém compatibilidade com frequentadores cadastrados manualmente) | Modelagem | Testes de model passam | ✅ `validates :cpf, uniqueness: true, format: { with: /\A\d{11}\z/ }, allow_nil: true` |
| 8.5 | Criar `app/jobs/importar_dados_pessoa_job.rb`: job (ActiveJob/`solid_queue`) que, dado um `user_id` ou `cpf`, chama `SticapiClient::Pessoas.get_by_cpf` e faz upsert dos campos espelhados no `User` correspondente | Jobs | Job roda isoladamente via console, atualiza o `User` a partir de um CPF de teste | ✅ Escopo inicial: só `nome_completo` (conforme decisão de espelhamento incremental) |
| 8.6 | Implementar lock de execução (adaptado a `solid_queue`, sem Redis — via registro de controle no banco) para evitar imports concorrentes, seguindo o padrão de `Unidade.adquirir_lock_importacao!` do pessoas2 | Jobs | Dois disparos simultâneos → apenas um executa | ✅ Via `pg_try_advisory_lock`/`pg_advisory_unlock` do Postgres (sem tabela nova, sem Redis) |
| 8.7 | Adicionar action `reimportar_dados_pessoa` em `Admin::FrequentadoresController`, que agenda (`perform_later`) o mesmo job usado no espelhamento, com checagem de "já em execução" | Controller | Mesmo padrão do botão em `unidades_controller.rb` (pessoas2) | ✅ Parcial — controller sempre enfileira; a checagem "já em execução" fica só no lock do job (sem fast-path de alerta ao usuário como no pessoas2). Avaliar se vale replicar o fast-path em sprint futura |
| 8.8 | Adicionar botão "Reimportar do Pessoas" na view `admin/frequentadores/index`, visível por frequentador ou em lote | Frontend | Botão dispara a action; feedback de sucesso/erro via flash | ✅ Botão por frequentador (só aparece quando `cpf` presente); sincronização em lote fora de escopo desta sprint |
| 8.9 | Agendar `ImportarDadosPessoaJob` em `config/recurring.yml` (Solid Queue) para rodar automaticamente uma vez por dia, à meia-noite (`schedule: "at midnight every day"`) — varrendo todos os `User` com `cpf` preenchido | Jobs | Job dispara sozinho às 00:00 em ambiente com Solid Queue scheduler ativo, sem intervenção manual | ✅ Registrado em `config/recurring.yml` (ambiente `production`) |
| 8.10 | Testes unitários do job (mock do `SticapiClient::Pessoas`) e testes de integração da action do controller | Testes | `rails test` passa; nenhuma chamada HTTP real nos testes | ✅ `test/jobs/importar_dados_pessoa_job_test.rb` (4 testes) + `test/controllers/admin/frequentadores_controller_test.rb` (3 testes); suíte completa: 187 testes, 1 falha pré-existente (timezone, não relacionada) |
| 8.11 | Documentar em `docs/` o campo de vínculo (`cpf`), o fluxo de espelhamento (automático 00:00 + manual via botão) e como adicionar novos campos nas sprints seguintes | Documentação | Documento criado, referenciado neste plano | ✅ `docs/integracao-pessoas-sticapi.md` |

**Pendências para produção:** garantir que o `config/master.key` de produção seja o mesmo gerado nesta rotação (ou a `RAILS_MASTER_KEY` correspondente esteja configurada no ambiente de deploy) — sem isso, o job falha ao tentar autenticar (log de erro, não derruba a aplicação, graças ao `rescue` em `importar_usuario`). Commitar a remoção de `master.key` do git antes do próximo push.

---

# Parte 2 — Telas Admin, Regras de Negócio e Integração Formal com Pessoas

> **Origem:** conteúdo migrado de `docs/12-plano-implementacao/plano-sprints.md` (Sprints 1–14 daquele documento, renumeradas aqui como 9–22 para não colidir com a Parte 1). Baseado em `docs/PRD-FREQUENCIA.md` (v1.0), `docs/03-dominio/07-casos-uso.md` e ADRs 0001–0005.

## 0. Premissas e sequenciamento

### 0.1 Levantamento do estado atual (em `Frequencia/api-ponto`)

| Camada | Estado |
|---|---|
| Repositório + CI | ✅ Existe (`daviaraujo18/Frequencia`), brakeman + rubocop + testes com Postgres em CI |
| Canal EstaçãoPonto (EP-01..EP-12) | ✅ 11 controllers em `app/controllers/presenca/`, `CryptoDes` (DES+UrlBase64) implementado — ver Parte 1, Sprints 1–7 |
| Modelos reais / schema | ⚠️ `User`, `TimeRecord`, `EstacaoPonto` existem. Nenhum outro agregado do domínio (`Regime`, `Dia`, `RegistroMensalFrequencia`, `RelatorioFrequenciaFinal`) existe no banco |
| Telas admin (AdminLTE) | ✅ 9 telas prontas (`dashboard`, `frequentadores`, `regimes`, `estacoes`, `direitos_deveres`, `frequencia`, `frequencia_por_orgao`, `relatorio_terceirizados`, `gestores_individuais`, `versoes`) — layout e colunas da grid já definidos |
| Dados por trás das telas | ❌ Maioria dos controllers ainda retorna array vazio hardcoded (`@regimes = []`, `@estacoes = []` antes da Sprint 9) — fachada visual, sem model/query real (exceto `estacoes` e `frequentadores`, já em andamento — ver Sprints 9 e 10) |
| Estrutura DDD (`domain/application/infrastructure`) | ❌ Não iniciada — código é Rails MVC padrão |

**Conclusão:** o trabalho de UI/layout está feito e não deve ser refeito. O gargalo é modelar as entidades e alimentar as grids com dado real — isso é a prioridade da Fase A abaixo, antes de qualquer motor de cálculo.

### 0.1.1 O que vem do Pessoas vs. o que é próprio de Frequência

Levantamento em `pessoas2/app/models`: já existem `Pessoa`, `Vinculo` (+ subtipos: efetivo, comissionado, cedido, terceirizado, estagiário...), `Orgao`, `Cargo`, `Lotacao`, `Afastamento`/`TipoAfastamento`/`MotivoAfastamento`. Isso cobre boa parte do que as grids de Frequência precisam exibir, expostos via `SticapiClient::Pessoas` (mesmo client já instalado na Sprint 8).

| Tela / Entidade | Dado já existe no Pessoas? | Tratamento na Fase A |
|---|---|---|
| `admin/frequentadores` (Nome, Comarca/Órgão, Vínculo) | ✅ `Pessoa` + `Vinculo` + `Orgao`, via `SticapiClient::Pessoas` | Tabela de **espelho** local (`frequentadores_cache`), alimentada via `sticapi_client` — não é cadastro próprio |
| `admin/frequentadores` (Digital) | ❌ é dado biométrico específico do ponto | Já existe em `users.digitais_hash` (tabela já existente em Frequência, não é nova) |
| `admin/direitos_deveres` (afastamentos) | ✅ `Afastamento`/`TipoAfastamento`/`MotivoAfastamento`, via `SticapiClient::Pessoas` | Tabela de **espelho** local (`afastamentos_cache`), alimentada via `sticapi_client` |
| `admin/estacoes` | ❌ não existe no Pessoas (é ativo físico do ponto) | Tabela própria em Frequência (mantido — já implementada, Sprint 9) |
| `admin/regimes` (jornadas) | ❌ não existe no Pessoas (regra de ponto, não cadastro) | Tabela própria em Frequência (mantido) |
| `admin/frequencia` (registros brutos) | ❌ não existe no Pessoas | Tabela própria em Frequência (mantido) |
| `admin/gestores_individuais` | ⚠️ existe `gestor_contrato.rb` no Pessoas, mas é conceito de gestão de contrato, não de gestão de ponto — não reaproveitar | Tabela própria em Frequência (mantido) |
| `admin/versoes` | ❌ não existe no Pessoas | Tabela própria em Frequência (mantido) |

**Mecanismo de consumo definido (Sprints 10 e 12):** client `sticapi_client` (gem oficial, já instalada na Sprint 8), autenticado via token HTTP (`POST /auth/sign_in`), chamando o módulo `SticapiClient::Pessoas`. A leitura é feita por um **job agendado** via Solid Queue (`config/recurring.yml`), que grava/atualiza uma tabela de espelho local uma vez por dia — mais um **gatilho manual** (botão na tela) para quando o dado precisa ficar fresco antes do próximo horário agendado. As telas de Frequência sempre leem o espelho local, nunca a Sticapi diretamente em tempo de request — isso garante que uma queda da Sticapi não derruba as telas administrativas. Não há conexão de banco entre os dois sistemas nem credencial de banco compartilhada — toda comunicação é via API HTTP autenticada. Continua sendo uma solução simplificada (não é o padrão API+eventos formal do ADR-0001), reformalizada na Sprint 21 (Fase C).

### 0.2 Nova ordem de prioridade

1. **Fase A — Popular o front** (Sprints 9–15): para cada tela já existente, criar o model/migration mínimo e a query de listagem, sem regra de negócio de cálculo. Critério "pronto" = a tela mostra dados reais do banco, com cadastro básico (CRUD) onde fizer sentido.
2. **Fase B — Regras de negócio** (Sprints 16–20): cálculo diário, consolidação mensal, banco de horas, relatório final, retificador, gestão de exceções — tudo o que hoje ainda não existe por trás das telas populadas na Fase A.
3. **Fase C — Integração formal com Pessoas + cutover** (Sprints 21–22): promover a integração cadastral simplificada da Fase A para o contrato oficial (API+eventos, ADR-0001/ADR-0006) e desligar a Intranet.

- **Dependência técnica fixa (não reordenável dentro da Fase B):** cálculo diário (Sprint 16) → consolidar mês (Sprint 17) → relatório final (Sprint 18).
- **Estratégia:** Strangler Fig (ADR-0002) — a Intranet `presenca` continua viva até o desligamento formal (última sprint).
- **Fora de escopo em todas as sprints:** qualquer alteração na EstaçãoPonto desktop (ADR-0003) e qualquer mudança de regra de cálculo sem evidência (DUV-005 já resolvida: v2 é o motor oficial).
- **Débito técnico assumido conscientemente:** na Fase A, dado cadastral (`Frequentador`, `Direito`) é lido do Pessoas via `sticapi_client` (API HTTP autenticada, não é o contrato canônico do ADR-0006, que ainda não existe) e espelhado localmente por job diário + gatilho manual — não é o padrão API+eventos definitivo do ADR-0001. Isso é destrinchado e corrigido na Fase C (Sprint 21), quando se decide se o padrão final mantém espelho via polling ou migra para eventos assíncronos — não é para virar solução definitiva sem revisão.

---

## Fase A — Popular o front (Sprints 9–15)

### Sprint 9 — Model de Estações + tela `admin/estacoes`

**Status:** ✅ CONCLUÍDA (tasks 9.1–9.5) — 171 testes, 1 falha pré-existente (timezone em `presenca_endpoints_test.rb`, não relacionada a `EstacaoPonto`; débito de outra task)

**Objetivo:** sair de `@estacoes = []` para dados reais, já usando o mesmo agregado que o canal `presenca/*` precisa (`EstacaoPonto`).

| Task | Descrição |
|---|---|
| 9.1 | Migration + model `EstacaoPonto` — campos vistos na grid: descrição, versão, último contato, VNC, AnyDesk, TeamViewer, observação, `codAtivacao` ✅ CONCLUÍDA |
| 9.2 | `Admin::EstacoesController#index` passa a consultar o model real (substituir array vazio) ✅ CONCLUÍDA |
| 9.3 | Formulário de cadastro/edição básico (sem validação de regra de negócio ainda) ✅ CONCLUÍDA |
| 9.4 | Ligar ao canal já existente: os controllers `presenca/adicione_estacao_controller.rb` e afins passam a gravar/consultar `EstacaoPonto` real em vez de dado solto ✅ CONCLUÍDA |
| 9.5 | Testes: listagem exibe estações cadastradas, cadastro básico funciona ✅ CONCLUÍDA |

### Sprint 10 — Sincronização de Frequentadores (espelho via Sticapi) + tela `admin/frequentadores`

**Objetivo:** popular a grid (Nome, Comarca/Órgão, Vínculo, Digital, Gerência) a partir de um **espelho local** dos dados de `Pessoa`/`Vinculo`/`Orgao` do Pessoas, obtidos via `sticapi_client` (`SticapiClient::Pessoas`), atualizado por job diário + gatilho manual. Reaproveita a fundação já estabelecida na Sprint 8 (gem instalada, `config/sticapi.yml`, campo `cpf` em `users`, job base de importação já rodando em produção com escopo mínimo: `nome_completo`).

| Task | Descrição | Status |
|---|---|---|
| 10.1 | Confirmar fundação da Sprint 8 já aplicada: gem `sticapi_client`, `config/sticapi.yml`, campo `users.cpf`, `ImportarDadosPessoaJob` básico | ✅ Confirmado — ver Sprint 8 |
| 10.2 | Migration + model `FrequentadorCache` (tabela de **espelho**, não cadastro próprio) — campos: `cpf` (chave, único), `pessoa_id_pessoas` (id no Pessoas), `nome`, `orgao`, `vinculo`, `sincronizado_em` | ✅ `db/migrate/20260828133924_create_frequentador_caches.rb` + `app/models/frequentador_cache.rb`; 6 testes em `test/models/frequentador_cache_test.rb`, todos passando |
| 10.3 | Estender `ImportarDadosPessoaJob` (ou criar `SincronizarFrequentadoresJob`) — para cada `User` com `cpf` preenchido, chama `SticapiClient::Pessoas.get_by_cpf`/`find` e faz upsert em `FrequentadorCache` (além do `nome_completo` já atualizado direto em `users` desde a Sprint 8) | ✅ Upsert completo: `pessoa_id_pessoas` (`id`), `nome`, `orgao` (`lotacao_principal.unidade.descricao`), `vinculo` (`vinculos_ativos[0].tipo_vinculo.nome`) e `sincronizado_em`. Formato do payload confirmado em 2026-08-28 com uma chamada real de teste (CPF do próprio usuário, autorizado por ele, nunca persistido em nenhum arquivo/log/commit). 6 testes, todos passando |
| 10.4 | Agendamento diário (00:00) — já coberto pela Sprint 8 (task 8.9); só validar que a extensão do job continua rodando no mesmo agendamento | ✅ Validado — `config/recurring.yml` continua apontando para `ImportarDadosPessoaJob` (mesma classe, não foi criado job novo); modo em lote (sem `user_id`, o mesmo usado pelo agendamento) testado manualmente e confirmado fazendo upsert completo em `FrequentadorCache` (`orgao`/`vinculo` inclusos) |
| 10.5 | Gatilho manual — já coberto pela Sprint 8 (task 8.8, botão "Reimportar do Pessoas"); validar que também atualiza o `FrequentadorCache` | ✅ Validado com teste de integração (`perform_enqueued_jobs`, executa o job de verdade a partir do POST no controller) — botão atualiza `nome`, `orgao` e `vinculo` no cache |
| 10.6 | Confirmar vínculo do login local da estação (`users.cpf`, já criado na Sprint 8) com o `FrequentadorCache` correspondente | ✅ Formalizado com associações `User belongs_to :frequentador_cache` / `FrequentadorCache has_one :user` (via `cpf`, `optional: true` — frequentador sem cpf continua válido). 4 testes novos cobrindo os dois sentidos e os casos sem cpf/sem cache |
| 10.7 | `Admin::FrequentadoresController#index` passa a combinar `User` (nome, digital) com `FrequentadorCache` (órgão, vínculo) — nunca a Sticapi diretamente na hora do request | ✅ `includes(:frequentador_cache)` no controller (evita N+1, testado explicitamente contando queries SQL); view exibe `orgao`/`vinculo` reais quando o cache existe, mantém "—" quando não. 3 testes novos (exibição com cache, exibição sem cache, ausência de N+1) |
| 10.8 | Testes: job faz upsert corretamente (mock do `SticapiClient::Pessoas`, sem chamada HTTP real), sincronização manual funciona, tela continua respondendo com o espelho antigo se a Sticapi estiver fora do ar no horário do job, frequentador sem CPF vinculado não quebra a tela | ✅ Cobertura fechada: upsert (10.3), sincronização manual (10.5), 2 testes novos para "Sticapi fora do ar" (job engole exceção e preserva cache antigo; tela renderiza com o espelho antigo sem nenhuma chamada HTTP), e "sem cache" já coberto na 10.7. Suíte completa: 207 testes, 1 falha pré-existente (timezone, não relacionada) |

### Sprint 10B — Importação em Massa de Frequentadores por Unidade (Sticapi)

**Objetivo:** inverter a direção da Sprint 10 — em vez de só *atualizar* um `User` que já tem `cpf` preenchido manualmente, a aplicação passa a **descobrir e criar** Frequentadores automaticamente a partir de uma unidade do Pessoas, puxando os cadastros de verdade da Sticapi.

**Contexto/decisão com o usuário:** a Sprint 10 resolvia "dado um CPF já vinculado, mantenha os dados atualizados". Isso não resolve o cenário real: hoje nenhum frequentador tem `cpf`, e ninguém vai digitar isso manualmente para dezenas de pessoas — a aplicação precisa puxar a lista inteira do Pessoas. Escopo inicial: **uma unidade piloto** (a mesma da lotação do usuário, já validada com 87 servidores), antes de expandir para todos os órgãos do TJPI. `User`s são criados automaticamente quando não existem.

**Investigação técnica (2026-08-28), com o CPF do próprio usuário, autorizado por ele — nada persistido em arquivo/log/commit:**
- `SticapiClient::Pessoas.unidade(id:)` retorna a unidade com `servidores` (array de `{matricula, nome, cargo, inicio_vinculo, inicio_lotacao, exercicios_funcoes}`) — **sem CPF**
- `/pessoas/find` (via `SticapiClient::Pessoas.find`) **não resolve por matrícula** — só aceita `cpf` ou `username` (campo distinto da matrícula; testado e confirmado que matrícula sozinha retorna vazio)
- `SticapiClient::Gestorh.competencia(mes:, ano:)` retorna a folha inteira do TJPI (~4700 pessoas testado com jul/2026) com `{matricula, nome, cpf, nascimento, tipo_vinculo, folha}` — **é o elo que resolve matrícula → CPF**
- **Achado importante:** nem toda matrícula aparece em toda competência (testado: a matrícula do próprio usuário não apareceu na competência de jul/2026, provavelmente por diferença de vínculo/formato) — o job precisa **tolerar CPF não resolvido** sem quebrar o restante do lote

| # | Task | Responsabilidade | Critério de Aceitação | Status |
|---|------|------------------|----------------------|--------|
| 10B.1 | Confirmar a unidade piloto (id já identificado nos testes) e a competência (mês/ano) a usar para resolução matrícula→CPF | Planejamento | Decisão registrada aqui, sem hardcode escondido no código | ✅ Unidade piloto: id `110001469` (lotação principal do usuário, 87 servidores confirmados via `SticapiClient::Pessoas.unidade`). Competência: a mais recente disponível — regra de cálculo ainda a implementar na 10B.3, não fixar mês/ano aqui |
| 10B.2 | Criar `app/services/pessoas/resolver_cpf_por_matricula_service.rb` (ou similar) — busca a competência mais recente via `SticapiClient::Gestorh.competencia`, monta um mapa `matricula => cpf` em memória (cache de request, não persiste os ~4700 registros no banco) | Service | Dado um array de matrículas, retorna o mapa correspondente; matrícula não encontrada não gera erro | ✅ `app/services/resolver_cpf_por_matricula_service.rb` (sem namespace `Pessoas::`, seguindo o padrão flat já usado em `app/services/` do projeto). Recebe `mes`/`ano` explícitos por enquanto — a lógica de "competência mais recente sem hardcode" fica pra 10B.3, que ainda não foi implementada. 6 testes (resolução, matrícula não encontrada, competência vazia, normalização integer/string, registros sem matrícula/cpf, memoização — só 1 chamada HTTP mesmo com múltiplas buscas na mesma instância) |
| 10B.3 | Decidir e implementar como obter "a competência mais recente" sem hardcode de mês/ano fixo no código (ex.: mês/ano atual, com fallback para o mês anterior se o atual ainda não tiver fechado folha) | Service | Não quebra em janeiro (ano anterior) nem no primeiro dia do mês | ✅ `ResolverCpfPorMatriculaService.mais_recente(matriculas)` — em vez de "cai pro mês anterior só se o atual estiver vazio" (podia dar falso negativo: mês atual existir mas não conter a matrícula específica, ex. servidor recém-lotado), busca **mês atual + mês anterior e mescla**, com o mês atual tendo prioridade quando a matrícula aparece nos dois. 3 testes novos: prioridade do mês atual, fallback pro anterior quando só ele tem a matrícula, e virada de ano (janeiro → dezembro do ano anterior, via `travel_to`) |
| 10B.4 | Criar `app/jobs/importar_servidores_unidade_job.rb` — dado um `unidade_id`, busca `SticapiClient::Pessoas.unidade`, resolve CPFs via 10B.2, e para cada servidor resolvido: `User.find_or_create_by!(cpf:)` (com senha temporária/aleatória, sem digital, status a definir) + upsert em `FrequentadorCache` (reaproveitando a lógica de `ImportarDadosPessoaJob#atualizar_cache`, extraída para um método/service comum) | Jobs | Roda contra a unidade piloto; cria os `User`s que não existiam; não duplica os que já existiam (por `cpf`) | ✅ `app/jobs/importar_servidores_unidade_job.rb` + lógica de cache extraída para `app/services/atualizar_frequentador_cache_service.rb` (reaproveitado por `ImportarDadosPessoaJob` também, sem regressão — 9 testes antigos continuam passando). Senha placeholder via `SecureRandom.hex(16)` (decisão registrada na Sprint 21 — login local fica inutilizável até a troca de autenticação). `User` só é criado se ainda não existir pelo `cpf` (não sobrescreve `nome_completo` de quem já existia — mesmo comportamento conservador do `ImportarDadosPessoaJob`). 6 testes: criação nova, não duplicação, matrícula não resolvida pulada, erro em 1 servidor não impede os demais, unidade vazia, lock de concorrência (chave distinta de `ImportarDadosPessoaJob::LOCK_KEY`) |
| 10B.5 | Definir e documentar o que preencher em campos que `User` exige mas a Sticapi não fornece diretamente: `password` (aleatória, forçar troca depois?), `username` (**decisão do usuário 2026-08-28: usar o `username` real vindo do payload da Sticapi — `dados["username"]` — em vez do `generate_username` local; mesmo campo que o próprio pessoas2 usa para vincular seu `User` a `Pessoa` via `has_one :pessoa, foreign_key: "username", primary_key: "username"`. `generate_username` vira só fallback para quando a Sticapi não retornar `username`**), `status` (ativo por padrão?) | Modelagem | Regra documentada aqui e no código; sem violar `has_secure_password`/validações existentes; usuários já existentes não têm o `username` sobrescrito nesta sprint (evita quebrar login/sessão ativa — só se aplica na criação) | ✅ `ImportarServidoresUnidadeJob#criar_user_se_necessario` agora usa `dados["username"]` quando presente, cai no `generate_username` (callback já existente no model) quando ausente. `status` confirmado como default do schema (`1`, ativo), sem set explícito. 3 testes novos (username real, fallback local, status default) |
| 10B.6 | Servidor sem CPF resolvido (matrícula não encontrada na competência) — logar e pular, sem quebrar o restante do lote | Jobs | Teste: unidade com 1 matrícula não resolvível entre várias resolvíveis → as outras são importadas normalmente | ✅ Já não quebrava o lote desde a 10B.4 (`next` no `each`); adicionado `Rails.logger.warn` explícito por matrícula pulada, testado capturando o log real (`assert_match`) |
| 10B.7 | Lock de execução (mesmo padrão advisory lock do Postgres da Sprint 8/`ImportarDadosPessoaJob`), chave distinta por não ser o mesmo job | Jobs | Duas execuções simultâneas para a mesma unidade → só uma roda | ✅ Já implementado desde a 10B.4 — `LOCK_KEY = 592_017_384` (distinta de `ImportarDadosPessoaJob::LOCK_KEY = 837_462_915`), mesmo padrão `pg_try_advisory_lock`/`pg_advisory_unlock`. Teste de concorrência (segunda conexão Postgres real) confirmado passando |
| 10B.8 | Action + botão único "Importar servidores desta unidade" em `admin/frequentadores` — **um clique dispara `ImportarServidoresUnidadeJob` para a unidade inteira de uma vez** (não é um botão por pessoa; decisão explícita do usuário: o polling manual não deve ser um-a-um) | Controller/Frontend | Um clique enfileira a importação de todos os servidores da unidade piloto; distinto do botão "Reimportar do Pessoas" por frequentador já existente (Sprint 8), que continua servindo para atualizar 1 pessoa específica já cadastrada | ✅ Botão "Importar servidores da unidade piloto" em `page_actions` (topo da tela, não por linha) → `POST /frequentadores/importar_unidade` → `Admin::FrequentadoresController#importar_unidade` → `ImportarServidoresUnidadeJob.perform_later(UNIDADE_PILOTO_ID)`. `UNIDADE_PILOTO_ID = 110_001_469` fixo no controller (constante documentada — seletor de unidade/expansão pra outros órgãos é escopo de sprint futura). 3 testes: enfileiramento correto, execução real criando múltiplos `User`s de uma vez (prova que não é um-a-um), exige autenticação |
| 10B.9 | Testes: mock de `SticapiClient::Pessoas.unidade` e `SticapiClient::Gestorh.competencia` (sem chamada HTTP real), criação de `User` novo, não duplicação de `User` existente, matrícula não resolvida não quebra o lote, `FrequentadorCache` populado igual ao `ImportarDadosPessoaJob` | Testes | `rails test` passa, nenhuma chamada HTTP real | ✅ Cobertura já fechada incrementalmente nas tasks 10B.2–10B.8 (29 testes entre `resolver_cpf_por_matricula_service_test.rb`, `importar_servidores_unidade_job_test.rb` e `frequentadores_controller_test.rb`) — auditado critério por critério, todos os cenários pedidos aqui já existiam. 100% via `define_singleton_method`, nenhuma chamada HTTP real. Suíte completa: 228 testes, 1 falha pré-existente (timezone, não relacionada) |
| 10B.10 | Rodar de verdade contra a unidade piloto (ambiente de dev, com `bin/jobs` ativo) e validar visualmente na tela `admin/frequentadores` — critério de "puxar tudo de lá" atendido para essa unidade | Validação | Frequentadores da unidade piloto aparecem na tela sem cadastro manual prévio | ✅ Rodado de verdade contra os 87 servidores da unidade piloto: **69 `User`s + `FrequentadorCache`s criados** (diferença = matrículas não resolvidas na competência ou sem nome retornado, comportamento tolerante já esperado). Página `admin/frequentadores` validada via HTTP real (200, 69 botões de reimportação, 14 travessões para quem ficou sem cpf/cache). **`bin/jobs` não é necessário em dev**: `config/environments/development.rb` não define `queue_adapter`, então o Rails usa `:async` (thread em processo) — rodei o job direto e de forma síncrona. **Bug real encontrado e corrigido durante a validação:** `vinculos_ativos` no payload da Sticapi vem como Array quando a pessoa tem múltiplos vínculos, mas como **Hash único** quando tem só 1 — `AtualizarFrequentadorCacheService` corrigido com `Array.wrap` (mesmo idioma já usado pelo próprio pessoas2 em `registro_importacao.rb`/`association_error_detail_concern.rb`), 4 testes novos em `test/services/atualizar_frequentador_cache_service_test.rb`. Reexecutado o job após a correção: 69/69 com `orgao` e `vinculo` preenchidos |

**Fora de escopo desta sprint:** expandir para todos os órgãos do TJPI (fica para uma sprint futura, após validar o piloto), reconciliar/desativar `User`s que saíram da unidade (alguém que se desliga não é automaticamente inativado — decisão de negócio a parte), biometria/digital (continua exigindo cadastro manual na estação, isso não vem do Pessoas).

---

### Sprint 11 — Model de Regimes + tela `admin/regimes`

| Task | Descrição |
|---|---|
| 11.1 | Migration + model `Regime` (+ `RegimeFrequentador`, AG-2) — campos: categoria, nome, modalidade, resumo, meta semanal |
| 11.2 | `Admin::RegimesController#index` consulta o model real |
| 11.3 | Cadastro/edição básico de regime (sem motor de cálculo associado ainda) |
| 11.4 | Testes: listagem, associação básica regime↔frequentador |

### Sprint 12 — Sincronização de Direitos/Deveres (espelho via Sticapi) + tela `admin/direitos_deveres`

**Objetivo:** popular a grid (Tipo, Frequentador, Cargo, Lotação, Momento Inicial/Final, Status) a partir de um **espelho local** de `Afastamento`/`TipoAfastamento`/`MotivoAfastamento` do Pessoas, obtidos via `sticapi_client`, reaproveitando a mesma infraestrutura de job/autenticação da Sprint 10.

| Task | Descrição |
|---|---|
| 12.1 | Migration + model `AfastamentoCache` (espelho, não cadastro próprio) — campos: `afastamento_id_pessoas` (chave), `cpf` (referência a `FrequentadorCache`), `tipo`, cargo, lotação, `momento_inicial`/`momento_final`, status |
| 12.2 | Job `SincronizarAfastamentosJob` — chama o(s) endpoint(s) correspondente(s) do módulo `SticapiClient::Pessoas` (mesma autenticação da Sprint 10) e faz upsert em `AfastamentoCache` |
| 12.3 | Agendar em `config/recurring.yml` — mesmo horário da Sprint 10 (00:00), rodando logo em seguida para evitar concorrência com o job de Frequentadores |
| 12.4 | Gatilho manual "Sincronizar agora" em `admin/direitos_deveres`, mesmo padrão da Sprint 10 |
| 12.5 | `Admin::DireitosDeveresController#index` lê `AfastamentoCache` |
| 12.6 | Se a tela precisar de um tipo de "direito" que só existe no domínio de Frequência (ex. autorização específica de ponto, não afastamento cadastral) — sinalizar caso a caso e só aí avaliar tabela própria (não espelho) |
| 12.7 | Testes: job faz upsert corretamente (mock do client, sem chamada HTTP real), sincronização manual funciona, cargo/lotação ausentes não quebram a tela |

### Sprint 13 — Grid de Frequência (registros brutos) — tela `admin/frequencia`

**Objetivo:** exibir os dados que o canal EstaçãoPonto **já está recebendo** (Parte 1, Sprint 5) — aqui é só ligar a grid à leitura, sem calcular nada ainda.

| Task | Descrição |
|---|---|
| 13.1 | Confirmar/ajustar model que representa o registro bruto já processado (`RegistroFrequencia`, membro interno do futuro `Dia`/AG-3 — aqui ainda tratado como leitura simples, sem a modelagem completa de `Dia`) |
| 13.2 | `Admin::FrequenciaController#index` consulta os registros reais (Frequentador, Data, Operação, Modo, Lotação Época, Estação) |
| 13.3 | Filtros básicos de listagem (por frequentador/data/estação) |
| 13.4 | Testes: grid mostra batidas reais recebidas pelo canal `presenca/*` |

### Sprint 14 — Telas agregadas: `frequencia_por_orgao`, `gestores_individuais`, `relatorio_terceirizados`, `versoes`

**Objetivo:** telas de consulta/agregação simples em cima do que já foi populado nas sprints 9–13.

| Task | Descrição |
|---|---|
| 14.1 | `frequencia_por_orgao` — query agregada (Trabalhado/Presenças/Ausências) sobre os dados da Sprint 13 |
| 14.2 | `gestores_individuais` — model `GestorIndividual` + listagem (Nome, Órgão, Gerenciados) |
| 14.3 | `relatorio_terceirizados` — definir/confirmar com o gestor o que essa tela deve exibir (não há coluna definida no layout ainda — levantamento pendente) |
| 14.4 | `versoes` — model simples de versões da EstaçãoPonto/app (Versão, Novidades, Link) |
| 14.5 | Testes: cada tela lista dado real, sem cálculo de negócio embutido |

### Sprint 15 — Dashboard consolidado

| Task | Descrição |
|---|---|
| 15.1 | `Admin::DashboardController` — KPIs simples a partir dos dados já populados (contagem de frequentadores, estações ativas, batidas do dia) |
| 15.2 | Nenhum KPI depende de cálculo de banco de horas/fechamento (isso só existe na Fase B) |
| 15.3 | Testes: dashboard carrega sem erro com dados reais e com base vazia |

**Critério de saída da Fase A:** todas as 9 telas admin exibem dados reais do banco, com cadastro básico onde aplicável. Nenhuma regra de cálculo de frequência foi implementada ainda — é aceitável que os números de frequência sejam apenas listagem/contagem simples nesta fase.

---

## Fase B — Regras de negócio (Sprints 16–20)

### Sprint 16 — Motor de cálculo diário (UC-05)

**Objetivo:** implementar o cálculo diário oficial (v2), agora sobre o modelo `Frequentador`/`Regime` já populados na Fase A. Aqui formaliza-se `Dia` (AG-3) como raiz, com `RegistroFrequencia` e `CalculoDiario` como membros internos — não mais leitura solta como na Sprint 13.

| Task | Descrição | UC |
|---|---|---|
| 16.1 | Modelar agregado `Dia` (AG-3) corretamente — migrar a leitura simples da Sprint 13 para essa estrutura | Nota crítica do PRD §4.2 |
| 16.2 | Portar regras do motor v2 (oficial, DUV-005) | UC-05 |
| 16.3 | Orquestração por modalidade (estratégias por regime, já cadastrado na Sprint 11) | UC-05 |
| 16.4 | Testes de paridade com dados reais do legado v2 | PRD §8 |

### Sprint 17 — Consolidação mensal e banco de horas (UC-06)

| Task | Descrição | UC |
|---|---|---|
| 17.1 | Consolidar mês → `RegistroMensalFrequencia` (AG-4), saldo/banco de horas | UC-06 |
| 17.2 | Mecanismo real de congelamento (`finalizado`) — corrigir bug do legado (nunca efetivado, DUV-010) | PRD §8 |
| 17.3 | Atualizar telas da Fase A (`frequencia`, `frequencia_por_orgao`, `dashboard`) para refletir dados calculados, não mais contagem simples | — |
| 17.4 | Testes: consolidação, saldo, trava de fechamento efetiva | UC-06 |

### Sprint 18 — Relatório final e retificador (UC-07, UC-12)

| Task | Descrição | UC |
|---|---|---|
| 18.1 | Gerar/atualizar `RelatorioFrequenciaFinal` (AG-5) | UC-07 |
| 18.2 | Retificador de banco de horas | UC-12 |
| 18.3 | Corrigir bug do legado `cont=+valor` → `cont+=valor` (DUV-011, não replicar) | PRD §8 |
| 18.4 | Testes: geração idempotente, retificação pós-fechamento | UC-07/12 |

### Sprint 19 — Gestão de exceções (UC-08, UC-09, UC-10, UC-11)

| Task | Descrição | UC |
|---|---|---|
| 19.1 | Batida manual / errata | UC-08 |
| 19.2 | Desconsiderar / reconsiderar ponto | UC-09 |
| 19.3 | Autorizar horas extras (deferir/indeferir) | UC-10 |
| 19.4 | Autorizar batida em prédio não permitido | UC-11 |
| 19.5 | Testes: fluxos de aprovação/rejeição, auditoria | UC-08–11 |

### Sprint 20 — Recálculo em lote e valores retroativos (UC-16, UC-17)

| Task | Descrição | UC |
|---|---|---|
| 20.1 | Registrar valores retroativos (já sem o bug DUV-011) | UC-16 |
| 20.2 | Recalcular mês / recalcular todos (job) | UC-17 |
| 20.3 | Testes de idempotência do recálculo em lote | UC-17 |

**Critério de saída da Fase B:** o sistema calcula frequência de ponta a ponta (dia → mês → relatório final) com as mesmas regras do legado v2, e as telas populadas na Fase A mostram dados calculados de verdade.

---

## Fase C — Integração formal com Pessoas e cutover (Sprints 21–22)

### Sprint 21 — Formalizar integração cadastral (UC-14)

**Objetivo:** substituir a leitura simplificada criada na Sprint 10 pelo contrato oficial do ADR-0001, fechando a ACL pendente (PRD §3).

**Decisão registrada com o usuário (2026-08-28), para executar aqui — não antes:** a autenticação de administradores/usuários do Frequencia deve deixar de usar senha local (`has_secure_password`) e passar a usar o **login/senha reais do Pessoas** (mesmo padrão de `sticapi_authenticatable` do pessoas2, via `sticapi_client`/Devise). Como consequência, o CRUD administrativo local de `User` (criar/editar/excluir frequentador manualmente pela tela) deixa de fazer sentido — **a intenção é remover as rotas de `POST`/`DELETE` de `Admin::UsersController`** (mantendo GET/listagem), já que o cadastro passa a vir inteiramente do Pessoas. Isso só deve ser feito **depois** que a importação em massa (Sprint 10B) e a autenticação via Sticapi estiverem validadas de ponta a ponta — remover escrita local prematuramente quebraria o cadastro manual que ainda é a única via disponível hoje.

**Mecanismo confirmado tecnicamente em 2026-08-28** (testado com o login real do usuário, senha nunca persistida em arquivo/log/commit — só via `ENV` em teste ad-hoc, descartado depois):
1. `Sticapi::SticapiClient.instance.get_token` — pega o token de aplicação (mesmo usado pra tudo, `config/sticapi.yml`)
2. Monta um JWT: `JWT.encode({ user: login, password: senha }, token_de_app, "HS256")` — o **token de app funciona como segredo de assinatura**, a senha da pessoa nunca trafega em texto puro fora desse JWT
3. `POST /users/log_in` com esse JWT (`Sticapi::SticapiClient.instance.sticapi_request("/users/log_in", data: token)`)
4. Sucesso retorna dados vindos do **Active Directory** do TJPI (`dn`, `samaccountname`, `username`, `cpf`, `email`, `name`, `unities`, `unities_short`) — confirma que a Sticapi delega a validação de senha ao AD, não guarda/compara nada por conta própria
5. A gem `sticapi_client` já implementa isso pronto como estratégia Devise (`Devise::Strategies::SticapiAuthenticatable`, registrada como `:sticapi_authenticatable`) — **não precisa reimplementar**, só configurar o model `User` pra usar essa estratégia (mesmo padrão do `devise :sticapi_authenticatable` do pessoas2)

**Entrega parcial antecipada (2026-08-28), fora da numeração das tasks:** `admin/users/:id/edit` já bloqueia edição manual para frequentadores com `cpf` preenchido (vindos do Pessoas) — campos desabilitados na view **e** bloqueio real no `Admin::UsersController#update` (defesa em profundidade, já que `disabled` no HTML não impede um POST direto). Usuários sem `cpf` (admins, cadastros manuais) continuam editáveis normalmente. Isso adianta parte do espírito da task 21.6 (que fala em remover `POST`/`DELETE` do controller inteiro) de forma seletiva — só para quem já está vinculado ao Pessoas — sem esperar a troca de autenticação da 21.5. 4 testes em `test/controllers/users_controller_test.rb`.

| Task | Descrição | UC |
|---|---|---|
| 21.1 | Especificar/aceitar ADR-0006 (contrato da API canônica do Pessoas) | PRD §10 |
| 21.2 | Decidir e implementar o padrão definitivo: tabela espelho (cache local) atualizada por eventos assíncronos, **ou** manter leitura via `sticapi_client` se o volume/latência permitir — decisão explícita, não herdada por omissão | ADR-0001 |
| 21.3 | Migrar `Frequentador`/`Direito` do espelho via job (Sprints 10/12) para o padrão definitivo escolhido em 21.2 | UC-14 |
| 21.4 | Anti-corruption layer: referências por ID, nunca FK/Hibernate direto | PRD §3 |
| 21.5 | Substituir autenticação local (`has_secure_password`) por `sticapi_authenticatable`/Devise (mesmo padrão do pessoas2), usando login/senha reais do Pessoas | ADR-0001, decisão 2026-08-28 |
| 21.6 | Remover `POST`/`DELETE` de `Admin::UsersController` (criação/exclusão manual de frequentador) — só depois de 21.5 validado; manter somente leitura/listagem | Decisão 2026-08-28 |
| 21.7 | Testes: consistência eventual, reprocessamento de evento perdido, login via Sticapi (sucesso/falha), ausência de rotas de escrita manual | UC-14 |

### Sprint 22 — Desligamento da Intranet (`presenca`)

| Task | Descrição |
|---|---|
| 22.1 | Checklist de paridade final Intranet × Frequência (todas as UCs P0–P2 validadas em produção) |
| 22.2 | Confirmar que `presenca_debitoremanscentenegociavel` (código morto) não foi migrada |
| 22.3 | Cutover: redirecionar EstaçãoPonto (config, não código) para o novo sistema |
| 22.4 | Período de coexistência monitorada (definir janela com o gestor) |
| 22.5 | Desligar módulo `presenca` da Intranet |
| 22.6 | Arquivar `docs2/` (decisão pendente do PRD §9) |

---

# Resumo do Cronograma Consolidado

| Sprint | Tema | Tasks | Status |
|--------|------|-------|--------|
| 1 | Setup e Modelagem | 10 | ✅ |
| 2 | Criptografia DES + UrlBase64 | 5 | ✅ |
| 3 | Endpoints de Autenticação e Relógio | 7 | ✅ |
| 4 | Endpoints de Dados Biométricos | 6 | ✅ |
| 5 | Registro de Batidas e Finalização | 10 | ✅ |
| 6 | Integração com Estação de Ponto (JavaFX) | 10 | ✅ Parcial |
| A | Layout + Views Iniciais + Auto-Alternação | 11 | ✅ |
| R | Reconciliação Estação/Frequência | 7 | ✅ |
| 7 | Login Manual na Interface de Ponto | 9 | ✅ |
| 8 | Integração com Sistema Pessoas via Sticapi (Fundação) | 11 | ✅ Concluída (11/11) |
| 9 | Model de Estações + tela `admin/estacoes` | 5 | ✅ |
| 10 | Sincronização de Frequentadores (espelho Sticapi) | 8 | ✅ Concluída (8/8) |
| 10B | Importação em Massa de Frequentadores por Unidade (Sticapi) | 10 | ✅ Concluída (10/10) — validada contra dados reais (69 frequentadores importados) |
| 11 | Model de Regimes + tela `admin/regimes` | 4 | 📋 Planejada |
| 12 | Sincronização de Direitos/Deveres (espelho Sticapi) | 7 | 📋 Planejada |
| 13 | Grid de Frequência (registros brutos) | 4 | 📋 Planejada |
| 14 | Telas agregadas | 5 | 📋 Planejada |
| 15 | Dashboard consolidado | 3 | 📋 Planejada |
| 16 | Motor de cálculo diário (UC-05) | 4 | 📋 Planejada |
| 17 | Consolidação mensal e banco de horas (UC-06) | 4 | 📋 Planejada |
| 18 | Relatório final e retificador (UC-07, UC-12) | 4 | 📋 Planejada |
| 19 | Gestão de exceções (UC-08 a UC-11) | 5 | 📋 Planejada |
| 20 | Recálculo em lote e retroativos (UC-16, UC-17) | 3 | 📋 Planejada |
| 21 | Formalizar integração cadastral (UC-14) | 7 | 📋 Planejada |
| 22 | Desligamento da Intranet (`presenca`) | 6 | 📋 Planejada |

**Total: 143 tasks**

---

## Observações

- **Ordem recomendada:** Parte 1 (Sprints 1→8) primeiro — canal EstaçãoPonto e fundação Sticapi — depois Parte 2 (Sprints 9→22) em fases: A (9–15) → B (16–20) → C (21–22).
- **Sprint 2** pode ser paralelizada com a Sprint 1 se houver mais de um desenvolvedor.
- **Sprint 6** depende da conclusão das Sprints 1 a 5 e do acesso à Estação de Ponto real (cliente JavaFX).
- **Sprint 7** depende das Sprints A (view PontoDePresenca) e R (CRUD admin de usuários).
- **Sprint 8** é independente do fluxo de marcação de ponto (Sprints 1-7) — pode ser feita em paralelo. Entrega apenas a fundação da integração Sticapi.
- **Sprint 10** depende da Sprint 8 (fundação Sticapi) e é pré-requisito técnico para a Sprint 12 (mesma infraestrutura de job/autenticação).
- **Fase B (16-20)** tem dependência técnica fixa entre si: 16 → 17 → 18; as demais (19, 20) podem ser paralelizadas entre si após a Fase B iniciar.
- **Fase C (21-22)** só deve começar depois que a Fase B estiver com critério de saída atendido e o ADR-0006 aceito.
- **Integração com Pessoas (Sprints 10 e 12) via `sticapi_client`** — não há acesso direto ao banco de Pessoas2 nem credencial de banco compartilhada; toda comunicação é via API HTTP autenticada da Sticapi, com credenciais em `config/sticapi.yml` (Sprint 8). Horário do job diário já definido (00:00).
- **Débito técnico assumido:** o espelho local atualizado por job (Sprints 10 e 12) é uma solução simplificada — não deixar essas sprints "fecharem" sem registrar o débito formalmente (issue), para reavaliar na Sprint 21 se o padrão final continua sendo espelho via job ou migra para eventos assíncronos.
- **Testes:** Cada sprint deve incluir testes unitários e/ou de integração. Não postergar testes para o final.
- **Validação:** Ao final de cada sprint, rodar `rails test` completo e garantir que não há regressão.
- **Tela `relatorio_terceirizados`** não tem colunas definidas no layout atual — levantamento de requisito pendente antes da Sprint 14.
- **View `presenca_frequentadorestacao`** precisa ser validada em produção antes da Sprint 21 (cache/eventos).
- **ADR-0006** (contrato API do Pessoas) precisa ser criado e aceito antes da Sprint 21.
- **Destino de `docs2/`** — decisão do gestor, não bloqueia sprints técnicas.
- Endpoints periféricos (`PrediosPermitidos`, fotos, auto-update de estação) tratados caso a caso, sob demanda.
- **Status geral:** Sprints 1-5 concluídas (25 testes, 0 falhas). Sprint 6 parcialmente concluída — API validada via curl, mas testes com estação JavaFX real pendentes (Maven não disponível). Sprint A e R concluídas (127 testes, 0 falhas). Sprint 7 concluída. Sprint 8 concluída (11/11). Sprint 9 concluída. Sprint 10 concluída (8/8, 207 testes, 1 falha pré-existente de timezone). Sprints 11–22 planejadas/pendentes.

---
**Fontes:** `PRD-POC-API-PONTO.md`, `docs/PRD-FREQUENCIA.md`, `docs/03-dominio/07-casos-uso.md`, ADRs 0001–0005, inspeção direta de `Frequencia/api-ponto`.
