#!/usr/bin/env bash
# Install keyd and activate a modifier profile.
#
#   ./scripts/install-keyd.sh            # installs the 'whitelist' profile
#   ./scripts/install-keyd.sh full-swap  # installs the 'full-swap' profile
#
# Idempotent: safe to re-run to switch profiles.
set -euo pipefail

PROFILE="${1:-whitelist}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/keyd/profiles/$PROFILE.conf"

[[ -f "$SRC" ]] || { echo "no such profile: $PROFILE (have: $(cd "$REPO/keyd/profiles" && ls *.conf | sed 's/\.conf//' | tr '\n' ' '))" >&2; exit 1; }

if ! command -v keyd >/dev/null; then
  echo "==> installing keyd from COPR (not in Fedora's own repos)"
  sudo dnf copr enable -y alternateved/keyd
  sudo dnf install -y keyd
fi

echo "==> installing profile '$PROFILE' to /etc/keyd/default.conf"
sudo install -Dm644 "$SRC" /etc/keyd/default.conf

echo "==> installing libinput touchpad quirk"
sudo install -Dm644 "$REPO/keyd/local-overrides.quirks" /etc/libinput/local-overrides.quirks

echo "==> enabling keyd.service"
sudo systemctl enable --now keyd
sudo keyd reload

echo "==> installing user app.conf (application-aware layer)"
install -Dm644 "$REPO/keyd/app.conf" "$HOME/.config/keyd/app.conf"

echo
echo "done. verify with:  sudo keyd monitor"
echo "next: enable the GNOME bridge -- see docs/gnome-wayland-bridge.md"
