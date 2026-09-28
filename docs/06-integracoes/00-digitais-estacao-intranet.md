# Armazenamento de Digitais — EstaçãoPonto ⇄ Intranet

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Documentar, de forma completa e verificada no código-fonte, **onde e como as digitais biométricas do ponto eletrônico são armazenadas, transmitidas e consumidas** entre os dois sistemas:

- **Intranet** (legado, Java 6 + MySQL) — lado **servidor**: persiste e expõe as digitais.
- **EstaçãoPonto** (desktop JavaFX + SDK Nitgen) — lado **cliente**: captura, indexa e verifica as digitais.

Este documento fecha o ponto que estava em aberto em discussões anteriores ("o envio/armazenamento de digitais no servidor não está 100% fechado; precisaríamos das especificações exatas do endpoint de upload e do formato"). **Aqui o fluxo está confirmado com evidências do código.**

> **Fonte de verificação:** repositórios `/Integracao/intranet` e `/Integracao/estacaoPonto` (data da exploração: 2026-08-05).
> **Fonte canônica da EstaçãoPonto:** `/frequencia/documentacao-estacao-ponto.md` (§4.3–4.5 e §8 sobre digitais) e resumo em `docs/07-estacao-ponto/02-endpoints-consumidos.md`.

---

## 1. Conceito-chave: o que é armazenado

A digital **não é armazenada como imagem** no servidor. O que viaja e persiste é o **hash gerado pelo SDK Nitgen**, no formato **`FIR_TEXTENCODE`** (representação textual/Base64 do template biométrico — é o que o `NBioBSPJNI` retorna em `GetTextFIRFromHandle`).

| Termo | Significado |
|-------|-------------|
| `FIR_TEXTENCODE` | Formato de texto (Base64) do template biométrico Nitgen. É a "moeda" usada entre estação e intranet |
| `digitaisHash` | Nome da coluna/campo onde esse hash é persistido no servidor |
| `data.db` | Arquivo local (IndexSearch binário) na estação onde os hashes são indexados p/ reconhecimento |

> ⚠️ Por ser um **template biométrico** (não a imagem), o dado é sensível e seu vazamento permitiria reconstrução/verificação da digital. (Relevante para segurança — ver débito `DT` sobre DES em `docs/07-estacao-ponto/01-resumo-arquitetura.md`.)

---

## 2. Visão geral do ciclo de vida da digital

```
[ CADASTRO ]                                          [ RECONHECIMENTO / BATIDA ]
                                                      ┌──────────────────────────┐
 Intranet (servidor)  ◄──────── INTEGRAÇÃO ─────────  │ EstaçãoPonto (desktop)   │
 ┌────────────────────────────┐   hash FIR            │  – NiGen IndexSearch      │
 │ presenca_frequentador      │   (texto/Base64)      │  – data.db (index p/1:N)  │
 │   .digitaisHash  ▲         │                       └──────────────────────────┘
 │                   │        │
 │ FrequentadorActions         │
 │   .update()  ▶ grava        │
 │    (form WebView #digitaisHash)                        Download/Frequência:
 └────────────────────────────┘   ▼                       DynFrequentadoresEstacao
   VIEW presenca_frequentadorestacao  ────────►          DynHashFrequentadoresEstacao
   (expoe digitalHash)                                  (MD5 p/ controle de versão)
```

---

## 3. Fluxo de CADASTRO / ATUALIZAÇÃO da digital (lado servidor)

### 3.1 Descoberta importante sobre "endpoint de upload remoto"

**Não existe um endpoint de upload de digitais dedicado em uso.** O action `modules.presenca.actions.ajax.CadastrarDigital` existe no backend, mas **não é chamado** por nenhum JavaScript do frontend web (`intranet/web`) nem pela EstaçãoPonto (verificação por busca exaustiva em `intranet/web` e `estacaoPonto/src`).

O cadastro real acontece **pelo submit do formulário web** da tela `Frequentador` (ações `create`/`update`), renderizada **dentro do WebView da EstaçãoPonto**.

### 3.2 Participantes

