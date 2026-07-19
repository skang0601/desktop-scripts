#!/usr/bin/env bash
# Run the modules enabled for this machine.
#
#   ./bootstrap.sh              # modules from hosts/$(hostname).modules, or all
#   ./bootstrap.sh --list       # show what's available and what's enabled
#   ./bootstrap.sh keybindings  # run specific modules, ignoring the host file
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTFILE="$REPO/hosts/$(hostname).modules"

available() { find "$REPO/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort; }

enabled() {
  if [[ -f "$HOSTFILE" ]]; then
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]//g' "$HOSTFILE"
  else
    available
  fi
}

if [[ "${1:-}" == "--list" ]]; then
  echo "available modules:"
  available | sed 's/^/  /'
  echo
  if [[ -f "$HOSTFILE" ]]; then
    echo "enabled on $(hostname) (via hosts/$(hostname).modules):"
  else
    echo "no hosts/$(hostname).modules -- everything is enabled by default:"
  fi
  enabled | sed 's/^/  /'
  exit 0
fi

if [[ $# -gt 0 ]]; then
  MODULES=("$@")
else
  mapfile -t MODULES < <(enabled)
  [[ -f "$HOSTFILE" ]] \
    || echo "note: no hosts/$(hostname).modules, running everything"
fi

for m in "${MODULES[@]}"; do
  script="$REPO/modules/$m/install.sh"
  if [[ ! -x "$script" ]]; then
    echo "!! skipping '$m': no executable $script" >&2
    continue
  fi
  echo
  echo "======================================================================"
  echo "  $m"
  echo "======================================================================"
  "$script"
done

echo
echo "bootstrap complete. Some modules have manual follow-up -- see their READMEs."
