#!/usr/bin/env bash
set -euo pipefail

APP_ID="org.vrgb.lilslimer"
APP_NAME="Lil Slimer"
SERVICE_NAME="lilslimer-brain.service"

PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/$APP_ID"
BACKEND_ROOT="$HOME/.local/share/lilslimer"
SERVICE_DEST="$HOME/.config/systemd/user/$SERVICE_NAME"

info() {
    echo "[lilslimer] $*"
}

restart_plasma() {
    # Prefer Plasma's systemd user unit; avoid killing the desktop shell.
    if systemctl --user cat plasma-plasmashell.service >/dev/null 2>&1; then
        systemctl --user restart plasma-plasmashell.service || {
            info "WARNING: Plasma restart failed. Log out and back in to refresh the widget."
        }
    else
        info "Plasma shell is not systemd-managed; log out and back in to refresh the widget."
    fi
}

if [[ "$EUID" -eq 0 ]]; then
    echo "[lilslimer] ERROR: Run as your normal desktop user, not with sudo." >&2
    exit 1
fi

info "Uninstalling $APP_NAME..."

info "Stopping brain service..."
systemctl --user stop "$SERVICE_NAME" >/dev/null 2>&1 || true
systemctl --user disable "$SERVICE_NAME" >/dev/null 2>&1 || true

info "Removing systemd user service..."
rm -f "$SERVICE_DEST"
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

info "Removing Plasma applet package..."
if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet -r "$APP_ID" >/dev/null 2>&1 || true
fi

rm -rf "$PLASMOID_DEST"

info "Removing backend files..."
rm -rf "$BACKEND_ROOT"

info "Restarting plasmashell..."
restart_plasma

cat <<EOF2

[lilslimer] Uninstall complete.

Removed:
  $PLASMOID_DEST
  $BACKEND_ROOT
  $SERVICE_DEST

If an "Unknown" widget remains on your panel, KDE kept an orphaned applet reference.
Remove it from panel edit mode. If it refuses to leave, restart Plasma and remove it again.

EOF2
