#!/usr/bin/env bash
# Instalador do g15-teclado — luz do teclado do Dell G15 no Linux
# Projeto: https://github.com/gillemosai/dell-g15-keyboard-backlight
#
# Uso:  bash install.sh          (pergunta antes de instalar)
#       bash install.sh -y       (instala sem perguntar)
#       bash install.sh --forcar (instala mesmo se não detectar um Dell G15)

set -euo pipefail

CONTROLLER_REPO="https://github.com/Vescrity/G15kblight-cli"
APP_DIR="$HOME/.local/share/g15-teclado"
BIN_DIR="$HOME/.local/bin"
UDEV_RULE="/etc/udev/rules.d/60-g15-teclado.rules"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SIM=0; FORCAR=0
for arg in "$@"; do
  case "$arg" in
    -y|--sim) SIM=1 ;;
    --forcar|--force) FORCAR=1 ;;
  esac
done

# ---------- Aparência ----------
if [ -t 1 ]; then
  AZ=$'\e[1;34m'; VD=$'\e[1;32m'; AM=$'\e[1;33m'; VM=$'\e[1;31m'; NG=$'\e[1m'; RS=$'\e[0m'
else
  AZ=""; VD=""; AM=""; VM=""; NG=""; RS=""
fi
passo() { echo "${AZ}==>${RS} ${NG}$*${RS}"; }
ok()    { echo "    ${VD}✔${RS} $*"; }
aviso() { echo "    ${AM}!${RS} $*"; }
falha() { echo "${VM}✘ $*${RS}" >&2; exit 1; }

echo
echo "${AZ}╔══════════════════════════════════════════════╗${RS}"
echo "${AZ}║${RS}  ${NG}g15-teclado${RS} · luz do teclado Dell G15 no Linux ${AZ}║${RS}"
echo "${AZ}╚══════════════════════════════════════════════╝${RS}"
echo

[ "$EUID" -eq 0 ] && falha "Não rode com sudo. Rode como seu usuário: bash install.sh (a senha será pedida quando precisar)."
[ -f "$SCRIPT_DIR/bin/g15-teclado" ] || falha "Arquivo bin/g15-teclado não encontrado. Rode o install.sh de dentro da pasta do projeto."

# ---------- 1. Notebook ----------
passo "Identificando o notebook"
FABRICANTE=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "?")
MODELO=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "?")
ok "$FABRICANTE $MODELO"
if [[ "$FABRICANTE" != *Dell* ]] || [[ "$MODELO" != *G15* ]]; then
  if [ "$FORCAR" -eq 1 ]; then
    aviso "Não parece um Dell G15, mas --forcar foi usado. Continuando."
  else
    falha "Este projeto é para o Dell G15. Se o seu modelo usa o mesmo controlador, rode: bash install.sh --forcar"
  fi
fi

# ---------- 2. Sistema ----------
passo "Identificando o sistema"
# shellcheck disable=SC1091
. /etc/os-release 2>/dev/null || true
ok "${PRETTY_NAME:-Linux} · kernel $(uname -r) · ${XDG_CURRENT_DESKTOP:-ambiente desconhecido}"

if command -v apt-get >/dev/null 2>&1; then
  GERENCIADOR="apt";    PACOTES=(python3-usb git zenity libnotify-bin)
elif command -v dnf >/dev/null 2>&1; then
  GERENCIADOR="dnf";    PACOTES=(python3-pyusb git zenity libnotify)
elif command -v pacman >/dev/null 2>&1; then
  GERENCIADOR="pacman"; PACOTES=(python-pyusb git zenity libnotify)
elif command -v zypper >/dev/null 2>&1; then
  GERENCIADOR="zypper"; PACOTES=(python3-pyusb git zenity libnotify-tools)
else
  GERENCIADOR=""
  aviso "Gerenciador de pacotes não reconhecido. Instale manualmente: python3 pyusb, git e zenity."
fi
[ -n "$GERENCIADOR" ] && ok "Gerenciador de pacotes: $GERENCIADOR"

