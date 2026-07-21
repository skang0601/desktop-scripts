# shellcheck shell=bash
APP_NAME=searxng

# Reported together in doctor's grouped output: one local-LLM stack rather than
# three apps scattered through an alphabetical list.
APP_GROUP="local llm"

QUADLET_SRC() { printf '%s/searxng.container\n' "$APP_DIR"; }
SETTINGS_SRC() { printf '%s/settings.yml\n' "$APP_DIR"; }

QUADLET="$HOME/.config/containers/systemd/searxng.container"
DATA="$HOME/.local/share/searxng"
SETTINGS="$DATA/settings.yml"
SECRET="$DATA/secret.env"
API=http://127.0.0.1:8888

app_blocked() {
  if ! have podman; then
    echo "no podman, which the container this app ships needs"
    return 0
  fi
  return 1
}

unit_active() {
  [[ "$(systemctl --user is-active searxng.service 2>/dev/null)" == active ]]
}

# Asserted by app_check, not just reported, so that editing the quadlet is
# enough to get the change applied. The symlink path and the settings file both
# stay identical when only the .container's contents change, and systemd will
# happily keep running a unit generated from the old one; the bound address is
# the observable that actually says which version is live.
listening_on_loopback() {
  local listen
  listen="$(ss -Hltn 'sport = :8888' 2>/dev/null | awk '{print $4}' | head -1)"
  [[ -n "$listen" ]] && [[ "$listen" == 127.0.0.1:* || "$listen" == "[::1]:"* ]]
}

app_check() {
  [[ "$(readlink -f "$QUADLET" 2>/dev/null)" == "$(readlink -f "$(QUADLET_SRC)")" ]] \
    && cmp -s "$(SETTINGS_SRC)" "$SETTINGS" \
    && [[ -s "$SECRET" ]] \
    && unit_active \
    && listening_on_loopback
}

# Copied rather than symlinked: the container sees this path through a bind
# mount, where a symlink pointing into the repo dangles. cmp in app_check is
# what notices the repo's copy changing.
install_settings() {
  if dry; then
    printf '    [dry-run] install -m644 %s %s\n' "$(SETTINGS_SRC)" "$SETTINGS"
    return 0
  fi
  install -m644 "$(SETTINGS_SRC)" "$SETTINGS"
}

# Written once and kept. Regenerating it on every run would invalidate any
# session the running instance holds, and there is no reason to roll it.
write_secret() {
  if [[ -s "$SECRET" ]]; then
    skip "searxng secret" "already generated"
    return 0
  fi
  if dry; then
    printf '    [dry-run] write %s (generated SEARXNG_SECRET)\n' "$SECRET"
    return 0
  fi
  ( umask 077
    printf 'SEARXNG_SECRET=%s\n' "$(openssl rand -hex 32)" >"$SECRET" )
}

app_install() {
  run mkdir -p "$DATA"
  link_config "$(QUADLET_SRC)" "$QUADLET"
  install_settings
  write_secret

  say "pulling searxng"
  run podman pull "$(awk -F= '/^Image=/ { print $2; exit }' "$(QUADLET_SRC)")"

  run systemctl --user daemon-reload
  # restart, not start: app_install only runs when app_check already failed, so
  # a changed settings.yml has to reach a container that may be running.
  run systemctl --user restart searxng.service

  dry || wait_for_json || warn "searxng did not answer JSON on $API"
}

# Stock SearXNG answers 403 to format=json, so a successful JSON response is
# what proves the settings override reached the container.
wait_for_json() {
  local i
  for i in $(seq 1 30); do
    if curl -fsS "$API/search?q=test&format=json" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

app_checks() {
  have podman || return 0

  if [[ "$(readlink -f "$QUADLET" 2>/dev/null)" == "$(readlink -f "$(QUADLET_SRC)")" ]]; then
    check_ok "searxng quadlet" "linked to the repo"
  else
    check_fail "searxng quadlet" "$QUADLET is not linked to the repo" \
      "./modules/packages/install.sh searxng"
  fi

  if cmp -s "$(SETTINGS_SRC)" "$SETTINGS"; then
    check_ok "searxng settings" "matches the repo"
  else
    check_fail "searxng settings" "$SETTINGS differs from the repo" \
      "./modules/packages/install.sh searxng"
  fi

  if unit_active; then
    check_ok "searxng.service" "active"
  else
    check_fail "searxng.service" "not active" "systemctl --user start searxng.service"
  fi

  local listen
  listen="$(ss -Hltn 'sport = :8888' 2>/dev/null | awk '{print $4}' | head -1)"
  if [[ -z "$listen" ]]; then
    check_warn "searxng" "nothing listening on 8888"
  elif ! listening_on_loopback; then
    check_fail "searxng" "listening on $listen, not loopback" \
      "./modules/packages/install.sh searxng"
  elif curl -fsS "$API/search?q=test&format=json" >/dev/null 2>&1; then
    check_ok "searxng json api" "$API"
  else
    check_fail "searxng json api" "403 or no answer; formats: json missing" \
      "./modules/packages/install.sh searxng"
  fi
}