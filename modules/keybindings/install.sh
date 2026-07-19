#!/usr/bin/env bash
# Install keyd and apply the macOS-style modifier config.
# Idempotent -- safe to re-run.
#
# Handles both traditional (dnf) and atomic/image-based (rpm-ostree) systems.
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COPR=alternateved/keyd     # keyd is not in Fedora proper; this COPR tracks it

is_atomic() { [[ -f /run/ostree-booted ]]; }

check_input_remapper() {
  # Bazzite ships input-remapper installed AND enabled, with its .desktop hidden
  # (NoDisplay=true), so it is easy to miss. Both it and keyd grab evdev devices
  # and create uinput virtual keyboards. No confirmed breakage is documented,
  # but running both is an obvious overlap.
  if systemctl is-enabled --quiet input-remapper.service 2>/dev/null; then
    echo
    echo "!! input-remapper.service is enabled (Bazzite enables it by default)."
    echo "   It grabs the same evdev devices keyd does. If keys misbehave:"
    echo "     sudo systemctl disable --now input-remapper.service"
    echo
  fi
}

install_keyd() {
  if command -v keyd >/dev/null; then
    echo "==> keyd already present"
    return
  fi

  if is_atomic; then
    echo "==> atomic system detected (ostree)"
    # Bazzite's documented pattern: dnf5 manages the repo file only, rpm-ostree
    # does the install. `dnf5 install` does not layer onto the running host.
    if command -v dnf5 >/dev/null; then
      sudo dnf5 copr enable -y "$COPR"
    else
      sudo curl -fsSL -o "/etc/yum.repos.d/_copr_${COPR/\//-}.repo" \
        "https://copr.fedorainfracloud.org/coprs/$COPR/repo/fedora-$(rpm -E %fedora)/${COPR/\//-}-fedora-$(rpm -E %fedora).repo"
    fi

    echo "==> layering keyd"
    echo "    note: layered packages can pause image updates or block a rebase"
    echo "    if a future image conflicts. keyd needs root-level evdev access,"
    echo "    so Flatpak/Homebrew are not alternatives."
    sudo rpm-ostree install -y keyd

    echo
    echo "!! REBOOT REQUIRED. Then re-run this script to finish configuration."
    echo "   (or: sudo rpm-ostree install --apply-live keyd, to skip the reboot)"
    exit 0
  fi

  sudo dnf copr enable -y "$COPR"
  sudo dnf install -y keyd
}

install_keyd
check_input_remapper

echo "==> installing /etc/keyd/default.conf"
# /etc is writable on ostree systems and survives upgrades and rebases: files
# with no /usr/etc counterpart are propagated forever by the 3-way merge.
sudo install -Dm644 "$MODULE/default.conf" /etc/keyd/default.conf

echo "==> validating config before touching the running daemon"
sudo keyd check /etc/keyd/default.conf

echo "==> installing libinput touchpad quirk"
sudo install -Dm644 "$MODULE/local-overrides.quirks" /etc/libinput/local-overrides.quirks

echo "==> enabling keyd.service"
# The RPM puts the unit in /usr/lib/systemd/system, which is loaded normally.
# (Building from source installs to /usr/local/lib/systemd/system instead, which
# systemd on Fedora Atomic does NOT load -- the service looks enabled and never
# starts. See keyd issue #1139. Another reason to prefer the package.)
sudo systemctl enable --now keyd
sudo keyd reload

echo "==> installing user app.conf"
install -Dm644 "$MODULE/app.conf" "$HOME/.config/keyd/app.conf"

if ! id -nG "$USER" | grep -qw keyd; then
  echo "==> adding $USER to the keyd group (needed for keyd-application-mapper)"
  sudo usermod -aG keyd "$USER"
  echo "    log out and back in for this to take effect"
fi

cat <<'EOF'

done.

  verify      sudo keyd monitor        # then tap Super, then Super+C
  next        ./gsettings.sh           # GNOME shortcut changes
  optional    gnome-wayland-bridge.md  # per-app terminal behaviour

first thing to test: open your terminals and confirm Ctrl+Insert copies and
Shift+Insert pastes. If they don't, those terminals need the Layer 3 bridge.
EOF
