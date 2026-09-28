# EstaçãoPonto — Resumo da Arquitetura

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Síntese da arquitetura da EstaçãoPonto para consulta rápida do agente de migração. **Não substitui** a fonte canônica: `/frequencia/documentacao-estacao-ponto.md`. Toda afirmação abaixo tem referência cruzada àquela documentação.

## Visão Geral

| Aspecto | Valor |
|---------|-------|
| **Tipo** | Aplicação Desktop standalone (kiosk) |
| **Stack** | JavaFX 8 (UI) + SDK Nitgen NBioBSPJNI (biometria) + JNA (Windows hook) |
| **Build** | Maven (`pom.xml`) |
| **Versão software** | 1.2 (`core/EstacaoPonto.java:25`) |
| **Estrutura** | MVC simplificado: `core/`, `controllers/`, `view/`, `async/`, `listeners/`, `utils/`, `exception/`, `core/leitura/` |
| **Linhas de código** | ~2.500 (28 classes Java) |
| **Testes** | ❌ Zero (debit técnico DT05) |
| **Persistência local** | Sem BD relacional — arquivos criptografados (DES), Map serializado, IndexSearch binário, Registro Windows |

## Camadas Principais

```
Application (EstacaoPonto.java, Main.fxml)
    ↓
Controller  (MainController.java)
    ↓
View        (TelaPonto.java com WebView + leitor)
    ↓
Async Services:
    PreProcessandoService   (loop captura digital)
    ThreadRelogio           (relógio síncrono servidor)
    DownloadFrequentadoresService
    CacheDownloadService
    PrediosPermitidosService
    ValidarBatidaManualService
    VivoOuMortoService      (heartbeat)
    ConexaoIntranetService
    ↓
Core        (LeitorDigital + SDK Nitgen IndexSearch)
```

## Comunicação com a Intranet

A EstaçãoPonto integra-se à Intranet de **três formas distintas** (importante para a migração):

| # | Mecanismo | Função | Risco para migração |
|---|-----------|--------|---------------------|
| 1 | **WebView** (renderiza JSPs `/presenca/IniciarPonto`, `/presenca/PontoDePresenca`) | Cria a interface web "dentro" do desktop. O `PontoDePresenca` carrega jQuery stub e chama `alert()` que é interceptado por `OnAlertListener` | 🔴 ALTO — a PoC atual substituiu JSPs por HTML erb + JS inline; precisará manter HTML compatível |
| 2 | **HTTP GET endpoints** (`/presenca/Dyn...`, `/presenca/CarregaRelogioAtual`, `/presenca/ValidarFrequentador`, `/presenca/AdicioneEstacao`) | Dados biométricos, heartbeat, sincronização de horário, validação login/senha | 🟡 MÉDIO — endpoints já implementados na PoC |
| 3 | **HTTP POST** (`/presenca/ajax/SincronizarRegistrosPonto`) | Envio de batidas offline (lote de registros DES-criptografados) | 🟢 BAIXO — implementado na PoC |
| 4 | **FxLauncher auto-update** | Baixa nova versão do JAR | 🔴 ALTO — mencionado no PRD como "pouco confiável"; **não migrar**, existem estratégias melhores |

## Pattern de Integração com JS (importante para Adapter)

A EstaçãoPonto usa um pattern curioso: o JavaScript da página carregada no WebView chama `alert('COMANDO')`, e o `OnAlertListener` do JavaFX intercepta esse alerta e mapeia para um enum `Operacao`. Cada `Operacao` implementa `execute(metodo, engine)`.

**Comandos atuais** (em `listeners/Operacao.java`):
- `RECUPERAR_FREQUENTADORES`
- `RECUPERAR_PREDIOS_PERMITIDOS`
- `RECUPERAR_CODIGO_ATIVACAO`
- `HORARIO_SERVIDOR_ATUAL`
- `ATUALIZAR_RELOGIO_LOCAL`
- `LIMPAR_REGISTROS_BATIMENTOS`
- `VIVO_MORTO`
- `LOGINMANUAL`

