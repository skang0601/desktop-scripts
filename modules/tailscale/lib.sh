# Shared by install.sh and checks.sh.
# shellcheck shell=bash

# The port is read from the quadlet, the one place the OpenCode server's host
# address is set: the host side of PublishPort=127.0.0.1:<host>:<container>.
OPENCODE_PORT="$(awk -F: '/^PublishPort=/ { print $2; exit }' \
  "$MODULE/../llm/opencode/opencode.container")"
OPENCODE_TARGET="http://127.0.0.1:$OPENCODE_PORT"

ts_status_field() {
  tailscale status --json 2>/dev/null | python3 -I -c "
import json, sys
try: d = json.load(sys.stdin)
except ValueError: sys.exit(1)
print($1)" 2>/dev/null
}

backend_state()  { ts_status_field 'd.get("BackendState", "")'; }
magic_dns_name() { ts_status_field '(d.get("Self") or {}).get("DNSName", "").rstrip(".")'; }

serving_opencode() {
  tailscale serve status --json 2>/dev/null | python3 -I -c "
import json, sys
try: d = json.load(sys.stdin)
except ValueError: sys.exit(1)
for host, web in (d.get('Web') or {}).items():
    if host.endswith(':443') and (web.get('Handlers') or {}).get('/', {}).get('Proxy') == sys.argv[1]:
        sys.exit(0)
sys.exit(1)" "$OPENCODE_TARGET"
}
