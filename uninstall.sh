#!/bin/bash
# Removes the Home Assistant kiosk and puts the Pi back to a normal login.
# Installed packages (X, Chromium) are left in place.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo:  sudo ./uninstall.sh" >&2
  exit 1
fi
KIOSK_USER="${KIOSK_USER:-${SUDO_USER:-}}"
KIOSK_HOME="$(getent passwd "$KIOSK_USER" | cut -d: -f6)"

sed -i '/^# >>> ha-kiosk >>>$/,/^# <<< ha-kiosk <<<$/d' "$KIOSK_HOME/.bash_profile" 2>/dev/null || true
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rmdir /etc/systemd/system/getty@tty1.service.d 2>/dev/null || true
rm -rf /opt/ha-kiosk "$KIOSK_HOME/.local/share/ha-kiosk"
rm -f /etc/ha-kiosk.conf
systemctl daemon-reload

echo "Kiosk removed. The Chromium profile (saved login) is still in"
echo "$KIOSK_HOME/.config/ha-kiosk-chromium — delete it too if you like."
echo "Reboot to finish:  sudo reboot"