**Métodos JS injetados pela estação na página** (`utils/The.java` + `MainController`):
- `process('DIGITAL_RECONHECIDA', dados)` — exibe dados do frequentador
- `sincronizaPonto(dados, codAtivacao)` — faz POST para o endpoint de sincronização
- `atualizaRelogioLocal(horario)` — atualiza relógio na tela
- `aguardarDigital()`, `lock()`, `unlock()`, `changeInfoDigital()`, `adicionaUpload()`, `adicionaParte()`

> **DECISÃO:** esse acoplamento WebView↔JS↔Java é **o ponto crítico** da estratégia de compatibilidade. O Frequência terá que servir HTML + JS que usem exatamente esses mesmos contratos (`alert('LOGINMANUAL')`, `process(...)`, etc.), senão a EstaçãoPonto para de funcionar. A PoC atual já faz isso parcialmente (ver `api-ponto/app/views/presenca/ponto_de_presenca/index.html.erb` no git).

## Funcionalidades (mapa alto nível)

| ID | Funcionalidade | Classe principal |
|----|----------------|------------------|
| F01 | Iniciar Estação | `core/EstacaoPonto.java` |
| F02 | Carregar Interface Web (WebView) | `view/TelaPonto.java` + `ConexaoIntranetService` |
| F03 | Capturar Digital | `async/PreProcessandoService` + `LeitorDigital` |
| F04 | Registrar Batida Biométrica | `VerificacaoDigitalService` + `EventoLeitura` + `ArquivoRegistros` |
| F05 | Login Manual (CPF/Senha) | `ValidarBatidaManualService` |
| F06 | Bloquear/Desbloquear Tela | `BloqueioTela` + `KeyHook` |
| F07 | Sincronizar Registros Offline | `MainController.iniciarSincronizacao()` |
| F08 | Heartbeat (VivoOuMorto) | `VivoOuMortoService` |
| F09 | Download de Frequentadores | `DownloadFrequentadoresService` |
| F10 | Cache de Fotos | `CacheDownloadService` |
| F11 | Cadastro de Digitais | `LeitorDigital.enroll()` |
| F12 | Relógio Sincronizado | `ThreadRelogio` |
| F13 | Auto-Update (FxLauncher) | `pom.xml` |
| F14 | Restart Programado (22:00–22:10) | `ScriptsBat` |
| F15 | Upload de Logs | `MainController` |

## Estados da Leitura Biométrica

`EventoLeitura` enum — 11 estados (ver `core/leitura/EventoLeitura.java`):

```
NULO → DEDO_POSICINADO → LEITURA_EM_ANALISE → {
    DIGITAL_RECONHECIDA                (ID > 0 + prédio OK)
    DIGITAL_RECONHECIDA_RESSALVA_PREDIO (ID > 0 + prédio !=)
    DIGITAL_NAO_RECONHECIDA            (ID <= 0)
    ERRO_LEITURA                       (sensor)
    USUARIO_SENHA_INVALIDOS            (login manual)
    USUARIO_SEM_PERMISSAO_MANUAL
    SEM_CONEXAO_TIMEOUT
    ESTACAO_SEM_PERMISSAO_PARA_BATIDA_MANUAL
}
```

## Débitos Técnicos Críticos (ver doc canônica ETAPA 10)

| ID | Débito | Severidade |
|----|--------|------------|
| DT01 | Chave DES `"cryp:gpf"` hardcoded em 3+ classes | Crítica |
| DT02 | DES é obsoleto desde 2005 | Crítica |
| DT03 | `System.out.println` em produção | Alta |
| DT05 | Zero testes automatizados | Alta |
| DT09 | `System.exit()` em vários locais | Alta |

## Pontos Fortes (ver doc canônica ETAPA 19.3)

1. Operação offline robusta (registros criptografados em arquivo)
2. Integração via WebView reusando interface web da Intranet
3. Heartbeat + auto-recuperação
4. Bloqueio de tela (kiosk)
5. Estrutura de pastas organizada em camadas

## Referências

- **Canônica:** `/frequencia/documentacao-estacao-ponto.md` (1773 linhas, 19 etapas)
- **PRD da PoC:** `/frequencia/PRD-POC-API-PONTO.md`
- **Métricas:** 28 classes, ~2500 LOC, 8 services async, 6 endpoints HTTP consumidos, 18 regras de negócio
- **Doc PoC:** `docs/05-migracao/00-codigo-preexistente-poc.md` (descoberta da PoC já implementada)

---
**Última atualização:** 2026-08-04
