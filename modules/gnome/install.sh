#!/usr/bin/env bash
# GNOME desktop: Studio Display brightness control, a login screen that uses
# the session's display layout, and no automatic suspend.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"
# shellcheck source=./common.sh
source "$MODULE/common.sh"

parse_module_args "$@"

install_brightness() {
  # The project is its own repo so it can be developed and versioned on its
  # own; this module only places and builds it. An existing checkout is left at
  # whatever commit it is on: pulling is a decision, not an install step.
  if [[ -d "$ASD_SRC/.git" ]]; then
    skip asd-brightness "checkout at $ASD_SRC"
  else
    say "cloning asd-brightness into $ASD_SRC"
    run git clone "$ASD_REMOTE" "$ASD_SRC"
  fi

  # The build runs in a container so the helper is a static binary that does
  # not depend on whichever Rust toolchain the host has, or none.
  if ! have podman && ! have docker; then
    warn "asd-brightness builds in a container; install podman or docker"
    return 1
  fi

  local head built dirty=0
  head="$(asd_head)"
  built="$(asd_built)"
  [[ -d "$ASD_SRC/.git" ]] && ! git -C "$ASD_SRC" diff --quiet HEAD 2>/dev/null && dirty=1

  if [[ -n "$head" && "$head" == "$built" && $dirty == 0 ]]; then
    skip extension "built from ${head:0:7}"
  else
    (( dirty )) && say "$ASD_SRC has uncommitted changes; rebuilding"
    say "building and installing $ASD_UUID"
    run "$ASD_SRC/install.sh"
    if dry; then
      printf '    [dry-run] record built commit in %s\n' "$ASD_STAMP"
    else
      git -C "$ASD_SRC" rev-parse HEAD >"$ASD_STAMP"
    fi
  fi

  if cmp -s "$ASD_RULE_SRC" "$ASD_RULE_DEST" && [[ ! -e "$ASD_RULE_STALE" ]]; then
    skip "udev rule" "$ASD_RULE_DEST matches the checkout"
  else
    say "installing $ASD_RULE_DEST"
    run sudo install -m644 "$ASD_RULE_SRC" "$ASD_RULE_DEST"
    run sudo restorecon "$ASD_RULE_DEST"
    [[ -e "$ASD_RULE_STALE" ]] && run sudo rm -f "$ASD_RULE_STALE"
    run sudo udevadm control --reload
    # Re-applies the rule to the display's existing nodes, so access does not
    # wait for a replug or reboot.
    run sudo udevadm trigger --subsystem-match=hidraw
  fi

  local enabled new
  enabled="$(gsettings get org.gnome.shell enabled-extensions)"
  if [[ "$enabled" == *"'$ASD_UUID'"* ]]; then
    skip "enabled" "in org.gnome.shell enabled-extensions"
  elif gnome-extensions info "$ASD_UUID" >/dev/null 2>&1; then
    say "enabling $ASD_UUID"
    run gnome-extensions enable "$ASD_UUID"
  else
    # gnome-extensions only knows extensions the running Shell has scanned, and
    # on Wayland the Shell scans only at login. Listing it in the setting makes
    # the next login load it.
    say "adding $ASD_UUID to enabled-extensions"
    if [[ "$enabled" == "@as []" ]]; then
      new="['$ASD_UUID']"
    else
      new="${enabled%]}, '$ASD_UUID']"
    fi
    run gsettings set org.gnome.shell enabled-extensions "$new"
  fi

  if ! gnome-extensions info "$ASD_UUID" 2>/dev/null | grep -q 'State: ACTIVE'; then
    warn "the running Shell has not loaded $ASD_UUID; log out and back in"
  fi
}

install_login_screen() {
  if [[ ! -f "$GDM_SRC" ]]; then
    warn "$GDM_SRC does not exist; set a scale in Settings > Displays first"
    return 1
  fi

  # A copy, not a symlink: the login screen's user cannot read this home.
  install_file --root "$GDM_SRC" "$GDM_DEST"
  (( FILE_CHANGED )) || return 0
  run sudo restorecon "$GDM_DEST"
  say "takes effect at the next login screen"
}

install_power() {
  if [[ "$(gsettings get "$POWER_SCHEMA" "$POWER_KEY")" == "'nothing'" ]]; then
    skip "session" "$POWER_KEY is nothing"
  else
    say "turning off automatic suspend in this session"
    run gsettings set "$POWER_SCHEMA" "$POWER_KEY" nothing
  fi

  if cmp -s "$GDM_POWER_SRC" "$GDM_POWER_DEST" && [[ "$GDM_DCONF_DB" -nt "$GDM_POWER_DEST" ]]; then
    skip "login screen" "$GDM_POWER_DEST compiled into $GDM_DCONF_DB"
    return 0
  fi

  # A copy, not a symlink: dconf update runs as root and the login screen's
  # user cannot read this home. The keyfile does nothing until compiled.
  say "turning off automatic suspend at the login screen"
  run sudo install -m644 "$GDM_POWER_SRC" "$GDM_POWER_DEST"
  run sudo dconf update
}

# Each part is independent, so one failing does not stop the others.
status=0
say "brightness"
install_brightness || status=1
say "login screen"
install_login_screen || status=1
say "power"
install_power || status=1
exit "$status"
