#!/usr/bin/env bash
# Tailscale, and the OpenCode server served on this machine's tailnet address.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"
# shellcheck source=lib.sh
source "$MODULE/lib.sh"

for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    *) warn "unknown option: $a"; exit 2 ;;
  esac
done

dry && say "dry run -- nothing will be changed"

# Bazzite ships tailscale in the image. Anywhere else it is one package from
# Tailscale's own repo, which is not this module's to add.
if ! have tailscale; then
  warn "tailscale is not installed; see https://tailscale.com/download/linux"
  exit 1
fi

if ! systemctl is-enabled --quiet tailscaled || ! systemctl is-active --quiet tailscaled; then
  say "enabling tailscaled"
  run sudo systemctl enable --now tailscaled
fi

# `tailscale up` prints a login URL and blocks until it is visited, so a first
# run needs someone at the browser.
if dry; then
  printf '    [dry-run] sudo tailscale up   (if not logged in)\n'
elif [[ "$(backend_state)" != Running ]]; then
  say "logging in to Tailscale -- open the URL it prints"
  sudo tailscale up
fi

# Served rather than bound: the OpenCode server stays on 127.0.0.1, and
# tailscaled terminates HTTPS on the tailnet address and proxies to it, so it
# is reachable from the tailnet and still not from the LAN. The server's own
# password still applies: the tailnet decides who can connect, and the
# password decides who gets a shell on this machine. The first serve on a
# tailnet asks for HTTPS certificates to be enabled in the admin console and
# prints the link.
if serving_opencode; then
  skip "tailscale serve" "already proxying to $OPENCODE_TARGET"
else
  say "serving OpenCode at https://<this machine>.<tailnet>.ts.net"
  run sudo tailscale serve --bg --https=443 "$OPENCODE_TARGET"
fi

dry || say "OpenCode: https://$(magic_dns_name)/ (user opencode, password in ~/.config/opencode-server/env)"
