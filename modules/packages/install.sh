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
RESULTS="$(mktemp)"
trap 'rm -f "$LAYERED_MARKER" "$RESULTS"' EXIT

for f in "${FILES[@]}"; do
  # errexit off around the app so a failing install is one bad line in the
  # summary rather than the end of the run: the remaining apps are unrelated
  # and there is no reason a broken package should hold them hostage.
  set +e
  (
    # Subshell per app so app_check/app_install definitions can't leak between
    # files. errexit back on inside it, since the parent has it off and an
    # app_install that fails halfway must not carry on to report success.
    set -e
    source "$f"
    if app_check; then
      skip "$APP_NAME"
      printf 'present\t%s\n' "$APP_NAME" >>"$RESULTS"
    else
      say "installing $APP_NAME"
      app_install
      printf 'installed\t%s\n' "$APP_NAME" >>"$RESULTS"
    fi
  )
  rc=$?
  set -e
  # The app records its own outcome on the paths that work, where APP_NAME is
  # in scope; a nonzero exit means it didn't get that far. apps.d filenames
  # match their APP_NAME, so the basename names it just as well.
  name="$(basename "$f" .sh)"
  if (( rc == BLOCKED )); then
    printf 'blocked\t%s\n' "$name" >>"$RESULTS"
  elif (( rc != 0 )); then
    warn "$name failed (exit $rc)"
    printf 'failed\t%s\n' "$name" >>"$RESULTS"
  fi
done

# One summary line per outcome, counted and named, or nothing when no app had
# that outcome -- an empty "failed" row reads as reassurance and is worth not
# printing at all.
report() {
  local outcome="$1" label="${2:-$1}" row
  row="$(awk -F'\t' -v s="$outcome" \
    '$1==s{n++; l=l sep $2; sep=", "} END{if(n) print n"\t"l}' "$RESULTS")"
  [[ -n "$row" ]] || return 0
  printf '    %-10s %2s  %s\n' "$label" "${row%%$'\t'*}" "${row#*$'\t'}"
}

echo
say "summary"
report installed
report present
report blocked
report failed FAILED

if [[ -e "$LAYERED_MARKER" ]]; then
  echo
  warn "packages were layered; reboot before they are usable"
fi

if grep -q '^failed' "$RESULTS"; then
  echo
  warn "re-run './install.sh <name>' to retry just the failures"
  exit 1
fi
