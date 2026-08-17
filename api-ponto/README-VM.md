# VM Windows — teste com leitor biométrico real

Ambiente usado para testar a Estação (JavaFX) contra o leitor biométrico
NitGen real (HFDU04/Hamster), fora do alcance dos stubs Linux do Docker de
dev. Roda uma VM Windows 10 via QEMU/KVM com o leitor conectado via USB
passthrough.

> **Pré-requisito:** as imagens da VM (`win.qcow2`, `OVMF_VARS.fd`,
> `drivers.img`, `app-build.img`) precisam já existir em `~/vm-estacao-win/`.
> Elas não fazem parte deste repositório (são artefatos locais, específicos
> da máquina/leitor de cada desenvolvedor) — se você está montando esse
> ambiente do zero, peça o passo a passo de criação da VM.

## 1. Liberar a permissão do leitor USB

Antes de cada boot, o dispositivo NitGen precisa de permissão de
leitura/escrita no host (senão o QEMU não consegue ler os descritores reais
do dispositivo, e ele aparece como "USB Host Device" genérico dentro da VM).

```bash
lsusb -d 0a86:0100
# anota o Bus/Device do resultado, ex: "Bus 005 Device 003"

sudo chmod 666 /dev/bus/usb/<bus>/<device>
```

## 2. Subir a VM

```bash
./script.sh
```

Isso abre uma janela QEMU com o Windows. Aguarde o boot terminar.

## 3. Rodar a Estação dentro da VM

No Windows, abra o **Prompt de Comando** e rode:

```cmd
cd /d F:\EstacaoPonto
java -cp "*" core.EstacaoPonto
```

(`F:` é o pendrive virtual com o build da Estação — confira a letra real em
"Este Computador" caso tenha mudado.)

## Notas e problemas conhecidos

- **Desligar a VM**: sempre pelo próprio Windows (Iniciar → Desligar), não
  matando o processo QEMU — evita corromper o disco.
- **Trocar o `.jar` da Estação**: com a VM desligada, monte `app-build.img`
  (`udisksctl loop-setup -f ~/vm-estacao-win/app-build.img`), copie o novo
  `.jar` pra dentro, desmonte, e suba a VM de novo. Os pendrives virtuais
  (`stick`/`appbuild`) usam número de série novo a cada boot (ver
  `script.sh`) justamente para evitar que o Windows sirva conteúdo em cache
  de um boot anterior.
- **Java**: precisa ser especificamente **Java 8 com JavaFX** (ex: Zulu 8
  "Bundled with JavaFX") — versões mais novas não têm o JavaFX 8 legado que
  o app usa.
- **Som desativado**: o `SoundService` da Estação está com a reprodução de
  áudio desligada de propósito — o player de mídia nativo do JavaFX crasha
  (`EXCEPTION_ACCESS_VIOLATION`) em builds OpenJFX sem codecs completos.
- **Captura biométrica automática**: pode apresentar timeout intermitente
  (`CaptureTimeOutException`) — possível limitação de latência do
  passthrough USB, ainda em investigação. O cadastro de digital (`Enroll()`,
  mais tolerante a atraso) funciona normalmente.

## Desafios enfrentados

Registro histórico de tudo que travou durante a montagem desse ambiente e a
integração com o leitor real — pra quem for reproduzir não repetir as mesmas
horas de debug.

### Infraestrutura da VM

- **RAM do host limitada** (5,2GB no total) — não dava pra alocar a RAM
  "padrão" de VM Windows (4GB) sem travar o host. Resolvido alocando 2560MB
  e fechando apps pesados antes de subir a VM.
- **Mouse capturado pela janela GTK do QEMU** — no modo padrão, o mouse fica
  "preso" na janela até apertar Ctrl+Alt. Resolvido com `-device usb-tablet`
  (posicionamento absoluto, sem precisar capturar/soltar).
- **`sudo` interativo** — o ambiente onde essas mudanças foram feitas não
  consegue fornecer senha de `sudo` sozinho; toda operação que precisava de
  privilégio (chmod de dispositivo USB, mkfs, apt install) teve que ser
  repassada como comando pro usuário rodar manualmente, um por um.

### Leitor biométrico (USB passthrough)

- **Sem driver Linux** — o SDK NitGen só existe pra Windows; é por isso que
  a VM Windows foi necessária em primeiro lugar (os stubs do Docker de dev
  cobrem só a lógica não-biométrica).
- **Permissão do dispositivo USB muda a cada reconexão** — o caminho
  `/dev/bus/usb/<bus>/<device>` muda toda vez que o leitor é
  desconectado/reconectado (inclusive internamente, durante a instalação do
  driver, que pede pra desconectar e reconectar o dispositivo no meio do
  processo). Cada mudança de caminho exigia um novo `sudo chmod 666` antes
  do QEMU conseguir ler os descritores reais do dispositivo — sem isso, ele
  aparecia na VM como um "USB Host Device" genérico (sem nome/velocidade
  reais), e o Windows não reconhecia o hardware.
