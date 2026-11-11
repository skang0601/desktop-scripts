# State checks for the llm module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

module_checks() {
  check_part "$MODULE/ollama/ollama.sh"
  check_part "$MODULE/searxng/searxng.sh"
  check_part "$MODULE/opencode-desktop/opencode-desktop.sh"
  check_part "$MODULE/opencode/opencode.sh"
}
