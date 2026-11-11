#!/usr/bin/env bash
# Fedora's GUI emacs, Doom, and the Doom config in doom/.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"
parse_module_args "$@"

install_part "$MODULE/emacs.sh"

parts_ok