- **Conflito de barramento USB com o mouse** — leitor e mouse (tablet) no
  mesmo controlador `xhci` fizeram o mouse parar de responder assim que o
  driver do leitor foi instalado (o Windows reseta o barramento inteiro
  durante a instalação). Resolvido separando o mouse pro barramento USB
  legado (`-usb`) e deixando só o leitor no `xhci`.
- **Instalação do driver exige ciclo de desconectar/reconectar** — o
  instalador (`EasyInstallation_v3.12.rar`) pede pra desconectar o
  dispositivo antes de começar e reconectar no meio da instalação; cada
  ciclo desses precisou ser coordenado manualmente entre o usuário
  (desconectar/reconectar fisicamente) e o QEMU (`device_del`/`device_add`
  + `chmod` no novo caminho).
- **Barramento legado (USB 1.1) deixa o leitor morto** — tentativa de mover
  o leitor pro barramento legado (mesma solução que resolveu o mouse) pra
  ver se reduzia a latência de captura piorou tudo: o LED parou de piscar
  completamente, sinal de que o sensor precisa de USB 2.0 High-Speed pra
  sequer inicializar. Revertido pro `xhci`.
- **Timeout intermitente na captura automática** — ainda em aberto (ver
  seção "Notas e problemas conhecidos" acima). O `Enroll()` (cadastro,
  mais tolerante a atraso) funciona bem; o `Capture()` do loop automático
  de reconhecimento estoura timeout com frequência, possível limitação de
  latência do passthrough.

### Transferência de arquivos pra dentro da VM

- **Sem `genisoimage`/`mkisofs`/`unrar` no host** — nada disso vinha
  instalado; precisou justificar e instalar (`apt install genisoimage`,
  depois `unrar`, ambos pacotes pequenos e padrão).
- **Rede do host bloqueia `archive.ubuntu.com`** — o `sudo apt install
  unrar` ficou tentando pra sempre. Diagnóstico: a rede (provavelmente
  política corporativa) bloqueia o mirror do Ubuntu — IPv6 "rede fora de
  alcance", IPv4 dropado silenciosamente — enquanto navegação normal (ex:
  `7-zip.org`) funcionava. Contornado baixando o 7-Zip **de dentro da VM**
  em vez do host.
- **Pendrive virtual (`app-build.img`) sem tabela de partição não monta no
  Windows** — formatar a imagem inteira como "superfloppy" (`mkfs.vfat`
  direto no disco, sem partição) funcionou como HD IDE cru, mas o Windows
  não reconheceu como disco válido. Precisou criar tabela MBR (`parted
  mklabel msdos` + `mkpart`) antes de formatar a partição.
- **Mesmo com partição, montado como HD IDE não aparecia** — trocado pra
  anexar como pendrive USB (`usb-storage`) em vez de disco IDE cru.
- **Windows serve conteúdo em cache do pendrive, ignorando reescritas** —
  o bug mais persistente da sessão: mesmo recriando o `app-build.img` do
  zero (nova tabela de partição, novo UUID de volume, hash verificado
  batendo no host), o Windows continuava mostrando o `.jar` antigo (tamanho
  e serial de volume de builds anteriores). Tentativas até resolver: serial
  USB único por boot, reboot completo da VM, ejeção manual pelo Windows,
  troca pra CD-ROM/ISO (`genisoimage`) — nada isolado resolveu. A causa raiz
  real só apareceu ao investigar `losetup -a`: havia **loop devices
  "fantasmas"** no host (mapeamentos antigos nunca desanexados
  corretamente, ex: `/dev/loop16` preso com o arquivo ainda montado em
  paralelo a montagens novas), fazendo duas montagens simultâneas do mesmo
  arquivo brigarem pelo cache uma da outra. Resolvido limpando todos os
  loop devices órfãos antes de cada montagem nova e conferindo com
  `losetup -a`/`mount` que não sobrava nada preso.
- **Ejetar manualmente pelo Windows deixou os pendrives em limbo** — depois
  de "Ejetar" via Windows, os drives sumiram e não voltaram nem com reboot
  completo da VM, nem com `device_del`/`device_add` ao vivo — só voltaram
  depois de uma recriação completa das imagens com IDs/seriais
  explicitamente novos no `script.sh`.

### Build da Estação com o SDK real

- **JARs Java do SDK (`NBioBSPJNI.jar`, `jna.jar`, etc.) não estavam no
  repositório** — só as DLLs nativas. Recuperados do **histórico do Git**
  (existiam em commits antigos, em `lib/`, antes de serem removidos do
  working tree).
