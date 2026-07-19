#!/usr/bin/env bash
# Install keyd and apply the macOS-style modifier config.
# Idempotent -- safe to re-run.
#
# Handles both traditional (dnf) and atomic/image-based (rpm-ostree, bootc)
# systems, since this is meant to survive a move to Bazzite.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

is_atomic() { [[ -f /run/ostree-booted ]]; }

install_keyd() {
  command -v keyd >/dev/null && { echo "==> keyd already present: $(keyd --version 2>&1 | head -1)"; return; }

  # keyd is not in Fedora proper; alternateved/keyd is the maintained COPR.
  if is_atomic; then
    echo "==> atomic system detected (ostree)"
    echo "    'dnf copr enable' is unavailable here; dropping the repo file directly."
    sudo wget -q -O /etc/yum.repos.d/_copr_alternateved-keyd.repo \
      "https://copr.fedorainfracloud.org/coprs/alternateved/keyd/repo/fedora-$(rpm -E %fedora)/alternateved-keyd-fedora-$(rpm -E %fedora).repo"
    echo "==> layering keyd (this requires a reboot to take effect)"
    sudo rpm-ostree install -y keyd
    echo
    echo "!! REBOOT REQUIRED, then re-run this script to finish configuration."
    exit 0
  else
    sudo dnf copr enable -y alternateved/keyd
    sudo dnf install -y keyd
  fi
}

install_keyd

echo "==> installing /etc/keyd/default.conf"
# /etc is writable and preserved across upgrades on ostree systems, so this is
# the same on both flavours.
sudo install -Dm644 "$REPO/keyd/default.conf" /etc/keyd/default.conf

echo "==> validating config before touching the running daemon"
sudo keyd check /etc/keyd/default.conf

echo "==> installing libinput touchpad quirk (see ADR 0003)"
sudo install -Dm644 "$REPO/keyd/local-overrides.quirks" /etc/libinput/local-overrides.quirks

echo "==> enabling keyd.service"
sudo systemctl enable --now keyd
sudo keyd reload

echo "==> installing user app.conf"
install -Dm644 "$REPO/keyd/app.conf" "$HOME/.config/keyd/app.conf"

if ! id -nG "$USER" | grep -qw keyd; then
  echo "==> adding $USER to the keyd group (needed for keyd-application-mapper)"
  sudo usermod -aG keyd "$USER"
  echo "    log out and back in for this to take effect"
fi

cat <<'EOF'

done.

  verify      sudo keyd monitor        # then tap Super, then Super+C
  next        ./gnome/gsettings.sh     # GNOME shortcut collisions
  optional    docs/gnome-wayland-bridge.md

first thing to test: open Ptyxis and foot and confirm Ctrl+Insert copies and
Shift+Insert pastes. If they don't, those terminals need the Layer 3 bridge.
EOF
