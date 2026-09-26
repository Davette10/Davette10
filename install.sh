#!/bin/bash
# Turns a Raspberry Pi (tested target: Pi 3 + Raspberry Pi OS Lite) into a
# Home Assistant wall panel:
#   - auto-login on the console, then start a bare X session
#   - Chromium in full-screen kiosk mode on your Home Assistant URL
#   - an idle clock that fades in after a period of no touches
#
# Usage (on the Pi, as your normal user):
#   sudo ./install.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR=/opt/ha-kiosk
CONF=/etc/ha-kiosk.conf
MARK_BEGIN='# >>> ha-kiosk >>>'
MARK_END='# <<< ha-kiosk <<<'

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo:  sudo ./install.sh" >&2
  exit 1
fi

KIOSK_USER="${KIOSK_USER:-${SUDO_USER:-}}"
if [ -z "$KIOSK_USER" ] || [ "$KIOSK_USER" = root ]; then
  echo "Run this from your normal user account with sudo (or set KIOSK_USER=<name>)." >&2
  exit 1
fi
KIOSK_HOME="$(getent passwd "$KIOSK_USER" | cut -d: -f6)"

# --- Settings ---------------------------------------------------------------

# Existing settings become the defaults when re-running the installer.
HA_URL=http://homeassistant.local:8123
IDLE_SECONDS=120
CLOCK_24H=no
CLOCK_SECONDS=no
ZOOM=1
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"

ask() {
  local var=$1 prompt=$2 answer
  if [ -t 0 ]; then
    read -r -p "$prompt [${!var}]: " answer
    [ -n "$answer" ] && printf -v "$var" '%s' "$answer"
  fi
  return 0
}

echo "== Home Assistant kiosk setup =="
ask HA_URL        "Home Assistant URL"
ask IDLE_SECONDS  "Show the clock after how many seconds without a touch"
ask CLOCK_24H     "24-hour clock? (yes/no)"
ask CLOCK_SECONDS "Show seconds on the clock? (yes/no)"
ask ZOOM          "Page zoom (1 = normal, 0.8 = fit more on a small screen)"

# --- Packages ---------------------------------------------------------------

echo "== Installing packages (this takes a while on a Pi 3) =="
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  xserver-xorg xserver-xorg-input-libinput x11-xserver-utils xinit \
  curl avahi-daemon libnss-mdns
apt-get install -y --no-install-recommends matchbox-window-manager \
  || apt-get install -y --no-install-recommends openbox
apt-get install -y chromium-browser || apt-get install -y chromium
apt-get install -y fonts-inter || echo "(fonts-inter not available — the clock will use the system font)"

# --- Files ------------------------------------------------------------------

echo "== Installing kiosk files to $INSTALL_DIR =="
install -d "$INSTALL_DIR" "$INSTALL_DIR/clock-extension"
install -m 755 "$SRC_DIR/kiosk/xinitrc" "$SRC_DIR/kiosk/run-chromium.sh" "$INSTALL_DIR/"
install -m 644 "$SRC_DIR"/clock-extension/* "$INSTALL_DIR/clock-extension/"

cat > "$CONF" <<EOF
# Home Assistant kiosk settings. After editing, apply with:
#   sudo systemctl restart getty@tty1
HA_URL="$HA_URL"
IDLE_SECONDS="$IDLE_SECONDS"
CLOCK_24H="$CLOCK_24H"
CLOCK_SECONDS="$CLOCK_SECONDS"
ZOOM="$ZOOM"
EOF
chmod 644 "$CONF"

# --- Auto-login and auto-start ----------------------------------------------

echo "== Enabling console auto-login for $KIOSK_USER =="
usermod -aG video,input,tty "$KIOSK_USER"
getent group render >/dev/null && usermod -aG render "$KIOSK_USER"

install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

# Boot to the console (the kiosk starts its own X session). On Raspberry Pi OS
# Desktop this stops the normal desktop from starting.
systemctl set-default multi-user.target
systemctl daemon-reload

PROFILE="$KIOSK_HOME/.bash_profile"
touch "$PROFILE"
sed -i "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$PROFILE"
cat >> "$PROFILE" <<EOF
$MARK_BEGIN
# Start the Home Assistant kiosk on the physical screen (not over SSH).
if [ -z "\${DISPLAY:-}" ] && [ "\$(tty)" = /dev/tty1 ]; then
  exec startx $INSTALL_DIR/xinitrc -- -nocursor >"\$HOME/.ha-kiosk.log" 2>&1
fi
$MARK_END
EOF
chown "$KIOSK_USER:" "$PROFILE"

cat <<EOF

== Done! ==
Settings are in $CONF.

Next:
  1. Set up auto-login in Home Assistant (see README.md, "Auto-login").
  2. Reboot:  sudo reboot
EOF