- **Ownership dos arquivos de build** — o container Docker roda como root;
  todo `mvn package` deixava `target/` com dono `root`, exigindo `sudo
  chown` manual antes de mexer nos arquivos gerados.

### Integração Estação ↔ Frequencia

- **`bundle exec` quebrado nesta versão do Ruby** — `bundle exec rails
  server` (e qualquer `bundle exec`) falhava com `invalid switch in
  RUBYOPT: -e`, um bug de compatibilidade entre Bundler 2.7.2 e Ruby 3.4.2
  neste ambiente (nada a ver com o código do projeto). Contornado chamando
  `ruby bin/rails ...` diretamente, sem passar pelo `bundle exec`.
- **`codAtivacao=null`** — em Windows real (diferente do stub Linux), a
  Estação lê o código de ativação do Registro do Windows
  (`HKCU\SOFTWARE\TJPIEstacaoPonto\codigoAtivacao`), que nunca existia numa
  VM nova — toda autenticação falhava silenciosamente. Resolvido criando a
  chave manualmente (`reg add`) com o valor da whitelist da Frequencia
  (`poc-ativacao-001`).
- **`base_intranet_url` não pode ser `localhost`** — de dentro da VM,
  `localhost`/`127.0.0.1` aponta pra própria VM, não pro host. Precisou
  usar o gateway especial do QEMU em modo `user` (`10.0.2.2`), que
  redireciona pro host onde a Frequencia estava rodando.
- **`config.properties` só é lido uma vez** — editar o arquivo com o app já
  aberto não tem efeito; sempre precisa fechar e abrir de novo pra pegar
  mudanças de configuração.

### Bugs de código descobertos e corrigidos nesta sessão

- **Botão "Cadastrar Digitais" inatingível pela interface** — só ficava
  visível quando o WebView carregava uma URL específica
  (`Frequentador?type=create`), mas nada no app linkava pra lá — nem o
  clique na imagem do topo (que ia pra `type=explore`, outro parâmetro).
  Além disso, a rota/controller da Frequencia pra essa tela era um stub sem
  formulário nem persistência nenhuma. Corrigido dos dois lados: link novo
  na tela `PontoDePresenca`, e controller/view reais na Frequencia que
  salvam o hash capturado no usuário certo.
- **`jQuery` usado onde não existe** — `MainController.cadastrarDigital()`
  injetava JS com sintaxe jQuery (`jQuery('#digitaisHash').val(...)`), mas
  as páginas kiosk atuais deliberadamente não carregam jQuery (o WebView
  antigo não executa `<script type="module">`, então nada carregado via
  import map funciona). Corrigido pra JS puro
  (`document.getElementById(...)`).
- **Crash nativo ao tocar som** (`EXCEPTION_ACCESS_VIOLATION` dentro de
  `com.sun.media.jfxmediaimpl`) — o player de mídia nativo do JavaFX
  (`AudioClip`) crasha de verdade (não é uma exceção Java capturável por
  try/catch — é um crash a nível de processo) em builds OpenJFX sem os
  codecs nativos completos (caso do Zulu 8 FX usado aqui). Corrigido
  desativando a reprodução de som por completo.
- **Corrida de threads entre `Enroll()` manual e o loop automático** — o
  `PreProcessandoService` (loop de captura em background) continuava
  rodando mesmo com o operador na tela de cadastro de digital, disputando
  o mesmo handle nativo do SDK com o `Enroll()` manual ao mesmo tempo —
  corrompia memória e derrubava a JVM (`EXCEPTION_ACCESS_VIOLATION` dentro
  do `ntdll.dll`, assinatura clássica de corrupção de heap). Corrigido
  pausando o loop (`cds.parar(true)`) ao entrar na tela de cadastro, do
  mesmo jeito que o fluxo antigo (clique na imagem do topo) já fazia — só
  que esse caminho novo não tinha essa proteção.
- **Bug de log (cosmético, não corrigido)** — `DadosFrequentadores.java`
  usa `total = i` (índice do loop) em vez de contar de fato os
  frequentadores processados; com 1 frequentador só, loga "Total: 0" mesmo
  tendo processado certo. Não afeta o funcionamento, só a mensagem de log.

### Outras pegadinhas menores

- **Java 25 instalado por engano** em vez de Java 8 — `NoClassDefFoundError:
  javafx/application/Application` até trocar pro Zulu 8.
- **`cd F:\pasta` sem `/d`** não troca de unidade no Prompt de Comando
  (fica quieto, parece que não fez nada) — precisa de `cd /d F:\pasta` ou
  `F:` seguido de `cd pasta`.
- **Aviso `Could not open/create prefs root node ...JavaSoft\Prefs`** —
  cosmético, aparece em toda execução do Java sem privilégio de admin no
  Windows, sem relação com nenhum dos bugs acima.
