#!/usr/bin/env bash
# Install apps and tooling that aren't already on the system.
#
#   ./install.sh                 # everything in apps.d/
#   ./install.sh emacs go        # only these
#   ./install.sh --dry-run       # show what would happen, change nothing
#
# Each app is a file in apps.d/ defining APP_NAME, app_check and app_install.
# Idempotent: app_check gates every install, so re-running is a no-op.
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"
# shellcheck source=lib.sh
source "$MODULE/lib.sh"

ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    -*) warn "unknown option: $a"; exit 2 ;;
    *) ARGS+=("$a") ;;
  esac
done

dry && say "dry run -- nothing will be installed"

if [[ ${#ARGS[@]} -gt 0 ]]; then
  FILES=()
  for name in "${ARGS[@]}"; do
    f="$MODULE/apps.d/$name.sh"
    [[ -f "$f" ]] || { warn "no such app: $name"; exit 2; }
    FILES+=("$f")
  done
else
  mapfile -t FILES < <(find "$MODULE/apps.d" -name '*.sh' | sort)
fi

LAYERED_MARKER="$(mktemp -u)"
export LAYERED_MARKER
trap 'rm -f "$LAYERED_MARKER"' EXIT

for f in "${FILES[@]}"; do
  # Subshell per app so app_check/app_install definitions can't leak between files.
  (
    source "$f"
    if app_check; then
      skip "$APP_NAME"
    else
      say "installing $APP_NAME"
      app_install || warn "$APP_NAME failed"
    fi
  )
done

if [[ -e "$LAYERED_MARKER" ]]; then
  echo
  warn "packages were layered; reboot before they are usable"
fi
