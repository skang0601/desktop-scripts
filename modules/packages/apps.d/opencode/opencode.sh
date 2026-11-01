# shellcheck shell=bash
APP_NAME=opencode

APP_GROUP="local llm"

# A standing OpenCode server for the phone, reached over the tailnet. The
# desktop app's own server is no use for that -- it listens on a random port,
# and only while the app is open -- and it runs with everything this user can
# reach. This one runs in a rootless container that sees one directory, its
# own config and sessions, and ollama.
QUADLET_SRC() { printf '%s/opencode.container\n' "$APP_DIR"; }
QUADLET="$HOME/.config/containers/systemd/opencode.container"
CONFIG_SRC() { printf '%s/sandbox/opencode.json\n' "$APP_DIR"; }
CONFIG_DIR="$HOME/.local/share/opencode-sandbox-config"
DATA="$HOME/.local/share/opencode-sandbox"
WORKSPACE="$HOME/Workspace/phone"
ENVFILE="$HOME/.config/opencode-server/env"
PORT=4096

image() { awk -F= '/^Image=/ { print $2; exit }' "$(QUADLET_SRC)"; }

app_blocked() {
  have podman && return 1
  echo "no podman, which the sandbox container needs"
  return 0
}

unit_active() { [[ "$(systemctl --user is-active opencode.service 2>/dev/null)" == active ]]; }

# Without the password this is a shell in the workspace for anything that can
# reach the port, so an unauthenticated request must be refused. Probed under
# /api: the web app's static shell at / is served to anyone and holds no data,
# while every API route requires the password.
auth_enforced() {
  [[ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/api/session" 2>/dev/null)" == 401 ]]
}

# Copied rather than linked: a symlink into the repo would have to be resolved
# inside the container, which cannot see the repo.
config_current() { cmp -s "$(CONFIG_SRC)" "$CONFIG_DIR/opencode.json"; }

app_check() {
  [[ "$(readlink -f "$QUADLET" 2>/dev/null)" == "$(readlink -f "$(QUADLET_SRC)")" ]] \
    && config_current \
    && [[ -s "$ENVFILE" ]] \
    && unit_active \
    && auth_enforced
}

write_envfile() {
  [[ -s "$ENVFILE" ]] && return 0
  if dry; then
    printf '    [dry-run] write %s (generated OPENCODE_SERVER_PASSWORD, mode 600)\n' "$ENVFILE"
    return 0
  fi
  mkdir -p "$(dirname "$ENVFILE")"
  (umask 077; printf 'OPENCODE_SERVER_PASSWORD=%s\n' \
    "$(python3 -I -c 'import secrets; print(secrets.token_urlsafe(24))')" >"$ENVFILE")
}

app_install() {
  # The models the sandbox config names: qwen3.8 from ollama's tier table, the
  # Devstral alias from opencode-desktop.
  require_app ollama
  require_app opencode-desktop

  run mkdir -p "$WORKSPACE" "$DATA" "$CONFIG_DIR"
  run install -m 644 "$(CONFIG_SRC)" "$CONFIG_DIR/opencode.json"
  write_envfile
  link_config "$(QUADLET_SRC)" "$QUADLET"

  say "pulling $(image)"
  run podman pull "$(image)"

  # Quadlet units are generated and cannot be enabled; [Install] in the
  # .container is what the generator acts on. restart rather than start, so a
  # changed quadlet or password reaches the running container.
  run systemctl --user daemon-reload
  run systemctl --user restart opencode.service

  dry || say "workspace: $WORKSPACE; password: $ENVFILE (user: opencode)"
}

app_checks() {
  have podman || return 0

  check_symlink "opencode quadlet" "$QUADLET" "$(QUADLET_SRC)" "./modules/packages/install.sh opencode"

  if config_current; then
    check_ok "opencode sandbox config" "local models only"
  else
    check_fail "opencode sandbox config" "$CONFIG_DIR/opencode.json differs from the repo" \
      "./modules/packages/install.sh opencode"
  fi

  if unit_active; then
    check_ok "opencode.service" "127.0.0.1:$PORT, sandboxed to $WORKSPACE"
  else
    check_fail "opencode.service" "not active" "systemctl --user restart opencode.service"
    return 0
  fi

  if auth_enforced; then
    check_ok "opencode auth" "unauthenticated requests refused"
  else
    check_fail "opencode auth" "127.0.0.1:$PORT answers without a password" \
      "./modules/packages/install.sh opencode"
  fi
}
