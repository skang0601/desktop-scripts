#!/usr/bin/env bash
# Every package in the Brewfile, then the setup around two of them.
#
#   ./install.sh             # install what the Brewfile lists and is missing
#   ./install.sh --upgrade   # also upgrade everything the Brewfile lists
#   ./install.sh --dry-run   # show what would happen, change nothing
#
# `brew bundle check` gates the Brewfile and each part's app_check gates the
# part, so re-running is a no-op.
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
parse_module_args "${rest[@]}"

if ! have brew; then
  warn "no Homebrew; this module installs through it (ADR 0006)"
  warn "Bazzite ships it; elsewhere see https://brew.sh"
  exit 1
fi

# Without --upgrade, a run adds what is missing and leaves versions alone, so
# a re-run changes nothing. With it, `check` also counts an outdated entry as
# unsatisfied, and `install` upgrades it. `check` has --no-upgrade but no
# --upgrade: checking versions is its default.
check_args=()
[[ "$UPGRADE" == --upgrade ]] || check_args=(--no-upgrade)
if brew_bundle check "${check_args[@]}" >/dev/null 2>&1; then
  skip "Brewfile" "every entry installed$([[ "$UPGRADE" == --upgrade ]] && echo ' and current')"
else
  if [[ "$UPGRADE" == --upgrade ]]; then
    say "installing and upgrading from the Brewfile"
  else
    say "installing from the Brewfile"
  fi
  if dry; then
    brew_bundle check "${check_args[@]}" --verbose 2>&1 | sed 's/^/    /' || true
    printf '    [dry-run] brew bundle install %s --file=%s\n' "$UPGRADE" "$BREWFILE"
  else
    brew_split_shared_dir share/pwsh
    pwsh_owner="$BREW_SPLIT_OWNER"
    if ! brew_bundle install "$UPGRADE"; then
      warn "brew bundle failed; the setup below runs anyway"
      PARTS_FAILED+=(Brewfile)
    fi
    [[ -z "$pwsh_owner" ]] || brew_relink "$pwsh_owner"
  fi
fi

install_part "$MODULE/rust.sh"
install_part "$MODULE/claude-code.sh"

parts_ok
