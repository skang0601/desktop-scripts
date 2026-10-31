# State checks for the gnome module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

module_checks() {
  # shellcheck source=./common.sh
  source "$MODULE/common.sh"
  CHECK_GROUP=brightness brightness_checks
  CHECK_GROUP="login screen" login_screen_checks
}

brightness_checks() {
  local fix="./modules/gnome/install.sh"

  if [[ -d "$ASD_SRC/.git" ]]; then
    check_ok "asd-brightness checkout" "$ASD_SRC"
  else
    check_fail "asd-brightness checkout" "missing at $ASD_SRC" "$fix"
  fi

  local head built
  head="$(asd_head)"
  built="$(asd_built)"
  if [[ ! -x "$ASD_HELPER" ]]; then
    check_fail "extension build" "not installed at $ASD_EXT" "$fix"
  elif [[ -z "$built" ]]; then
    check_warn "extension build" "installed, but not by this module; source commit unknown" "$fix"
  elif [[ "$built" == "$head" ]]; then
    check_ok "extension build" "built from ${head:0:7}"
  else
    check_warn "extension build" "built from ${built:0:7}, checkout is at ${head:0:7}" "$fix"
  fi

  # The extension refuses to load when its metadata does not name the running
  # Shell, which is how it breaks on a GNOME major upgrade.
  local shell_major
  shell_major="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"
  if [[ -n "$shell_major" && -f "$ASD_EXT/metadata.json" ]]; then
    if grep -q "\"$shell_major\"" "$ASD_EXT/metadata.json"; then
      check_ok "Shell version" "metadata names GNOME $shell_major"
    else
      check_fail "Shell version" "metadata does not list GNOME $shell_major" \
        "add it to shell-version in $ASD_SRC/extension/metadata.json"
    fi
  fi

  if gnome-extensions info "$ASD_UUID" 2>/dev/null | grep -q 'State: ACTIVE'; then
    check_ok "GNOME extension" "enabled and active"
  elif [[ "$(gsettings get org.gnome.shell enabled-extensions)" == *"'$ASD_UUID'"* ]]; then
    # On Wayland the Shell scans for extensions only at login.
    check_warn "GNOME extension" "enabled but not loaded by this session" "log out and back in"
  else
    check_fail "GNOME extension" "not enabled" "$fix"
  fi

  [[ -x "$ASD_HELPER" ]] || return 0
  local out
  out="$("$ASD_HELPER" get 2>&1)" || true
  if [[ "$out" == '{"ok":true'* ]]; then
    local value="${out#*\"value\":}"
    check_ok "display" "reachable, brightness ${value%%,*}"
  elif [[ "$out" == *"not found"* ]]; then
    check_warn "display" "no Studio Display connected"
  else
    # Usually hidraw permissions: the display's nodes need uaccess.
    check_fail "display" "${out:-helper produced no output}" \
      "$ASD_SRC/install.sh --udev"
  fi
}

login_screen_checks() {
  local fix="./modules/gnome/install.sh"

  if [[ ! -f "$GDM_SRC" ]]; then
    check_warn "session layout" "$GDM_SRC missing; no saved display layout to copy"
  elif [[ ! -f "$GDM_DEST" ]]; then
    check_fail "display layout" "$GDM_DEST missing; login screen guesses its own scale" "$fix"
  elif cmp -s "$GDM_SRC" "$GDM_DEST"; then
    check_ok "display layout" "$GDM_DEST matches $GDM_SRC"
  else
    # Settings > Displays rewrites the user's copy on every change.
    check_warn "display layout" "$GDM_DEST differs from $GDM_SRC" "$fix"
  fi
}
