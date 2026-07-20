# State checks for the keybindings module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

module_checks() {
  have keyd || { check_fail "keyd" "not installed" "./modules/keybindings/install.sh"; return 0; }
  check_ok "keyd" "$(keyd --version 2>&1 | head -1)"

  check_service_active "keyd.service" keyd "sudo systemctl enable --now keyd"
  check_no_recent_crash "keyd stability" keyd

  check_installed_matches "keyd restart drop-in" \
    "$MODULE/keyd-restart.conf" /etc/systemd/system/keyd.service.d/restart.conf \
    "./modules/keybindings/install.sh"

  # The file being in place is not the same as systemd having read it, and the
  # difference decides whether a segfault leaves the keyboard unmapped.
  local policy
  policy="$(systemctl show keyd -p Restart --value 2>/dev/null)"
  if [[ "$policy" == always ]]; then
    check_ok "keyd restart policy" "Restart=always"
  else
    check_fail "keyd restart policy" "Restart=$policy; a crash stays down" \
      "sudo systemctl daemon-reload"
  fi

  check_installed_matches "default.conf" \
    "$MODULE/default.conf" /etc/keyd/default.conf \
    "./modules/keybindings/install.sh"

  check_installed_matches "libinput quirk" \
    "$MODULE/local-overrides.quirks" /etc/libinput/local-overrides.quirks \
    "./modules/keybindings/install.sh"

  # keyd exits 0 on an unknown key or action and only warns, so a whole layer
  # can be silently dropped from a config that "passes".
  local out
  out="$(keyd check "$MODULE/default.conf" 2>&1 || true)"
  if grep -q WARNING <<<"$out"; then
    check_fail "config validity" "keyd check reports warnings" "keyd check $MODULE/default.conf"
  else
    check_ok "config validity" "keyd check is clean"
  fi

  # --- Layer 3: per-application remapping ------------------------------------

  check_installed_matches "app.conf" \
    "$MODULE/app.conf" "$HOME/.config/keyd/app.conf" \
    "./modules/keybindings/install.sh"

  check_in_group "keyd group" keyd "./modules/keybindings/install.sh"

  # The mapper's only failure mode in practice: it starts, runs, and cannot open
  # the socket, logging an error per focus change while appearing healthy.
  if [[ -S /run/keyd.socket ]]; then
    if [[ -r /run/keyd.socket ]]; then
      check_ok "keyd socket" "readable"
    else
      check_fail "keyd socket" "/run/keyd.socket not readable by $USER" \
        "./modules/keybindings/install.sh, then log out and back in"
    fi
  else
    check_fail "keyd socket" "/run/keyd.socket is missing" "sudo systemctl restart keyd"
  fi

  if pgrep -f keyd-application-mapper >/dev/null 2>&1; then
    check_ok "application mapper" "running"
  else
    check_warn "application mapper" "not running" \
      "the GNOME extension spawns it; check it is enabled"
  fi

  # app.log is append-only and its lines carry no timestamps, so counting every
  # ERROR ever written turns one outage into a permanent failure -- keyd being
  # down for a minute leaves dozens of "failed to connect" lines that no later
  # success erases. Only the tail is read, and it is a warning rather than a
  # failure: these lines are a record that something went wrong, not evidence
  # that anything is wrong now. The live checks above answer that.
  local log="$HOME/.config/keyd/app.log" errors
  if [[ -f "$log" ]]; then
    errors="$(tail -n 40 "$log" 2>/dev/null | grep -c ERROR || true)"
    if (( errors > 0 )); then
      check_warn "mapper log" "$errors error line(s) in the last 40" \
        "tail $log; : > $log to reset once keyd is healthy"
    else
      check_ok "mapper log" "no recent errors"
    fi
  fi

  local uuid=keyd@keyd.rvaiya.github.com
  local ext="$HOME/.local/share/gnome-shell/extensions/$uuid"
  if ! have gnome-extensions; then
    check_warn "GNOME extension" "gnome-extensions not available"
  elif ! gnome-extensions info "$uuid" >/dev/null 2>&1; then
    check_fail "GNOME extension" "not installed" "run keyd-application-mapper once"
  elif gnome-extensions info "$uuid" 2>/dev/null | grep -q 'State: ACTIVE'; then
    check_ok "GNOME extension" "enabled and active"
  else
    check_fail "GNOME extension" "installed but not active" "gnome-extensions enable $uuid"
  fi

  # The extension refuses to load when its metadata does not name the running
  # Shell, which is how a working setup breaks on a GNOME major upgrade.
  local shell_major
  shell_major="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"
  if [[ -n "$shell_major" && -f "$ext/metadata.json" ]]; then
    if grep -q "\"$shell_major\"" "$ext/metadata.json"; then
      check_ok "extension/Shell match" "declares GNOME $shell_major"
    else
      check_fail "extension/Shell match" "does not declare GNOME $shell_major" \
        "add it to $ext/metadata.json"
    fi
  fi

  # --- Layer 2: the GNOME shortcuts the keyd layers collide with -------------

  check_dconf "app grid key" org.gnome.shell.keybindings \
    toggle-application-view "['<Shift><Super>space']"
  check_dconf "overview key" org.gnome.shell.keybindings \
    toggle-overview "['<Super>space']"
  check_dconf_unset "gtk-key-theme" /org/gnome/desktop/interface/gtk-key-theme

  check_dconf "input-source key" org.gnome.desktop.wm.keybindings \
    switch-input-source "@as []"

  # Bare-Ctrl accelerators here would swallow the keys app.conf hands back to
  # the shell, so the check is that no override exists at all.
  local k
  for k in select-all search new-tab new-window; do
    check_dconf_unset "Ptyxis $k" "/org/gnome/Ptyxis/Shortcuts/$k"
  done
}
