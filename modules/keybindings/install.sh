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
  # while the check "passes". Any WARNING is fatal here.
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

say "installing the keyd.service restart drop-in"
# Before enabling, so the first start already has the policy.
run sudo install -Dm644 "$MODULE/keyd-restart.conf" \
  /etc/systemd/system/keyd.service.d/restart.conf
run sudo systemctl daemon-reload

say "enabling keyd.service"
# Requires the packaged keyd. A source build installs its unit to
# /usr/local/lib/systemd/system, which systemd on Fedora Atomic does not load:
# the service reports enabled and never starts (keyd issue #1139).
run sudo systemctl enable --now keyd

# keyd 2.6.0 has segfaulted in process_event applying a changed config through
# `keyd reload`, which leaves every keyboard unmapped while systemd still
# reports the unit enabled. Reload is still the right call -- it keeps the
# device grabs, where a restart drops and re-takes them.
run sudo keyd reload
if ! dry && ! systemctl is-active --quiet keyd; then
  warn "keyd died applying the config; restarting it"
  run sudo systemctl restart keyd
fi

say "installing user app.conf"
run install -Dm644 "$MODULE/app.conf" "$HOME/.config/keyd/app.conf"

if ! id -nG "$USER" | grep -qw keyd; then
  say "adding $USER to the keyd group (needed for keyd-application-mapper)"

  # On nss-altfiles systems the image's groups live in /usr/lib/group and only
  # local ones in /etc/group. usermod resolves keyd through NSS, finds it, then
  # amends /etc/group -- which holds no keyd record -- and exits 0 having done
  # nothing at all. Copying the record across first gives it something local to
  # extend. nsswitch.conf merges the files and altfiles sources, so a record in
  # both is the arrangement they are designed for, not a conflict.
  keyd_group="$(getent group keyd || true)"
  if [[ -n "$keyd_group" ]] && ! grep -q '^keyd:' /etc/group; then
    if dry; then
      printf '    [dry-run] append %s to /etc/group\n' "$keyd_group"
    else
      printf '%s\n' "$keyd_group" | sudo tee -a /etc/group >/dev/null
    fi
  fi

  run sudo usermod -aG keyd "$USER"

  # usermod reports success whether or not the membership landed, and the
  # symptom is a mapper that runs but cannot open /run/keyd.socket, which shows
  # up only as a log full of permission errors.
  if ! dry && ! getent group keyd | grep -qw "$USER"; then
    warn "keyd group membership did not take; per-app remapping will not work"
    exit 1
  fi

  echo "    log out and back in for this to take effect"
fi

cat <<'EOF'

done.

  verify      sudo keyd monitor        # then tap Super, then Super+C
  next        ./gsettings.sh           # GNOME shortcut changes
  optional    gnome-wayland-bridge.md  # per-app terminal behaviour

first thing to test: tap Super for the overview, then Cmd+C in a GUI app.

in a terminal the clipboard is Ctrl+Shift+C/V, pressed physically -- Ptyxis
ignores the Insert forms the mac layer emits, so Cmd+C does not copy there.
EOF