| Componente | Arquivo (evidência) | Papel |
|------------|----------------------|-------|
| Campo formulário | `intranet/web/WEB-INF/tags/modules/presenca/formDigitais.tag:34` | `<input type="hidden" ... id="digitaisHash" name="digitaisHash">` |
| Form create/update | `intranet/web/modules/presenca/includes/forms/frequentador.jsp` | Inclui `<fpg:formDigitais/>` nas abas "Digitais" (create `:24`, update `:82`), protegido por `presencaGerenciaFrequentadores` / `presencaCadastroDigital` |
| Action que persiste | `intranet/src/modules/presenca/actions/FrequentadorActions.java:158` | `frequentadorAtualizado.setDigitaisHash(input.getStringValue("digitaisHash"));` no `update()` |
| Bean | `intranet/src/modules/presenca/beans/Frequentador.java:56` | Campo `private String digitaisHash;` (getter/setter `:130-136`) |
| Injeção do hash na estação | `estacaoPonto/src/main/java/controllers/MainController.java:94-109` | `jQuery('#digitaisHash').val(digitaisHash)` via JS |
| Controle de botões (setup) | `estacaoPonto/src/main/java/listeners/ChangeUrlListener.java:39-48` | Mostra "Cadastrar Digitais" em `type=create`, "Atualizar Digitais" em `type=update` |

### 3.3 Sequência de cadastro (via WebView)

```
Administrador ──► WebView(JSP Frequentador) ──► EstaçãoPonto ──► LeitorDigital(Nitgen)
    │                    │                            │                │
    │ abre tela          │                            │                │
    │  (type=create/     │                            │                │
    │   type=update)     │                            │                │
    │                    │ clica "Cadastrar/          │                │
    │                    │  Atualizar Digitais"       │                │
    │                    │                            │ enroll()        │
    │                    │                            ├───────────────►│ abre janela+
    │                    │                            │                │ captura dedo
    │                    │                            │◄───────────────┤ retorna
    │                    │ jQuery('#digitaisHash')    │                │ FIR_TEXTENCODE
    │                    │   .val(digitaisHash) ◄─────┤                │
    │                    │ changeInfoDigital(...)     │                │
    │ submete formulário │                            │                │
    │  (POST digitaisHash)                            │                │
    ▼                    ▼                            │                │
 FrequentadorActions.update() _______________________________________
    setDigitaisHash(digitaisHash)  →  Dao.saveOrUpdate(frequentador)
                  │
                  ▼
   presenca_frequentador.digitaisHash  (PERSISTIDO NO SERVIDOR)
```

**Código-chave (EstaçãoPonto) — injeção do hash:**
```java
// MainController.cadastrarDigital()
String digitaisHash = getLeitorDigital().enroll();          // SDK Nitgen -> FIR
...
The.inserirJavascript(tela.getWebEngine(),
    "jQuery('#digitaisHash').val('" + digitaisHash + "');"); // injeta no form web
The.inserirJavascript(tela.getWebEngine(),
    "changeInfoDigital('success','Digitais identificadas!');");
```

**Código-chave (Intranet) — persistência:**
```java
// FrequentadorActions.update()
frequentadorAtualizado.setDigitaisHash(input.getStringValue("digitaisHash"));
...
Dao.saveOrUpdate(frequentadorAtualizado);   // grava presenca_frequentador.digitaisHash
```

> 💡 **Ação de "Atualizar Digitais" (type=update)** usa o mesmíssimo caminho: o botão aparece em `ChangeUrlListener` e o hash atualizado é colocado no mesmo campo `#digitaisHash` antes do submit.

### 3.4 O action legado `CadastrarDigital` (não usado)

`intranet/src/modules/presenca/actions/ajax/CadastrarDigital.java`:

```java
public String execute() {
    String dataDescrypt = CryptoUtil.decryptDES("cryp:gpf", data);   // AES-... DES, chave "cryp:gpf"
    String[] dados = dataDescrypt.split(";");
    // frequentadorId; digitaisHash; cpfCadastrador
    ...
    f.setDigitaisHash(digitaisHash);     // persistiria a digital
    Dao.saveOrUpdate(f);
}
```

