#!/usr/bin/env bash
# GNOME desktop: Studio Display brightness control, and a login screen that
# uses the session's display layout.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"
# shellcheck source=./common.sh
source "$MODULE/common.sh"

for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    *) warn "unknown option: $a"; exit 2 ;;
  esac
done

dry && say "dry run -- nothing will be changed"

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

  if cmp -s "$GDM_SRC" "$GDM_DEST"; then
    skip monitors.xml "$GDM_DEST matches $GDM_SRC"
    return 0
  fi

  # A copy, not a symlink: the login screen's user cannot read this home.
  say "copying $GDM_SRC to $GDM_DEST"
  run sudo install -m644 "$GDM_SRC" "$GDM_DEST"
  run sudo restorecon "$GDM_DEST"
  say "takes effect at the next login screen"
}

# Each part is independent, so one failing does not stop the other.
status=0
say "brightness"
install_brightness || status=1
say "login screen"
install_login_screen || status=1
exit "$status"
