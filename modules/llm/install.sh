#!/usr/bin/env bash
# The local LLM stack: ollama, SearXNG, OpenCode desktop and the OpenCode server.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"
parse_module_args "$@"

# In dependency order: the OpenCode parts use models ollama serves.
install_part "$MODULE/ollama/ollama.sh"
install_part "$MODULE/searxng/searxng.sh"
install_part "$MODULE/opencode-desktop/opencode-desktop.sh"
install_part "$MODULE/opencode/opencode.sh"

parts_ok
