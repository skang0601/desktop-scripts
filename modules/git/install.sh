#!/usr/bin/env bash
# Global git config.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"

parse_module_args "$@"

have git || warn "git is not installed; the packages module installs it"

say "linking ~/.gitconfig"
# Symlinked rather than copied so `git config --global` edits the tracked file.
link_config "$MODULE/gitconfig" "$HOME/.gitconfig"

# ~/.config/git/config wins over ~/.gitconfig, so a stray one here would
# silently override everything above.
if [[ -e "$HOME/.config/git/config" ]]; then
  warn "$HOME/.config/git/config exists and takes precedence over ~/.gitconfig"
fi

dry || {
  echo
  echo "identity in effect:"
  printf '  user.name  %s\n' "$(git config --global user.name || echo '(unset)')"
  printf '  user.email %s\n' "$(git config --global user.email || echo '(unset)')"
}
