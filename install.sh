#!/usr/bin/env bash
set -euo pipefail

APP_ID="org.vrgb.lilslimer"
APP_NAME="Lil Slimer"
SERVICE_NAME="lilslimer-brain.service"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_SRC="$SCRIPT_DIR/$APP_ID"
BACKEND_SRC="$SCRIPT_DIR/backend"

PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/$APP_ID"
BACKEND_DEST="$HOME/.local/share/lilslimer/backend"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_DEST="$SERVICE_DIR/$SERVICE_NAME"
STATE_DEST="$PLASMOID_DEST/contents/ui/state.json"

fail() {
    echo "[lilslimer] ERROR: $*" >&2
    exit 1
}

info() {
    echo "[lilslimer] $*"
}

require_command() {
    local cmd="$1"
    local hint="${2:-}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[lilslimer] Missing required command: $cmd" >&2
        if [[ -n "$hint" ]]; then
            echo "$hint" >&2
        fi
        exit 1
    fi
}

print_kdotool_hint() {
    cat >&2 <<'HINT'

Install kdotool with one of these, then rerun ./install.sh:
  Fedora / Nobara:             sudo dnf install kdotool
  Arch / Endeavour / CachyOS:  sudo pacman -S kdotool
  openSUSE:                    sudo zypper install kdotool
  Kubuntu / KDE neon:          sudo apt install kdotool

Lil Slimer can fall back to xdotool in some sessions, but kdotool is recommended for KDE Plasma.
HINT
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

verify_source_tree() {
    [[ -d "$PLASMOID_SRC" ]] || fail "Missing plasmoid directory: $PLASMOID_SRC"
    [[ -f "$PLASMOID_SRC/metadata.json" ]] || fail "Missing metadata.json in $PLASMOID_SRC"
    [[ -f "$PLASMOID_SRC/contents/ui/main.qml" ]] || fail "Missing main.qml in $PLASMOID_SRC/contents/ui"
    [[ -f "$PLASMOID_SRC/contents/icons/lilslimer.png" ]] || fail "Missing widget icon"
    [[ -f "$PLASMOID_SRC/contents/ui/state.json" ]] || fail "Missing default state.json"
    [[ -f "$SCRIPT_DIR/systemd/$SERVICE_NAME" ]] || fail "Missing systemd service template"
    [[ -d "$BACKEND_SRC" ]] || fail "Missing backend directory: $BACKEND_SRC"
    [[ -f "$BACKEND_SRC/brain.py" ]] || fail "Missing backend/brain.py"
    [[ -f "$BACKEND_SRC/signals.py" ]] || fail "Missing backend/signals.py"
    [[ -f "$BACKEND_SRC/state_machine.py" ]] || fail "Missing backend/state_machine.py"
}

install_plasmoid() {
    info "Installing plasmoid package..."

    # Upgrade in place; never remove a working package before attempting an update.
    if [[ -f "$PLASMOID_DEST/metadata.json" ]]; then
        kpackagetool6 -t Plasma/Applet -u "$PLASMOID_SRC" || fail "Plasmoid upgrade failed; existing installation was not intentionally removed."
    else
        kpackagetool6 -t Plasma/Applet -i "$PLASMOID_SRC" || fail "Plasmoid installation failed."
    fi

    [[ -f "$PLASMOID_DEST/metadata.json" ]] || fail "Installed plasmoid missing metadata.json"
    [[ -f "$PLASMOID_DEST/contents/ui/main.qml" ]] || fail "Installed plasmoid missing main.qml"
    [[ -f "$PLASMOID_DEST/contents/icons/lilslimer.png" ]] || fail "Installed plasmoid missing icon"
}

install_backend() {
    info "Installing backend files..."
    rm -rf "$BACKEND_DEST"
    mkdir -p "$BACKEND_DEST"
    cp -a "$BACKEND_SRC/." "$BACKEND_DEST/"

    find "$BACKEND_DEST" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
    find "$BACKEND_DEST" -name '*.pyc' -type f -delete 2>/dev/null || true

    chmod +x "$BACKEND_DEST/brain.py" || true
}

install_service() {
    info "Installing systemd user service..."
    mkdir -p "$SERVICE_DIR"

    # Keep the checked-in unit as the single source of truth.
    install -m 644 "$SCRIPT_DIR/systemd/$SERVICE_NAME" "$SERVICE_DEST"

    systemctl --user daemon-reload
    systemctl --user enable --now "$SERVICE_NAME"
}

info "Installing $APP_NAME..."

[[ "$EUID" -ne 0 ]] || fail "Run as your normal desktop user, not with sudo."

verify_source_tree

require_command python3
require_command systemctl
require_command kpackagetool6 "Install KDE Plasma package tools first."

if ! systemctl --user show-environment >/dev/null 2>&1; then
    fail "systemctl --user is not available in this session. Log into a normal graphical KDE session and rerun."
fi

if ! command -v kdotool >/dev/null 2>&1; then
    if command -v xdotool >/dev/null 2>&1; then
        info "kdotool not found; xdotool fallback is available. Terminal/Judge detection may be limited on Wayland."
    else
        print_kdotool_hint
        exit 1
    fi
fi

# Preserve the current runtime snapshot across kpackagetool upgrades.
# A temporary file outside the plasmoid directory survives package replacement.
STATE_BACKUP=""
cleanup_state_backup() {
    if [[ -n "$STATE_BACKUP" ]]; then
        rm -f -- "$STATE_BACKUP"
    fi
}
trap cleanup_state_backup EXIT
if [[ -f "$STATE_DEST" ]]; then
    STATE_BACKUP="$(mktemp)"
    cp -- "$STATE_DEST" "$STATE_BACKUP"
fi

info "Stopping existing brain service if present..."
systemctl --user stop "$SERVICE_NAME" >/dev/null 2>&1 || true
systemctl --user disable "$SERVICE_NAME" >/dev/null 2>&1 || true

install_plasmoid
if [[ -n "$STATE_BACKUP" ]]; then
    cp -- "$STATE_BACKUP" "$STATE_DEST"
fi
install_backend
install_service

info "Restarting plasmashell..."
restart_plasma

cat <<EOF2

[lilslimer] Install complete. 🧪

Add Lil Slimer from:
  Right-click panel or desktop → Add Widgets → Lil Slimer

Useful commands:
  systemctl --user status $SERVICE_NAME
  systemctl --user restart $SERVICE_NAME
  journalctl --user -u $SERVICE_NAME -f

State file:
  $STATE_DEST

EOF2
