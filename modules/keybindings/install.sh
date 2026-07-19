#!/usr/bin/env bash
# Install keyd and apply the macOS-style modifier config.
# Idempotent -- safe to re-run.
#
# Handles both traditional (dnf) and atomic/image-based (rpm-ostree) systems.
#
#   ./install.sh --dry-run     # show every command, change nothing
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"

COPR=alternateved/keyd     # keyd is not in Fedora proper; this COPR tracks it

for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    *) warn "unknown option: $a"; exit 2 ;;
  esac
done

dry && say "dry run -- nothing will be changed"

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
    say "keyd already present"
    return
  fi

  if is_atomic; then
    say "atomic system detected (ostree)"
    # dnf5 manages the repo file only; it does not layer onto the running host.
    if command -v dnf5 >/dev/null; then
      # -y is a dnf5 global option and must precede the subcommand.
      run sudo dnf5 -y copr enable "$COPR"
    else
      run sudo curl -fsSL -o "/etc/yum.repos.d/_copr_${COPR/\//-}.repo" \
        "https://copr.fedorainfracloud.org/coprs/$COPR/repo/fedora-$(rpm -E %fedora)/${COPR/\//-}-fedora-$(rpm -E %fedora).repo"
    fi

    say "layering keyd"
    echo "    note: layered packages can pause image updates or block a rebase"
    echo "    if a future image conflicts. keyd needs root-level evdev access,"
    echo "    so Flatpak/Homebrew are not alternatives."
    # rpm-ostree install does not prompt, and -y is not portable across versions.
    run sudo rpm-ostree install keyd

    echo
    warn "REBOOT REQUIRED. Then re-run this script to finish configuration."
    echo "   (or: sudo rpm-ostree install --apply-live keyd, to skip the reboot)"
    # Under --dry-run keep going so the whole plan is visible in one pass.
    dry || exit 0
  fi

  run sudo dnf copr enable -y "$COPR"
  run sudo dnf install -y keyd
}

install_keyd
check_input_remapper

say "validating default.conf"
# The repo copy, not the installed one: checking after `install` leaves a
# broken config in /etc when it fails.
if dry; then
  printf '    [dry-run] keyd check %s\n' "$MODULE/default.conf"
else
  # keyd exits nonzero only on a parse error. An unknown key or action is a
  # warning on stdout with exit 0, so a whole layer of bindings can be dropped
  # while the check "passes" -- which is exactly how the trailing-comment form
  # went unnoticed. Any WARNING is fatal here.
  check_out="$(keyd check "$MODULE/default.conf" 2>&1)" || true
  printf '%s\n' "$check_out"
  if grep -q WARNING <<<"$check_out"; then
    warn "default.conf has invalid bindings; not installing it"
    exit 1
  fi
fi

say "installing /etc/keyd/default.conf"
# On ostree systems /etc is writable, and files with no /usr/etc counterpart
# survive upgrades and rebases via the 3-way merge.
run sudo install -Dm644 "$MODULE/default.conf" /etc/keyd/default.conf

say "installing libinput touchpad quirk"
run sudo install -Dm644 "$MODULE/local-overrides.quirks" /etc/libinput/local-overrides.quirks

say "enabling keyd.service"
# Requires the packaged keyd. A source build installs its unit to
# /usr/local/lib/systemd/system, which systemd on Fedora Atomic does not load:
# the service reports enabled and never starts (keyd issue #1139).
run sudo systemctl enable --now keyd
run sudo keyd reload

say "installing user app.conf"
run install -Dm644 "$MODULE/app.conf" "$HOME/.config/keyd/app.conf"

if ! id -nG "$USER" | grep -qw keyd; then
  say "adding $USER to the keyd group (needed for keyd-application-mapper)"
  run sudo usermod -aG keyd "$USER"
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
