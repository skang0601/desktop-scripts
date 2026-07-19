#!/usr/bin/env bash
# SSH client config.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"

for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    *) warn "unknown option: $a"; exit 2 ;;
  esac
done

dry && say "dry run -- nothing will be changed"

# ssh refuses to use a config directory others can write to.
say "ensuring ~/.ssh exists with 700"
run mkdir -p "$HOME/.ssh"
run chmod 700 "$HOME/.ssh"

say "linking ~/.ssh/config"
link_config "$MODULE/config" "$HOME/.ssh/config"

# The agent socket is created by the 1Password desktop app when it is running
# and SSH agent support is enabled in its settings. It is not part of `op`.
AGENT_SOCK="$HOME/.1password/agent.sock"
if [[ -S "$AGENT_SOCK" ]]; then
  say "1Password agent socket present; keys it offers:"
  # Query the 1Password socket explicitly: $SSH_AUTH_SOCK usually points at
  # gnome-keyring, which holds nothing and would report an empty agent.
  dry || SSH_AUTH_SOCK="$AGENT_SOCK" ssh-add -l 2>&1 | sed 's/^/    /' || true
else
  warn "no agent socket at $AGENT_SOCK"
  warn "enable it in 1Password: Settings > Developer > Use the SSH agent"
fi