**Conclusão:** é um endpoint **legado/não conectado** ao fluxo atual do frontend. Ele *persistiria* `digitaisHash` e, pela convenção futurepages, ficaria em `/presenca/ajax/CadastrarDigital` (POST, parâmetro `data` criptografado DES). **Não é pré-requisito para a PoC**, pois o caminho em uso é o formulário web.

---

## 4. Fluxo de LEITURA / DOWNLOAD das digitais (estação → reconhecimento)

### 4.1 Endpoints consumidos pela estação

| Endpoint (GET) | Finalidade | Implementado na PoC? |
|----------------|------------|----------------------|
| `/presenca/DynFrequentadoresEstacao/` | Baixa lista de frequentadores com `digitalHash` (8 campos serializados) | ✅ (EP-02) |
| `/presenca/DynHashFrequentadoresEstacao/` | Retorna MD5 da série para controle de versão | ✅ (EP-03) |

*Ref.: `docs/07-estacao-ponto/02-endpoints-consumidos.md` (EP-02/EP-03).*

### 4.2 Download com controle de versão por MD5

- `estacaoPonto/src/main/java/core/DownloadFrequentadoresService.java`:
  - `temNovasDigitais()` chama `DynHashFrequentadoresEstacao` e compara com hash local em `{AppData}/data/hash`. Só baixa quando mudou.
  - `downloadDigitais()` chama `DynFrequentadoresEstacao` e retorna a string serializada.
- `DynHashFrequentadoresEstacao` → `FrequentadorServices.gerarHashFrequentadorEstacao()` (intranet) calcula MD5 sobre a string de `montarFrequentadoresParaEstacoess()`:
  ```java
  MessageDigest md = MessageDigest.getInstance("MD5");
  md.update(dados.getBytes());
  String myHash = DatatypeConverter.printHexBinary(md.digest()).toUpperCase();
  ```

### 4.3 Formato serializado (o "hash/arquivo" transmitido)

`FrequentadorServices.montarFrequentadoresParaEstacoess()` monta registros com **8 campos `;`** separados por **`'`**:

```
<id>;<matricula>;<nome>;<digitalHash(FIR)>;<urlFoto>;false;<sexo>;<predioId>'<id2>;...
```

Exemplo:
```
123;JC12345;JOÃO DA SILVA;<HASH_FIR>;/intranet/fotos/joao.jpg;false;M;5'456;JC23456;...
```

| Pos | Campo | Origem (view `presenca_frequentadorestacao`) |
|-----|-------|-----------------------------------------------|
| 0 | ID do frequentador | `presenca_frequentador.id` |
| 1 | Matrícula | `tjpi_vinculado.matricula` |
| 2 | Nome completo | `tjpi_pessoafisica.nomeCompleto` |
| 3 | **Hash da digital (FIR)** | `presenca_frequentador.digitaisHash` |
| 4 | URL da foto | `tjpi_imagem.cadastroFotoId` |
| 5 | É administrador | `false` (fixo no service atual) |
| 6 | Sexo | `tjpi_pessoafisica.sexo` |
| 7 | ID do prédio de trabalho | `global_orgao.predioSede_id` |

### 4.4 A view que alimenta as estações

`intranet/src/modules/presenca/schema/scripts/view_presenca_frequentadorestacao.sql`:

```sql
SELECT f.id, vp.matricula, pf.nomeCompleto,
       f.digitaisHash AS digitalHash,
       i.cadastroFotoId AS foto, pf.sexo,
       IF(o.predioSede_id IS NULL, 0, o.predioSede_id) AS predio_id
FROM presenca_frequentador f
...
WHERE f.ativo IS TRUE
  AND f.digitaisHash <> ''      -- só quem TEM digital participa
ORDER BY f.id ASC;
```

> A estação só carrega no leitor quem tem `digitaisHash <> ''`.

### 4.5 Indexação e reconhecimento na estação

- `estacaoPonto/src/main/java/core/leitura/LeitorDigital.java`:
  - `addDigitalToIndexSearch(Map id→hash)` — adiciona cada `FIR` ao `IndexSearch` do Nitgen e chama `SaveDB({data}/data.db)`.
  - `loadDB()` / `clearDB()` — carregar/limpar o índice local.
  - `searchDigitalOnIndexSearchEngine(hash)` → `indexSearchEngine.Identify(...)` retorna o `ID` do frequentador (ou `-1`).
