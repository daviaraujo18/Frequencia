# Plano de Sprints — PoC API de Ponto (Rails 8)

> Baseado no PRD-POC-API-PONTO.md v1.0

---

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

## Resumo do Cronograma Estimado

| Sprint | Tema | Tasks | Esforço Estimado |
|--------|------|-------|------------------|
| 1 | Setup e Modelagem | 10 | Alta |
| 2 | Criptografia DES + UrlBase64 | 5 | Média |
| 3 | Endpoints de Autenticação e Relógio | 7 | Alta |
| 4 | Endpoints de Dados Biométricos | 6 | Média |
| 5 | Registro de Batidas e Finalização | 10 | Alta |

**Total: 38 tasks**

---

## Observações

- **Ordem recomendada:** Seguir a numeração das sprints (1 → 2 → 3 → 4 → 5), pois há dependências (Sprint 2 é pré-requisito para 3 e 5).
- **Sprint 2** pode ser parallelizada com a Sprint 1 se houver mais de um desenvolvedor.
- **Testes:** Cada sprint deve incluir testes unitários e/ou de integração. Não postergar testes para o final.
- **Validação:** Ao final de cada sprint, rodar `rails test` completo e garantir que não há regressão.

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

## Resumo do Cronograma Estimado

| Sprint | Tema | Tasks | Status |
|--------|------|-------|--------|
| 1 | Setup e Modelagem | 10 | ✅ |
| 2 | Criptografia DES + UrlBase64 | 5 | ✅ |
| 3 | Endpoints de Autenticação e Relógio | 7 | ✅ |
| 4 | Endpoints de Dados Biométricos | 6 | ✅ |
| 5 | Registro de Batidas e Finalização | 10 | ✅ |
| **6** | **Integração com Estação de Ponto (JavaFX)** | **10** | **✅ Parcial** |

**Total: 48 tasks**

---

## Observações

- **Ordem recomendada:** Seguir a numeração das sprints (1 → 2 → 3 → 4 → 5 → 6), pois há dependências (Sprint 2 é pré-requisito para 3 e 5).
- **Sprint 2** pode ser parallelizada com a Sprint 1 se houver mais de um desenvolvedor.
- **Sprint 6** depende da conclusão das Sprints 1 a 5 e do acesso à Estação de Ponto real (cliente JavaFX).
- **Testes:** Cada sprint deve incluir testes unitários e/ou de integração. Não postergar testes para o final.
- **Validação:** Ao final de cada sprint, rodar `rails test` completo e garantir que não há regressão.
- **Status geral:** Sprints 1-5 concluídas (25 testes, 0 falhas). Sprint 6 parcialmente concluída — API validada via curl, mas testes com estação JavaFX real pendentes (Maven não disponível).

