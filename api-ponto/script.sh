#!/bin/bash
#
# Sobe a VM Windows (QEMU/KVM) usada para testar a Estação com o leitor
# biométrico NitGen real. Ver README-VM.md para o passo a passo completo
# (inclusive a liberação de permissão do dispositivo USB, necessária antes
# de rodar este script).
#
set -e

VM_DIR="$HOME/vm-estacao-win"
rm -f "$VM_DIR/monitor.sock"

# Serial USB único a cada boot + id explícito nos pendrives virtuais.
# Sem isso o Windows trata os pendrives como a MESMA mídia entre
# reinicializações da VM (mesmo VID/PID/serial gerados pelo QEMU) e serve
# conteúdo de diretório em cache, ignorando qualquer arquivo novo gravado
# na imagem.
TS="$(date +%s)"

qemu-system-x86_64 \
  -enable-kvm -m 2560 -smp 2 -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file="$VM_DIR/OVMF_VARS.fd" \
  -drive file="$VM_DIR/win.qcow2",format=qcow2,if=ide \
  -boot order=c \
  -vga qxl -display gtk \
  -usb -device usb-tablet \
  -drive file="$VM_DIR/drivers.img",format=raw,if=none,id=stick \
  -device usb-storage,id=stickdev,drive=stick,serial="stick-$TS" \
  -drive file="$VM_DIR/app-build.img",format=raw,if=none,id=appbuild \
  -device usb-storage,id=appbuilddev,drive=appbuild,serial="appbuild-$TS" \
  -device qemu-xhci,id=xhci \
  -device usb-host,bus=xhci.0,vendorid=0x0a86,productid=0x0100,id=nitgen \
  -netdev user,id=net0 -device e1000,netdev=net0 \
  -monitor unix:"$VM_DIR/monitor.sock",server,nowait \
  -name "Estacao-Win10"
