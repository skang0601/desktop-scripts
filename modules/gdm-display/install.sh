#!/usr/bin/env bash
# Login screen display layout: copies this user's monitors.xml to GDM so the
# login screen uses the same scale (2x on the Studio Display) as the session.
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

if [[ ! -f "$GDM_SRC" ]]; then
  warn "$GDM_SRC does not exist; set a scale in Settings > Displays first"
  exit 1
fi

# A copy, not a symlink: the gdm user cannot read this user's home directory.
if cmp -s "$GDM_SRC" "$GDM_DEST" 2>/dev/null; then
  skip monitors.xml "GDM's copy matches $GDM_SRC"
  exit 0
fi

say "copying $GDM_SRC to $GDM_DEST"
run sudo install -D -o gdm -g gdm -m644 "$GDM_SRC" "$GDM_DEST"
# GDM silently ignores a monitors.xml carrying the wrong label, such as the
# config_home_t a file keeps when it is moved rather than copied from home.
run sudo restorecon -R "$(dirname "$GDM_DEST")"
say "takes effect at the next login screen"
