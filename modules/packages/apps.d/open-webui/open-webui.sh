APP_NAME=open-webui

# Quadlet rather than a hand-written unit: podman generates the service from
# this file, so the container's lifecycle, image pull and cleanup are its
# concern rather than an ExecStartPre/ExecStopPost pair to keep correct.
QUADLET_SRC() { printf '%s/open-webui.container\n' "$APP_DIR"; }
QUADLET="$HOME/.config/containers/systemd/open-webui.container"

DATA="$HOME/.local/share/open-webui"

# ollama's installer records which model it chose; the quadlet reads this file
# with EnvironmentFile=, which is what gets it inside the container.
ROLES="$HOME/.local/share/ollama/roles.env"
ENVFILE="$DATA/model.env"

model() { awk -F= '/^OLLAMA_MODEL=/ { print $2; exit }' "$ROLES" 2>/dev/null; }

# One source of truth for the tag and the port: the quadlet file the unit is
# generated from. ai.localhost rather than 127.0.0.1 because systemd-resolved
# resolves the whole reserved .localhost TLD to loopback (RFC 6761), so the
# nicer name costs no configuration and nothing under /etc.
image() { awk -F= '/^Image=/ { print $2; exit }' "$(QUADLET_SRC)"; }
port()  { awk -F= '/^Environment=PORT=/ { print $3; exit }' "$(QUADLET_SRC)"; }
ui()    { printf 'http://ai.localhost:%s\n' "$(port)"; }

app_blocked() {
  if ! have podman; then
    echo "no podman, which the container this app ships needs"
    return 0
  fi
  return 1
}

unit_active() {
  [[ "$(systemctl --user is-active open-webui.service 2>/dev/null)" == active ]]
}

app_check() {
  [[ "$(readlink -f "$QUADLET" 2>/dev/null)" == "$(readlink -f "$(QUADLET_SRC)")" ]] \
    && [[ -n "$(model)" ]] \
    && grep -q "DEFAULT_MODELS=$(model)" "$ENVFILE" 2>/dev/null \
    && unit_active
}

# DEFAULT_MODELS seeds a persisted setting rather than pinning it, so a model
# picked in the UI later still wins. This only decides what a fresh install and
# a new chat start on.
write_envfile() {
  local model="$1"
  if dry; then
    printf '    [dry-run] write %s (DEFAULT_MODELS=%s)\n' "$ENVFILE" "$model"
    return 0
  fi
  printf 'DEFAULT_MODELS=%s\n' "$model" >"$ENVFILE"
}

app_install() {
  # ollama is what this is a front end for, and app order alone does not
  # guarantee it ran first.
  require_app ollama

  run mkdir -p "$DATA"
  link_config "$(QUADLET_SRC)" "$QUADLET"

  # Written unconditionally: EnvironmentFile is not optional to podman, and a
  # missing one fails the container start rather than defaulting.
  local chosen
  chosen="$(model)"
  [[ -n "$chosen" ]] || warn "no model in $ROLES; open-webui will have no default"
  write_envfile "$chosen"

  # The [Service] drop-in an earlier version wrote never reached the container.
  run rm -rf "$HOME/.config/systemd/user/open-webui.service.d"

  # Pulled here rather than left to the unit's first start, so the ~1.8GB
  # download shows progress instead of looking like a hung service.
  say "pulling $(image)"
  run podman pull "$(image)"

  # Quadlet units are generated, so they cannot be `systemctl enable`d; the
  # [Install] section in the .container file is what the generator acts on.
  run systemctl --user daemon-reload
  # restart, not start: app_install only runs when app_check already failed, and
  # `start` on a running unit is a no-op that would leave the old drop-in and
  # the old image in place while reporting success.
  run systemctl --user restart open-webui.service

  dry || say "open $(ui) -- the first account created becomes the admin"
}

app_checks() {
  have podman || return 0

  if [[ "$(readlink -f "$QUADLET" 2>/dev/null)" == "$(readlink -f "$(QUADLET_SRC)")" ]]; then
    check_ok "open-webui quadlet" "linked to the repo"
  else
    check_fail "open-webui quadlet" "$QUADLET is not linked to the repo" \
      "./modules/packages/install.sh open-webui"
  fi

  if grep -q "DEFAULT_MODELS=$(model)" "$ENVFILE" 2>/dev/null; then
    check_ok "open-webui model" "$(model)"
  else
    check_fail "open-webui model" "$ENVFILE does not name ollama's model" \
      "./modules/packages/install.sh open-webui"
  fi

  if unit_active; then
    check_ok "open-webui.service" "active"
  else
    check_fail "open-webui.service" "not active" \
      "systemctl --user start open-webui.service"
  fi

  # Bound to loopback deliberately; a listener on any other address means the
  # HOST= line stopped taking effect and the UI is reachable from the LAN.
  local listen
  listen="$(ss -Hltn "sport = :$(port)" 2>/dev/null | awk '{print $4}' | head -1)"
  if [[ -z "$listen" ]]; then
    check_warn "open-webui" "nothing listening on $(port)"
  elif [[ "$listen" == 127.0.0.1:* || "$listen" == "[::1]:"* ]]; then
    check_ok "open-webui" "$(ui)"
  else
    check_fail "open-webui" "listening on $listen, not loopback" \
      "./modules/packages/install.sh open-webui"
  fi
}
