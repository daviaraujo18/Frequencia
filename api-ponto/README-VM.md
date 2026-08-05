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
