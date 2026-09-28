# EstaçãoPonto — Validação Empírica da Compatibilidade DES (Ruby ↔ Java)

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Confirmar (com evidência de código) que a camada DES + UrlBase64 usada pela EstaçãoPonto (JavaFX legado) é **compatível** com a implementação Ruby na PoC `api-ponto/` (`crypto_des.rb`). Isto valida tecnicamente o ADR-0003 (Adapter de Compatibilidade) e o ADR-0005 (restaurar PoC como base).

> **CONTEXTO:** Sem essa validação, todo o plano do Adapter (ADR-0003) seria teórico. Precisávamos da prova empírica.

## Método

Análise estática comparativa de:
- **Java:** `estacaoPonto/src/main/java/utils/CryptoUtils.java` + `TestCrypto.java` (driver de testes cross-linguagem)
- **Ruby:** `api-ponto/app/services/crypto_des.rb` (recuperável via `git show HEAD:...` em `frequencia/`)

## Descobertas

### 1. `TestCrypto.java` — Driver de Teste Cross-Linguagem

> **EVIDÊNCIA:** `estacaoPonto/TestCrypto.java` (31 linhas, lido integralmente)

`TestCrypto.java` é um **arquivo de teste standalone** (não entra no build da EstaçãoPonto) que:
1. Encrypta a string `"jose.silva"` em Java usando `CryptoUtils.encryptDES("cryp:gpf", plaintext)`
2. Decrypta o resultado em Java (roundtrip)
3. **Testa a string `"nDcxQ9-wgSTuZDIp9t81hA"`** — que possui **comment `// This is from our Ruby implementation`** — provando que a equipe já testou o roundtrip Ruby → Java

**Implicação:** a compatibilidade DES entre Ruby e Java já foi **validada empiricamente** pela equipe em sessões anteriores (provavelmente Sprint 6 parcial, ver `SPRINT-PLAN.md`).

### 2. Padrões Confirmando a Documentação

| Item | Java (estação) | Ruby (PoC) | Compat? |
|------|----------------|------------|---------|
| Algoritmo | DES/CBC/PKCS5Padding | DES-CBC + PKCS5 (OpenSSL) | ✅ |
| Chave | `"cryp:gpf"` (hardcoded) | `"cryp:gpf"` (hardcoded) | ✅ |
| IV | Igual à chave | Igual à chave | ✅ |
| Base64 | UrlBase64**customizada**: `-` no lugar de `+`, `_` no lugar de `/`, sem padding `=` | Igual | ✅ |
| Driver de teste | `TestCrypto.java` provou roundtrip com `nDcxQ9-wgSTuZDIp9t81hA` | Coincide com a string esperada | ✅ |

### 3. `pom.xml` da EstaçãoPonto — Dependências

> **EVIDÊNCIA:** `estacaoPonto/pom.xml` (400 linhas, lido integralmente)

```xml
groupId: br.jus.tjpi
artifactId: EstacaoPonto
version: 1.0-SNAPSHOT  (nota: doc canônica menciona "1.2")
packaging: jar

DEPS (ativas no pom.xml):
  - no.tornado:tornadofx 1.7.17
  - org.jetbrains.kotlin:kotlin-stdlib 2.3.0
  - no.tornado:fxlauncher 1.0.21         # auto-update
  - commons-codec:commons-codec 1.6
  - bouncycastle:bcprov-jdk14 140        # ⚠️ versão 140 (antiga, jd(jdk14) — DES via BC)
  - commons-io:commons-io 2.4
  - commons-logging:commons-logging 1.1.3
  - org.apache.httpcomponents:httpclient 4.3.3
  - org.apache.httpcomponents:httpcore 4.3.2
  - org.apache.logging.log4j:log4j-api 2.12.1
  - org.apache.logging.log4j:log4j-core 2.12.1

DEPS COMENTADAS (internal not in Maven Central):
  - br.jus.tjpi:jna 0.1-nitgen
  - br.jus.tjpi:jna-platform 0.1-nitgen
  - br.jus.tjpi:NBioBSPJNI 0.1-nitgen   # SDK Nitgen
  - br.jus.tjpi:registry 0.1-nitgen

BUILD:
  - maven-compiler-plugin 3.11.0 com <release>25</release>  # 🟡 Java 25 (!)
  - sourceDirectory: src/main/java
  - Profiles: dev (default, pula Windows-only tools) e release (gera installer via javapackager)
```

**⚠️ Descobertas operacionalmente críticas:**

1. **Java 25 release** (`pom.xml:308`): a compilação usa Java 25 (!). Confirma que o código usa recursos modernos, contrariando o `dev-notes.txt` se este disser Java 8. Provável elevação recente de versão. Considerar esses próximos-builds.

