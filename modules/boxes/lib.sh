# distrobox helpers for the boxes module.
# shellcheck shell=bash

# `distrobox list` prints a padded table with the name in the second column.
distrobox_exists() {
  distrobox list 2>/dev/null | awk -F'|' 'NR>1 {gsub(/ /,"",$2); print $2}' | grep -qx "$1"
}

# Vendors who ship .deb and nothing else share one box rather than each pulling
# an image of its own (ADR 0005).
DEB_BOX=ubuntu
DEB_BOX_IMAGE=quay.io/toolbx/ubuntu-toolbox:24.04

distrobox_ensure() {
  local name="$1" image="$2"
  shift 2
  distrobox_exists "$name" && return 0
  say "creating the $name distrobox from $image"
  run distrobox create --name "$name" --image "$image" --yes "$@"
}
