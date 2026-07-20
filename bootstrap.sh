#!/usr/bin/env bash
# Run the modules enabled for this machine.
#
#   ./bootstrap.sh              # modules from hosts/$(hostname).modules, or all
#   ./bootstrap.sh --list       # show what's available and what's enabled
#   ./bootstrap.sh --dry-run    # show every command, change nothing
#   ./bootstrap.sh keybindings  # run specific modules, ignoring the host file
#   ./bootstrap.sh --host work  # use hosts/work.modules regardless of hostname
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO/lib/common.sh"

available() { find "$REPO/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort; }

enabled() {
  if [[ -f "$HOSTFILE" ]]; then
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]//g' "$HOSTFILE"
  else
    available
  fi
}

ARGS=()
HOST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; export DRY_RUN ;;
    --list) LIST=1 ;;
    --host) HOST="${2:?--host needs a name}"; shift ;;
    --host=*) HOST="${1#*=}" ;;
    -*) warn "unknown option: $1"; exit 2 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done

# Hostname is a weak identifier: Fedora leaves /etc/hostname empty and falls
# back to DEFAULT_HOSTNAME from /etc/os-release, so unrelated machines commonly
# all answer "fedora". --host exists to say which profile you actually mean.
HOSTFILE="$REPO/hosts/${HOST:-$(hostname)}.modules"

if [[ -n "${LIST:-}" ]]; then
  echo "available modules:"
  available | sed 's/^/  /'
  echo
  if [[ -f "$HOSTFILE" ]]; then
    echo "enabled via $(basename "$HOSTFILE"):"
  else
    echo "no $(basename "$HOSTFILE") -- everything is enabled by default:"
  fi
  enabled | sed 's/^/  /'
  exit 0
fi

if [[ ${#ARGS[@]} -gt 0 ]]; then
  MODULES=("${ARGS[@]}")
else
  mapfile -t MODULES < <(enabled)
  [[ -f "$HOSTFILE" ]] \
    || echo "note: no $(basename "$HOSTFILE"), running everything"
fi

# Hooks under .git/hooks are not tracked, so a clone starts without them. This
# points git at the tracked directory instead. Local to this repo, and cheap
# enough to reassert on every run rather than document as a manual step.
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
