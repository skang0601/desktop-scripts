#!/usr/bin/env bash
# Apple Studio Display (XDR) brightness: the asd-brightness GNOME Shell
# extension, built from its own repo.
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

# The project is its own repo so it can be developed and versioned on its own;
# this module only places and builds it. An existing checkout is left at
# whatever commit it is on: pulling is a decision, not an install step.
if [[ -d "$ASD_SRC/.git" ]]; then
  skip asd-brightness "checkout at $ASD_SRC"
else
  say "cloning asd-brightness into $ASD_SRC"
  run git clone "$ASD_REMOTE" "$ASD_SRC"
fi

# The build runs in a container so the helper is a static binary that does not
# depend on whichever Rust toolchain the host has, or none.
if ! have podman && ! have docker; then
  warn "asd-brightness builds in a container; install podman or docker"
  exit 1
fi

head="$(asd_head)"
built="$(asd_built)"
dirty=0
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
