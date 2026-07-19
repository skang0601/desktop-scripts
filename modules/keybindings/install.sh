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
  # Bazzite enables input-remapper by default and hides its desktop entry, so
  # it is easy to miss. It grabs the same evdev devices keyd does.
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
    # dnf5 manages the repo file only; it does not layer onto the running host.
    if command -v dnf5 >/dev/null; then
      # -y is a dnf5 global option and must precede the subcommand.
      sudo dnf5 -y copr enable "$COPR"
    else
      sudo curl -fsSL -o "/etc/yum.repos.d/_copr_${COPR/\//-}.repo" \
        "https://copr.fedorainfracloud.org/coprs/$COPR/repo/fedora-$(rpm -E %fedora)/${COPR/\//-}-fedora-$(rpm -E %fedora).repo"
    fi

    echo "==> layering keyd"
    echo "    note: layered packages can pause image updates or block a rebase"
    echo "    if a future image conflicts. keyd needs root-level evdev access,"
    echo "    so Flatpak/Homebrew are not alternatives."
    # rpm-ostree install does not prompt, and -y is not portable across versions.
    sudo rpm-ostree install keyd

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
# On ostree systems /etc is writable, and files with no /usr/etc counterpart
# survive upgrades and rebases via the 3-way merge.
sudo install -Dm644 "$MODULE/default.conf" /etc/keyd/default.conf

echo "==> validating config before touching the running daemon"
sudo keyd check /etc/keyd/default.conf

echo "==> installing libinput touchpad quirk"
sudo install -Dm644 "$MODULE/local-overrides.quirks" /etc/libinput/local-overrides.quirks

echo "==> enabling keyd.service"
# Requires the packaged keyd. A source build installs its unit to
# /usr/local/lib/systemd/system, which systemd on Fedora Atomic does not load:
# the service reports enabled and never starts (keyd issue #1139).
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
