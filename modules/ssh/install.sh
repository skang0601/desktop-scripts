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

# ssh follows the symlink and judges the repo file's mode, refusing the whole
# config as "bad owner or permissions" if it is group- or world-writable. A
# umask of 002 checks the repo out 664, so this is the normal case, not the
# exception. git tracks only the exec bit, so this leaves no diff.
if [[ "$(stat -Lc %a "$HOME/.ssh/config")" != 644 ]]; then
  say "tightening $MODULE/config to 644 for ssh"
  run chmod 644 "$MODULE/config"
fi

# The agent socket is created by the 1Password desktop app when it is running
# and SSH agent support is enabled in its settings. It is not part of `op`.
AGENT_SOCK="$HOME/.1password/agent.sock"
FALLBACK_KEY="$HOME/.ssh/id_rsa"
if [[ -S "$AGENT_SOCK" ]]; then
  say "1Password agent socket present; keys it offers:"
  # Query the 1Password socket explicitly: $SSH_AUTH_SOCK usually points at
  # gnome-keyring, which holds nothing and would report an empty agent.
  dry || SSH_AUTH_SOCK="$AGENT_SOCK" ssh-add -l 2>&1 | sed 's/^/    /' || true
elif [[ -f "$FALLBACK_KEY" ]]; then
  say "no 1Password agent; falling back to $FALLBACK_KEY"
  # ssh rejects a private key any other user can read, and an exported key
  # commonly arrives 0644.
  if [[ "$(stat -c %a "$FALLBACK_KEY")" != 600 ]]; then
    say "tightening $FALLBACK_KEY to 600"
    run chmod 600 "$FALLBACK_KEY"
  fi
else
  warn "no agent socket at $AGENT_SOCK, and no key at $FALLBACK_KEY"
  warn "enable it in 1Password: Settings > Developer > Use the SSH agent"
fi
