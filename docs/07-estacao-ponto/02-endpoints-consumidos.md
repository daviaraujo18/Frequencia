# EstaçãoPonto — Endpoints Consumidos na Intranet

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Repoósito centralizado dos endpoints HTTP que a EstaçãoPonto chama na Intranet. Esta é a interface que o novo Frequência deve reproduzir (camada de compatibilidade) para evitar alterações no desktop.

> **DECISÃO (ADR-0003):** O Frequência exporá exatamente esses mesmos endpoints no namespace `/presenca/...` para manter compatibilidade com a EstaçãoPonto existente. A PoC `api-ponto/` (ver `docs/05-migracao/00-codigo-preexistente-poc.md`) já implementa estes endpoints.

## Tabela Consolidada de Endpoints

| # | Método | Endpoint | Função | Implementado na PoC? |
|---|--------|----------|--------|----------------------|
| 1 | GET | `/presenca/ValidarFrequentador` | Autentica usuário (login + senha criptografados em DES) | ✅ |
| 2 | GET | `/presenca/DynFrequentadoresEstacao/` | Baixa lista de usuários ativos com `digitais_hash` (formato serializado) | ✅ |
| 3 | GET | `/presenca/DynHashFrequentadoresEstacao/` | Retorna MD5 dos dados serializados (controle de versão) | ✅ |
| 4 | GET | `/presenca/CarregaRelogioAtual` | Retorna timestamp em ms (sincronização de horário da estação) | ✅ |
| 5 | POST | `/presenca/ajax/SincronizarRegistrosPonto` | Recebe lote de batidas DES-criptografadas | ✅ |
| 6 | GET | `/presenca/AdicioneEstacao` | Heartbeat ("estou vivo", versão, estado) | ✅ |
| 7 | GET | `/presenca/PrediosPermitidos/` | Lista prédios autorizados para a estação (não implementado na PoC) | ❌ (fora escopo PoC) |
| 8 | GET | `/presenca/InicializarPonto` | Redireciona para `PontoDePresenca` após init | ✅ |
| 9 | GET | `/presenca/IniciarPonto` | Página-resumo carregada no WebView (verifica conexão) | ✅ |
| 10 | GET | `/presenca/PontoDePresenca` | Interface WebView que chama `alert()` para a estação | ✅ |
| 11 | GET | `/presenca/Frequentador` | (desconhecido — provavelmente detalhes de um frequentador específico) | ✅ |
| 12 | GET | `/presenca/ProblemaRegistro` | (desconhecido — talvez tratamento de erro de batida) | ✅ |

## Contrato Detalhado dos Endpoints Críticos

### EP-01 — `GET /presenca/ValidarFrequentador`

**Parâmetros (query string):**
| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `loginAccessKey` | string | Username DES-criptografado (chave `"cryp:gpf"`) + UrlBase64 |
| `plainPassword` | string | Senha DES-criptografada (mesma chave) + UrlBase64 |
| `codAtivacao` | string | Código de ativação da estação |

**Resposta** (string pura, NÃO JSON):
| Body | Significado |
|------|-------------|
| `"<id>"` (ex: `"42"`) | Sucesso — ID do usuário |
| `"USUARIO_SENHA_INVALIDOS"` | Credenciais inválidas ou usuário inativo |
| `"USUARIO_SEM_PERMISSAO_MANUAL"` | Frequentador sem autorização para login manual |
| `"ESTACAO_SEM_PERMISSAO_PARA_BATIDA_MANUAL"` | Estação não liberada |

> **EVIDÊNCIA:** PoC `api-ponto/app/controllers/presenca/validar_frequentador_controller.rb` (HEAD) → implementa exatamente este contrato. `User.ativos.find_by(username: ...)` + `user.authenticate(password)` (bcrypt).

### EP-02 — `GET /presenca/DynFrequentadoresEstacao/`

**Parâmetros:** nenhum.