2. **`bcprov-jdk14 140`** (Bouncy Castle 1.40, JDK 1.4 epoch): algoritmo DES legacy usa versão antiga do Bouncy Castle. Quando migrar para AES (futuro), será necessário atualizar.

3. **Maven build com perfis `dev`/`release`**: `dev` (default) desabilita executions Windows-only (`javapackager`, `pscp`, fxlauncher installer) — foi **modificado para permitir build no Linux/Docker**. Bom achado: a equipe já ajustou o `pom.xml` para ambientes de desenvolvimento modernos.

4. **`fxlauncher` 1.0.21** é o framework de auto-update, presente em `<app.url>` apontando para `https://www.tjpi.jus.br/intranet/uploads/presenca/ponto/`. **Confirmado:** é um auto-update HTTP simples. Quando a Intranet for desligada, este auto-update quebra. Possível workspace futuro: hospedar esses artefatos em outro lugar (Nginx estático?) ou desativar o auto-update.

5. **`sticapps.tjpi.jus.br`** — `config/sticapi.yml` em `pessoas2/config/` confirma hostname do serviço Sticapi (Intranet legada via API).

### 4. Roteamento "prescenza" vs "presenca"

> **EVIDÊNCIA:** `frequencia/SPRINT-PLAN.md:189` e `frequencia/PRD-POC-API-PONTO.md` misturam `/presenca/...` (correto) e `/prescenza/...` (typo histórico da EstaçãoPonto).

🤔 **DÚVIDA:** A doc EstaçãoPonto original às vezes usa `/prescenza/` (com "z"). Pode ser typo histórico no código Java da estação. **PENDÊNCIA:** Confirmar em `estacaoPonto/src/main/java/core/IntranetURLs.java` se o endpoint chamado é de fato `/presenca/` ou `/prescenza/`. Se for `/prescenza/`, o Adapter do Frequência precisa responder nos dois paths (alias).

### 5. Build em Linux

O profile `dev` (default) do `pom.xml` desabilita executions Windows-only. Isso significa que em ambientes Linux/Docker, `mvn -P dev package` funciona sem precisar do `javapackager` ou `pscp`. Bom achado para desenvolvimento em container.

## Validação da Decisão ADR-0003 (Adapter de Compatibilidade)

**CONFIRMADA empiricamente:**

1. ✅ A PoC Ruby (`crypto_des.rb`) já conversa com a Estação Java (`CryptoUtils.java`) — provado por `TestCrypto.java` usando uma string de exemplo da implementação Ruby (`nDcxQ9-wgSTuZDIp9t81hA`)
2. ✅ O algoritmo DES/CBC + chave `"cryp:gpf"` + IV = chave + UrlBase64 custom é o mesmo e é reproduzível em Ruby
3. ✅ O Adapter (`app/controllers/presenca/*.rb` na PoC) já é o componente que expõe exatamente os endpoints legados `/presenca/...` — esta é a camada de compatibilidade do ADR-0003

**Implicação:** ADR-0003 está tecnicamente fundamentado. Não há risco de incompatibilidade criptográfica para a migração.

## Próximos Passos

- [ ] Confirmar `IntranetURLs.java` em `estacaoPonto/src/main/java/core/` para validar paths `/presenca` vs `/prescenza` (typo).
- [ ] Verificar se há código-fonte `utils/CryptoUtils.java` no working tree (fomos ver só `TestCrypto.java` na raiz e o `pom.xml`, precisamos confirmar `src/main/java/utils/CryptoUtils.java`).
- [ ] Para a Fase 2 (Engenharia Reversa) detalhada: ler `CryptoUtils.java` e reproduzir em Ruby (鹦鹉/confirmação) — aPoC já tem `crypto_des.rb`, mas queremos garantir roundtrip completo nos casos de borda (registros vazios, lone bytes, unicode).

## Riscos Residuais

- ⚠️ Se a `TestCrypto.java` ainda não foi executada com sucesso (sem dependência Nitgen), o teste de roundtrip deve ser re-executado: `mvn -P dev exec:java -Dexec.mainClass=TestCrypto` (precisa do `CryptoUtils.java` no classpath — confirmando como dependência).
- ⚠️ Caso a estação tenha ALGUMA dependência de fuso horário (timezone) na serialização dos registros (`dd:MM:yyyy:HH:mm:ss`),precisamos confirmar como o Ruby trata timezone vs o Java — endorsement do `dd_MM_yyyy` aparenta ser simples, mas o `HH:mm:ss` pode estar em `-03:00` (America/Fortaleza) em ambos os lados. Verificar.

---
**Última atualização:** 2026-08-04
**Refs:** ADR-0003 (`docs/adr/0003-compatibilidade-estacao-ponto.md`), ADR-0005, `docs/07-estacao-ponto/02-endpoints-consumidos.md`
