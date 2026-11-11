# Host profiles: which modules a machine enables. Sourced by bootstrap.sh and
# doctor.sh.
# shellcheck shell=bash

available_modules() {
  find "$REPO/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

# Hostname is a weak identifier: Fedora leaves /etc/hostname empty and falls
# back to DEFAULT_HOSTNAME from /etc/os-release, so unrelated machines commonly
# all answer "fedora". --host says which profile is meant.
host_file() { printf '%s/hosts/%s.modules\n' "$REPO" "${1:-$(hostname)}"; }

# One module per line, comments and blank lines dropped.
host_modules() {
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]//g' "$1"
}
