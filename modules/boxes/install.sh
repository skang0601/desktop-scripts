#!/usr/bin/env bash
# distroboxes: a Fedora dev toolbox and the Ubuntu box for claude-desktop.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"
# shellcheck source=lib.sh
source "$MODULE/lib.sh"
parse_module_args "$@"

install_part "$MODULE/dev-box/dev-box.sh"
install_part "$MODULE/claude-desktop.sh"

parts_ok
