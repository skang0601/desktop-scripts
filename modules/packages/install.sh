#!/usr/bin/env bash
# Install the Brewfile, then set up the apps in apps.d/.
#
#   ./install.sh                 # the Brewfile, then every app in apps.d/
#   ./install.sh emacs rust      # only these apps, without the Brewfile
#   ./install.sh --upgrade       # also upgrade everything the Brewfile lists
#   ./install.sh --dry-run       # show what would happen, change nothing
#
# Each app is a file in apps.d/ defining APP_NAME, app_check and app_install.
# Idempotent: `brew bundle check` gates the Brewfile and app_check gates every
# app, so re-running is a no-op.
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"
# shellcheck source=lib.sh
source "$MODULE/lib.sh"

# --upgrade belongs to this module alone, so it is taken out before the shared
# parser sees it.
UPGRADE=--no-upgrade
rest=()
for a in "$@"; do
  if [[ "$a" == --upgrade ]]; then UPGRADE=--upgrade; else rest+=("$a"); fi
done
parse_module_args --with-args "${rest[@]}"

if ! have brew; then
  warn "no Homebrew; this module installs through it (ADR 0006)"
  warn "Bazzite ships it; elsewhere see https://brew.sh"
  exit 1
fi

if [[ ${#ARGS[@]} -gt 0 ]]; then
  NAMES=("${ARGS[@]}")
  for name in "${NAMES[@]}"; do
    app_path "$name" >/dev/null || { warn "no such app: $name"; exit 2; }
  done
else
  mapfile -t NAMES < <(app_names)
fi

LAYERED_MARKER="$(mktemp -u)"
export LAYERED_MARKER
RESULTS="$(mktemp)"
trap 'rm -f "$LAYERED_MARKER" "$RESULTS"' EXIT

# Named apps are a targeted re-run, which the Brewfile has no part in.
if [[ ${#ARGS[@]} -gt 0 && "$UPGRADE" == --upgrade ]]; then
  warn "--upgrade applies to the Brewfile, which a run naming apps skips"
  exit 2
fi
if [[ ${#ARGS[@]} -eq 0 ]]; then
  # Without --upgrade, a run adds what is missing and leaves versions alone, so
  # a re-run changes nothing. With it, `check` also counts an outdated entry as
  # unsatisfied, and `install` upgrades it. `check` has --no-upgrade but no
  # --upgrade: checking versions is its default.
  check_args=()
  [[ "$UPGRADE" == --upgrade ]] || check_args=(--no-upgrade)
  if brew_bundle check "${check_args[@]}" >/dev/null 2>&1; then
    skip "Brewfile" "every entry installed$([[ "$UPGRADE" == --upgrade ]] && echo ' and current')"
    printf 'present\tBrewfile\n' >>"$RESULTS"
  else
    if [[ "$UPGRADE" == --upgrade ]]; then
      say "installing and upgrading from the Brewfile"
    else
      say "installing from the Brewfile"
    fi
    if dry; then
      brew_bundle check "${check_args[@]}" --verbose 2>&1 | sed 's/^/    /' || true
      printf '    [dry-run] brew bundle install %s --file=%s\n' "$UPGRADE" "$BREWFILE"
      printf 'installed\tBrewfile\n' >>"$RESULTS"
    else
      brew_split_shared_dir share/pwsh
      pwsh_owner="$BREW_SPLIT_OWNER"
      if brew_bundle install "$UPGRADE"; then
        printf 'installed\tBrewfile\n' >>"$RESULTS"
      else
        warn "brew bundle failed; the apps below run anyway"
        printf 'failed\tBrewfile\n' >>"$RESULTS"
      fi
      [[ -z "$pwsh_owner" ]] || brew_relink "$pwsh_owner"
    fi
  fi
fi

for name in "${NAMES[@]}"; do
  f="$(app_path "$name")"
  # errexit off around the app so a failing install is one bad line in the
  # summary rather than the end of the run: the remaining apps are unrelated
  # and there is no reason a broken package should hold them hostage.
  set +e
  (
    # Subshell per app so app_check/app_install definitions can't leak between
    # files. errexit back on inside it, since the parent has it off and an
    # app_install that fails halfway must not carry on to report success.
    set -e
    APP_DIR="$(dirname "$f")"
    # shellcheck source=/dev/null
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
  # in scope; a nonzero exit means it didn't get that far. An app's name matches
  # its APP_NAME, so it names the failure just as well.
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