- `estacaoPonto/src/main/java/core/leitura/VerificacaoDigitalService.java`:
  - Captura → `searchDigitalOnIndexSearchEngine(digitalHash)` → define `EventoLeitura` (`DIGITAL_RECONHECIDA`/`_RESSALVA_PREDIO`/`NAO_RECONHECIDA`) conforme o id e validação de prédio.
- `estacaoPonto/src/main/java/async/PreProcessandoService.java` — loop assíncrono que detecta dedo (`temDedo()`) e captura (`capturarDigital()`).

---

## 5. Modelo de dados consolidado (armazenamento físico)

| Sistema | Onde | Tipo | Formato |
|---------|------|------|---------|
| **Intranet (servidor)** | `presenca_frequentador.digitaisHash` | `String` (coluna) | `FIR_TEXTENCODE` (Base64) |
| Intranet (visão p/ estações) | view `presenca_frequentadorestacao.digitalHash` | derivada | idem |
| **EstaçãoPonto (local)** | `{AppData}/data/data.db` | binário (IndexSearch) | índice Nitgen |
| EstaçãoPonto (controle versão) | `{AppData}/data/hash` | texto | MD5 hex maiúsculo |

---

## 6. Implicações para o Frequência (migração / PoC)

1. **Não precisa** criar um endpoint de upload de digitais: o contrato atual passa pelo formulário web `Frequentador?type=create/update` (campo `#digitaisHash`) + endpoints de download `DynFrequentadoresEstacao`/`DynHashFrequentadoresEstacao`.
2. A PoC (`api-ponto`, namespace `/presenca`) **já implementa** EP-02 e EP-03 (ver `docs/07-estacao-ponto/02-endpoints-consumidos.md`). Falta garantir a **compatibilidade do WebView** com o formulário `Frequentador` (para cadastro/atualização de digitais) — este é o ponto sensível, pois hoje a estação injeta o hash no form web.
3. O hash `FIR_TEXTENCODE` precisa ser **tratado como dado sensível** (template biométrico).
4. O action legado `CadastrarDigital` (DES) pode ser descartado ou mantido só como referência; **não** é usado pelo fluxo ativo.

---

## 7. Referências e evidências-chave

- `intranet/src/modules/presenca/actions/FrequentadorActions.java` (`update()`, `:147-184`)
- `intranet/src/modules/presenca/actions/ajax/CadastrarDigital.java` (legado, não usado)
- `intranet/src/modules/presenca/services/FrequentadorServices.java` (`montarFrequentadoresParaEstacoess()`, `gerarHashFrequentadorEstacao()`)
- `intranet/src/modules/presenca/beans/Frequentador.java` (`digitaisHash`)
- `intranet/src/modules/presenca/beans/FrequentadorEstacao.java` (bean da view)
- `intranet/src/modules/presenca/schema/scripts/view_presenca_frequentadorestacao.sql`
- `intranet/web/WEB-INF/tags/modules/presenca/formDigitais.tag`
- `intranet/web/modules/presenca/includes/forms/frequentador.jsp`
- `estacaoPonto/src/main/java/controllers/MainController.java` (`cadastrarDigital()`)
- `estacaoPonto/src/main/java/core/DownloadFrequentadoresService.java`
- `estacaoPonto/src/main/java/core/DadosFrequentadores.java`
- `estacaoPonto/src/main/java/core/leitura/LeitorDigital.java`
- `estacaoPonto/src/main/java/core/leitura/VerificacaoDigitalService.java`
- `estacaoPonto/src/main/java/async/PreProcessandoService.java`
- `estacaoPonto/src/main/java/listeners/ChangeUrlListener.java`
- `estacaoPonto/docs/relatorio-interacao-presenca-estacao.md` (§4.3–4.5, §8)
- `docs/07-estacao-ponto/02-endpoints-consumidos.md` (EP-02/EP-03)

---

**Última atualização:** 2026-08-05
