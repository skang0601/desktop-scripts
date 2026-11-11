# shellcheck shell=bash
APP_NAME=1password

# The desktop app's value here is the SSH agent socket at ~/.1password/agent.sock,
# which ./config points IdentityAgent at. Everything below follows from needing
# that socket to appear on the host.

# The app and op are the ublue-os casks in ../packages/Brewfile: 1Password's own Linux
# tarball, repackaged (ADR 0005). The two alternatives both fail on an atomic
# system: the rpm's %post aborts under rpm-ostree, and the Flatpak has no
# --filesystem=home, so its agent socket is created inside a redirected $HOME
# and never reaches the ssh module.

# 1Password writes this file itself when "Start at login" is on, and hardcodes
# Exec=/opt/1Password/1password -- where its own .deb and .rpm install. The cask
# puts the binary under brew's prefix, so the entry the app writes points at
# nothing. GNOME's exec fails silently at login, and the first symptom is ssh
# falling back to a key file because agent.sock has no daemon behind it.
AUTOSTART="$HOME/.config/autostart/1password.desktop"

# The app's own setting decides whether it should start at login; the .desktop
# file is only how that gets implemented. An unreadable settings file counts as
# yes, since the agent socket exists only while the app runs.
wants_autostart() {
  local settings="$HOME/.config/1Password/settings/settings.json"
  [[ -f "$settings" ]] || return 0
  python3 -c 'import json,sys
sys.exit(0 if json.load(open(sys.argv[1])).get("app.startAtLogin", True) else 1)' \
    "$settings" 2>/dev/null
}

# The entry's Exec target, or nonzero if the file is absent or its target no
# longer resolves to something executable -- which is the failure this repairs.
autostart_exec() {
  local exec_line target
  [[ -f "$AUTOSTART" ]] || return 1
  exec_line="$(sed -n 's/^Exec=//p' "$AUTOSTART" | head -1)"
  target="${exec_line%% *}"
  [[ -x "$target" ]] || return 1
  printf '%s\n' "$target"
}

autostart_ok() { ! wants_autostart || autostart_exec >/dev/null; }

app_check() { have 1password && have op && autostart_ok; }

app_install() {
  if ! have 1password || ! have op; then
    warn "1password or op is missing; both come from the Brewfile, which install.sh applies first"
    return 1
  fi

  install_autostart

  say "sign in, then enable Settings -> Developer -> 'Use the SSH agent'"
  say "and 'Integrate with 1Password CLI' for op"
}

# Rewritten by the app whenever "Start at login" is toggled, so this repairs
# rather than owns it: re-running the installer is the fix after that happens.
install_autostart() {
  wants_autostart || return 0
  autostart_exec >/dev/null && return 0

  local bin
  bin="$(command -v 1password)" || { warn "no 1password binary to point autostart at"; return 1; }

  say "pointing the autostart entry at $bin"
  if dry; then
    printf '    [dry-run] write %s with Exec=%s --silent\n' "$AUTOSTART" "$bin"
    return 0
  fi

  mkdir -p "$(dirname "$AUTOSTART")"
  # --silent starts it to the tray, which is what a login start is for.
  cat >"$AUTOSTART" <<EOF
[Desktop Entry]
Name=1Password
Exec=$bin --silent
Terminal=false
Type=Application
Icon=1password
StartupWMClass=1Password
Comment=Password manager and secure wallet
MimeType=x-scheme-handler/onepassword;x-scheme-handler/onepassword8;
Categories=Office;
X-GNOME-Autostart-enabled=true
EOF
}

app_checks() {
  if have 1password; then
    check_ok "1password app" "$(command -v 1password)"
  else
    check_warn "1password app" "not installed" "./modules/ssh/install.sh"
  fi

  # Checked separately from the socket because it is the cause the socket's
  # absence does not name: the app not running at all, every login, silently.
  local target
  if ! wants_autostart; then
    check_ok "1password autostart" "off in the app's settings"
  elif target="$(autostart_exec)"; then
    check_ok "1password autostart" "$target"
  elif [[ -f "$AUTOSTART" ]]; then
    check_warn "1password autostart" \
      "$AUTOSTART points at a binary that is not there" \
      "./modules/ssh/install.sh"
  else
    check_warn "1password autostart" \
      "'Start at login' is on, but no autostart entry implements it" \
      "./modules/ssh/install.sh"
  fi

  local op_path
  op_path="$(command -v op || true)"
  if [[ -z "$op_path" ]]; then
    check_warn "op cli" "not on PATH" "./modules/ssh/install.sh"
  elif [[ "$op_path" == "$HOME/.local/bin/"* ]]; then
    # A distrobox-exported wrapper left over from running the app in a
    # container. op and the app have to be the same side of the container
    # boundary, so this cannot reach an app installed on the host.
    check_warn "op cli" "$op_path is a container wrapper; it cannot reach the host app" \
      "rm $op_path && ./modules/ssh/install.sh"
  else
    check_ok "op cli" "$op_path"
  fi

  # op-ssh-sign ships with the app rather than the CLI, and the git module's
  # signing block resolves it through PATH.
  if have op-ssh-sign; then
    check_ok "op-ssh-sign" "$(command -v op-ssh-sign)"
  else
    check_warn "op-ssh-sign" "absent; git ssh commit signing would fail" \
      "./modules/ssh/install.sh"
  fi
}