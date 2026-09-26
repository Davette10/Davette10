#!/bin/bash
# Launches Chromium in kiosk mode on the Home Assistant dashboard and restarts
# it if it ever exits or crashes.
set -u

# shellcheck source=/dev/null
. /etc/ha-kiosk.conf

HA_URL="${HA_URL:-http://homeassistant.local:8123}"
IDLE_SECONDS="${IDLE_SECONDS:-120}"
CLOCK_24H="${CLOCK_24H:-no}"
CLOCK_SECONDS="${CLOCK_SECONDS:-no}"
ZOOM="${ZOOM:-1}"

# The Chromium profile lives here and persists across reboots — this is what
# keeps you logged in to Home Assistant.
PROFILE_DIR="$HOME/.config/ha-kiosk-chromium"
EXT_DIR="$HOME/.local/share/ha-kiosk/clock-extension"

BROWSER="$(command -v chromium-browser || command -v chromium)"
if [ -z "$BROWSER" ]; then
  echo "ha-kiosk: Chromium is not installed" >&2
  exit 1
fi

yes_no() { case "${1,,}" in y|yes|true|1|on) echo true ;; *) echo false ;; esac; }

IDLE_SECONDS="${IDLE_SECONDS//[^0-9]/}"
IDLE_SECONDS="${IDLE_SECONDS:-120}"

# Copy the clock extension and write its settings from /etc/ha-kiosk.conf.
mkdir -p "$EXT_DIR"
cp -r /opt/ha-kiosk/clock-extension/. "$EXT_DIR/"
cat > "$EXT_DIR/config.js" <<EOF
// Generated from /etc/ha-kiosk.conf at kiosk start — edit that file instead.
self.HA_KIOSK_CLOCK = {
  idleSeconds: ${IDLE_SECONDS},
  use24h: $(yes_no "$CLOCK_24H"),
  showSeconds: $(yes_no "$CLOCK_SECONDS"),
};
EOF

# Give the network and Home Assistant up to ~2 minutes to come up so the first
# page load doesn't land on an error screen.
for _ in $(seq 1 60); do
  curl -s -o /dev/null --max-time 3 "$HA_URL" && break
  sleep 2
done

while true; do
  # Mark the last session as a clean exit so Chromium never shows the
  # "Restore pages?" bubble after a power cut.
  prefs="$PROFILE_DIR/Default/Preferences"
  if [ -f "$prefs" ]; then
    sed -i -e 's/"exited_cleanly":false/"exited_cleanly":true/' \
           -e 's/"exit_type":"[^"]*"/"exit_type":"Normal"/' "$prefs"
  fi

  "$BROWSER" \
    --kiosk \
    --user-data-dir="$PROFILE_DIR" \
    --load-extension="$EXT_DIR" \
    --disable-features=Translate,TranslateUI,DisableLoadExtensionCommandLineSwitch \
    --ozone-platform=x11 \
    --force-device-scale-factor="$ZOOM" \
    --touch-events=enabled \
    --overscroll-history-navigation=0 \
    --disable-pinch \
    --no-first-run \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-restore-session-state \
    --password-store=basic \
    --check-for-update-interval=31536000 \
    --autoplay-policy=no-user-gesture-required \
    "$HA_URL"

  sleep 3
done