# ---------- 3. Placa de vídeo (informativo) ----------
passo "Identificando a placa de vídeo"
if command -v lspci >/dev/null 2>&1; then
  while IFS= read -r linha; do ok "${linha#*: }"; done < <(lspci | grep -Ei 'vga|3d|display' || true)
else
  for d in /sys/bus/pci/devices/*; do
    case "$(cat "$d/class" 2>/dev/null)" in
      0x03*) ok "PCI $(cat "$d/vendor"):$(cat "$d/device")" ;;
    esac
  done
fi
aviso "A placa de vídeo não interfere na luz do teclado; ela aparece aqui só para o diagnóstico."

# ---------- 4. Controlador de luz ----------
passo "Procurando o controlador de luz do teclado"
usb_id() {
  local d
  for d in /sys/bus/usb/devices/*; do
    if [ "$(cat "$d/idVendor" 2>/dev/null)" = "187c" ]; then
      cat "$d/idProduct"
      return
    fi
  done
}
PRODUTO=$(usb_id || true)

if [ "$PRODUTO" = "0550" ]; then
  MODO="rgb"
  ok "Teclado RGB com controlador Alienware 187c:0550 (suportado)"
elif [ "$PRODUTO" = "0551" ]; then
  echo
  aviso "Encontrado o controlador 187c:0551 (G15 5530 e modelos mais novos)."
  aviso "Esse controlador usa outro protocolo e ainda não é suportado por este projeto."
  aviso "Alternativa: o projeto AWCC (no Arch: pacote 'awcc-git' do AUR)."
  aviso "Se quiser ajudar a adicionar suporte, abra uma issue com o resultado de: lsusb"
  exit 1
elif [ -d /sys/class/leds/dell::kbd_backlight ]; then
  MODO="branco"
  ok "Teclado de luz branca (dell::kbd_backlight)"
else
  falha "Nenhum controle de luz do teclado foi encontrado. Abra uma issue com a saída de: ls /sys/class/leds/ ; lsusb"
fi

# ---------- Confirmação ----------
echo
echo "O instalador vai:"
[ -n "$GERENCIADOR" ] && echo "  • instalar dependências: ${PACOTES[*]}"
[ "$MODO" = "rgb" ] && echo "  • baixar o controlador do teclado ($CONTROLLER_REPO)"
echo "  • criar uma regra de permissão (udev) para não pedir senha a cada uso"
echo "  • reaplicar a cor quando o notebook voltar da suspensão"
echo "  • criar o atalho 'Cor do Teclado' e aplicar a cor ao iniciar a sessão"
if [ "$SIM" -eq 0 ]; then
  read -r -p "Continuar? [S/n] " resp
  [[ "${resp:-S}" =~ ^[SsYy]$ ]] || { echo "Cancelado."; exit 0; }
fi

# ---------- 5. Dependências ----------
passo "Instalando dependências (a senha pode ser pedida)"
case "$GERENCIADOR" in
  apt)    sudo apt-get update -qq && sudo apt-get install -y "${PACOTES[@]}" ;;
  dnf)    sudo dnf install -y "${PACOTES[@]}" ;;
  pacman) sudo pacman -S --needed --noconfirm "${PACOTES[@]}" ;;
  zypper) sudo zypper --non-interactive install "${PACOTES[@]}" ;;
esac
ok "Dependências prontas"

# ---------- 6. Controlador ----------
mkdir -p "$APP_DIR" "$BIN_DIR" "$HOME/.config/g15-teclado"
echo "$MODO" > "$HOME/.config/g15-teclado/modo"

if [ "$MODO" = "rgb" ]; then
  passo "Baixando o controlador do teclado"
  if [ -d "$APP_DIR/controller/.git" ]; then
    git -C "$APP_DIR/controller" pull -q || aviso "Não foi possível atualizar; usando a versão já baixada."
  else
    rm -rf "$APP_DIR/controller"
    git clone -q "$CONTROLLER_REPO" "$APP_DIR/controller" || falha "Falha ao baixar o controlador. Verifique sua internet."
  fi
  [ -f "$APP_DIR/controller/src/main.py" ] || falha "O controlador baixado não tem src/main.py. Abra uma issue."
  ok "Controlador em $APP_DIR/controller"
fi

install -m 755 "$SCRIPT_DIR/bin/g15-teclado" "$BIN_DIR/g15-teclado"
ok "Comando instalado: $BIN_DIR/g15-teclado"

# ---------- 7. Permissões (udev) ----------
passo "Configurando permissões"
if [ "$MODO" = "rgb" ]; then
  REGRA='SUBSYSTEM=="usb", ATTRS{idVendor}=="187c", ATTRS{idProduct}=="0550", MODE="0660", TAG+="uaccess"'
else
  REGRA='ACTION=="add", SUBSYSTEM=="leds", KERNEL=="dell::kbd_backlight", RUN+="/bin/chmod 0666 /sys/class/leds/%k/brightness"'
fi
echo "$REGRA" | sudo tee "$UDEV_RULE" >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger
ok "Regra criada em $UDEV_RULE"

# ---------- 8. Volta da suspensão ----------
passo "Reaplicando a cor após suspender"
SLEEP_DIR="/usr/lib/systemd/system-sleep"
[ -d "$SLEEP_DIR" ] || SLEEP_DIR="/lib/systemd/system-sleep"
if [ -d "$SLEEP_DIR" ]; then
  sudo tee "$SLEEP_DIR/g15-teclado" >/dev/null <<EOF
#!/bin/sh
# Criado por g15-teclado: reaplica a cor do teclado ao acordar
if [ "\$1" = "post" ]; then
  ( sleep 3; HOME="$HOME" "$BIN_DIR/g15-teclado" --auto ) >/dev/null 2>&1 &
fi
EOF
  sudo chmod 755 "$SLEEP_DIR/g15-teclado"
  ok "Ativado"
else
  aviso "Sistema sem systemd-sleep; após suspender, use o atalho 'Cor do Teclado'."
fi

# ---------- 9. Atalhos ----------
passo "Criando atalhos"
LANCADOR="[Desktop Entry]
Type=Application
Name=Cor do Teclado
Name[en]=Keyboard Color
Comment=Escolhe a cor da luz do teclado do Dell G15
Comment[en]=Pick the Dell G15 keyboard backlight color
Exec=$BIN_DIR/g15-teclado
Icon=input-keyboard
Terminal=false
Categories=Utility;Settings;HardwareSettings;
Keywords=teclado;keyboard;rgb;luz;backlight;g15;"

mkdir -p "$HOME/.local/share/applications" "$HOME/.config/autostart"
echo "$LANCADOR" > "$HOME/.local/share/applications/g15-teclado.desktop"
printf '%s\n' "$LANCADOR" | sed "s|^Exec=.*|Exec=$BIN_DIR/g15-teclado --auto|" \
  > "$HOME/.config/autostart/g15-teclado.desktop"
ok "Menu de aplicativos: 'Cor do Teclado'"
ok "Cor aplicada automaticamente ao iniciar a sessão"

AREA="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
if [ -n "$AREA" ] && [ -d "$AREA" ] && [ "$AREA" != "$HOME" ]; then
  echo "$LANCADOR" > "$AREA/g15-teclado.desktop"
  chmod +x "$AREA/g15-teclado.desktop"
  gio set "$AREA/g15-teclado.desktop" metadata::trusted true 2>/dev/null || true
  ok "Atalho na Área de Trabalho"
fi

# ---------- 10. Teste ----------
passo "Acendendo o teclado"
if "$BIN_DIR/g15-teclado" --auto; then
  ok "Teclado aceso!"
else
  aviso "Não acendeu agora. Reinicie o computador e abra 'Cor do Teclado'."
  aviso "Se continuar, rode 'g15-teclado --diagnostico' e abra uma issue no GitHub."
fi

echo
echo "${VD}Instalação concluída.${RS}"
echo "  • Abra ${NG}Cor do Teclado${RS} no menu para escolher a cor"
echo "  • No terminal: ${NG}g15-teclado --cor 0x00AAFF${RS}"
echo "  • Para remover: ${NG}bash uninstall.sh${RS}"
echo
echo "Feito por Gil Lemos · ${AZ}https://gillemosai.com${RS}"
echo
