#!/usr/bin/env bash
# Remove o g15-teclado e tudo o que o install.sh criou.
set -u

[ "$EUID" -eq 0 ] && { echo "Não rode com sudo. Rode: bash uninstall.sh"; exit 1; }

echo "==> Removendo g15-teclado"
rm -f  "$HOME/.local/bin/g15-teclado"
rm -rf "$HOME/.local/share/g15-teclado"
rm -rf "$HOME/.config/g15-teclado"
rm -f  "$HOME/.local/share/applications/g15-teclado.desktop"
rm -f  "$HOME/.config/autostart/g15-teclado.desktop"
AREA="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "$AREA" ] && rm -f "$AREA/g15-teclado.desktop"

echo "==> Removendo arquivos do sistema (a senha pode ser pedida)"
sudo rm -f /etc/udev/rules.d/60-g15-teclado.rules \
           /usr/lib/systemd/system-sleep/g15-teclado \
           /lib/systemd/system-sleep/g15-teclado
sudo udevadm control --reload-rules 2>/dev/null

echo "Pronto. As dependências (pyusb, git, zenity) foram mantidas."