**Resposta:** String serializada, formato:
```
<id>;<username>;<nome>;<digitalHash>;;false;N;0'<id>;<username>;...;0'
```
- Separador entre campos de um registro: `;`
- Separador entre registros: `'` (apóstrofo)
- `username` = matrícula
- `false` = campo `isAdmin` (sempre false na PoC)
- `N` = sexo (não informado na PoC)
- `0` = predioId (fora de escopo na PoC)

**Exemplo real (PRD §8.2):**
```
1;jose.silva;José Silva;AB12CD34...;;false;N;0'2;maria.santos;Maria Santos;EF56GH78...;;false;N;0'
```

### EP-03 — `GET /presenca/DynHashFrequentadoresEstacao/`

**Parâmetros:** nenhum.
**Resposta:** String MD5 hex maiúsculo (32 caracteres `[A-F0-9]`), calculado sobre a string retornada por EP-02.

### EP-04 — `GET /presenca/CarregaRelogioAtual`

**Parâmetros:** nenhum.
**Resposta:** String numérica (timestamp em milissegundos). Ex: `"1782000000000"`.

### EP-05 — `POST /presenca/ajax/SincronizarRegistrosPonto`

**Parâmetros (body form-urlencoded):**
| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `registros` | string | Lote DES + UrlBase64. Após descriptografar, linhas no formato `<id>-<dd:MM:yyyy:HH:mm:ss>` |
| `codAtivacao` | string | Código de ativação |

**Resposta:** `"sincronizado"` (string pura).

### EP-06 — `GET /presenca/AdicioneEstacao` (heartbeat)

**Parâmetros:**
| Parâmetro | Descrição |
|-----------|-----------|
| `codAtivacao` | URL encoded |
| `versao` | ex: `"1.2"` |
| `estadoEstacao` | `"FUNCIONANDO"` |

**Resposta:** `true`/`false` (logado na estação).

### EP-07 — `GET /presenca/PrediosPermitidos/`

**Parâmetros:** `codAtivacao`.
**Resposta:** `"<id1>;<id2>;..."` (separado por `;`).
**Status:** Não implementado na PoC (fora de escopo). Verificar se a Intranet existe e se a EstaçãoPonto realmente chama.

### EP-08/09/10 — `InicializarPonto`, `IniciarPonto`, `PontoDePresenca`

Servem páginas HTML/JSP renderizadas dentro do WebView da estação. O conteúdo precisa manter:
- jQuery (ou stub compatível) respondendo a chamadas `alert()` interceptadas pelo `OnAlertListener` Java.
- Função `sincronizaPonto(dados, codAtivacao)` que faça POST para EP-05.

> **EVIDÊNCIA:** PoC `api-ponto/app/views/presenca/ponto_de_presenca/index.html.erb` (git) — contém HTML com jQuery stub inline, sem dependência de CDN. Sprint 6 Resultados em `SPRINT-PLAN.md:137` confirma: "PontoDePresenca com jQuery stub inline".

## Lacunas Documentais

- 🤔 **DÚVIDA:** O PRD lista EP-11 (`Frequentador`) e EP-12 (`ProblemaRegistro`) em `routes.rb` da PoC, mas a documentação não detalha o contrato. **PENDÊNCIA:** Investigar implementação PoC (`git show HEAD:api-ponto/app/controllers/presenca/frequentador_controller.rb`) e a documentação da Intranet rural.
- 🤔 **DÚVIDA:** A PoC não implementa EP-07 (`PrediosPermitidos`). Precisamos confirmar se a EstaçãoPonto ainda chama este endpoint e o que a Intranet retorna hoje.

## Formato de Criptografia (cross-reference)

Confirme em `PRD-POC-API-PONTO.md §6.2` e §12 (lacuna L01) e na doc canônica ETAPA 8.1:
- Algoritmo: **DES/CBC/PKCS5Padding**
- Chave: `"cryp:gpf"` (hardcoded)
- IV: igual à chave
- Encoding: **UrlBase64 custom** — substitui `+` → `-`, `/` → `_`, remove padding `=`
- Implementação de referência: PoC `api-ponto/app/services/crypto_des.rb` (git HEAD)

---
**Última atualização:** 2026-08-04
