#!/usr/bin/env bash
# Run the modules enabled for this machine.
#
#   ./bootstrap.sh              # modules from hosts/$(hostname).modules
#   ./bootstrap.sh --host work  # use hosts/work.modules regardless of hostname
#   ./bootstrap.sh --all        # every module, for a machine with no profile
#   ./bootstrap.sh keybindings  # run specific modules, ignoring the host file
#   ./bootstrap.sh --list       # show what's available and what's enabled
#   ./bootstrap.sh --dry-run    # show every command, change nothing
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO/lib/common.sh"
source "$REPO/lib/hosts.sh"

ARGS=()
HOST=""
ALL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; export DRY_RUN ;;
    --list) LIST=1 ;;
    --all) ALL=1 ;;
    --host) HOST="${2:?--host needs a name}"; shift ;;
    --host=*) HOST="${1#*=}" ;;
    -*) warn "unknown option: $1"; exit 2 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done

HOSTFILE="$(host_file "$HOST")"

if [[ -n "${LIST:-}" ]]; then
  echo "available modules:"
  available_modules | sed 's/^/  /'
  echo
  if [[ -f "$HOSTFILE" ]]; then
    echo "enabled via $(basename "$HOSTFILE"):"
    host_modules "$HOSTFILE" | sed 's/^/  /'
  else
    echo "no $(basename "$HOSTFILE"); pass --host <name> or --all"
  fi
  exit 0
fi

if [[ ${#ARGS[@]} -gt 0 ]]; then
  MODULES=("${ARGS[@]}")
elif [[ -n "$ALL" ]]; then
  mapfile -t MODULES < <(available_modules)
elif [[ -f "$HOSTFILE" ]]; then
  mapfile -t MODULES < <(host_modules "$HOSTFILE")
else
  # Every module changes the machine, and a missing profile usually means the
  # hostname is not the one the profile was written for, so this asks.
  warn "no $(basename "$HOSTFILE") for this machine"
  warn "pass --host <name> for a profile in hosts/, --all for every module, or module names"
  exit 2
fi

# Hooks under .git/hooks are not tracked, so a clone starts without them. Local
# to this repo, and cheap enough to reassert on every run rather than document
# as a manual step.
if [[ -d "$REPO/.git" && "$(git -C "$REPO" config core.hooksPath || true)" != .githooks ]]; then
  run git -C "$REPO" config core.hooksPath .githooks
fi

FAILED=()
for m in "${MODULES[@]}"; do
  script="$REPO/modules/$m/install.sh"
  if [[ ! -x "$script" ]]; then
    echo "!! skipping '$m': no executable $script" >&2
    FAILED+=("$m")
    continue
  fi
  echo
  echo "======================================================================"
  echo "  $m"
  echo "======================================================================"
  # Modules are independent, so one that fails costs its own changes and not
  # the rest of the run. Each module reports its own detail; this only records
  # that it came back nonzero.
  set +e
  if dry; then "$script" --dry-run; else "$script"; fi
  rc=$?
  set -e
  (( rc == 0 )) || FAILED+=("$m")
done

echo
if (( ${#FAILED[@]} )); then
  warn "modules with failures: ${FAILED[*]}"
  warn "scroll up for the detail, or re-run just those: ./bootstrap.sh ${FAILED[*]}"
fi
if dry; then
  echo "dry run complete. Nothing was changed."
else
  echo "bootstrap complete. Some modules have manual follow-up -- see their READMEs."
fi
(( ${#FAILED[@]} == 0 ))
