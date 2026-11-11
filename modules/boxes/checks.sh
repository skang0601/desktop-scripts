# State checks for the boxes module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

# shellcheck source=lib.sh
source "$MODULE/lib.sh"

module_checks() {
  check_part "$MODULE/dev-box/dev-box.sh"
  check_part "$MODULE/claude-desktop.sh"
}
