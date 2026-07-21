# shellcheck shell=bash
APP_NAME=1password

# The desktop app's value here is the SSH agent socket at ~/.1password/agent.sock,
# which the ssh module points IdentityAgent at. Everything below follows from
# needing that socket to appear on the host.
AGENT_SOCK="$HOME/.1password/agent.sock"

# ublue-os package 1Password's own Linux tarball from downloads.1password.com
# rather than rebuilding it, so this is the vendor's binary by a different route
# (ADR 0005). The two alternatives both fail on an atomic system: the rpm's
# %post aborts under rpm-ostree, and the Flatpak has no --filesystem=home, so
# its agent socket is created inside a redirected $HOME and never reaches the
# ssh module.
GUI_CASK="$UBLUE_TAP/1password-gui-linux"
CLI_CASK="$UBLUE_TAP/1password-cli-linux"

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

# The Exec target, which is the part that goes wrong. Empty when the entry is
# absent or its first token no longer resolves to something executable.
autostart_exec() {
  local exec_line target
  [[ -f "$AUTOSTART" ]] || return 1
  exec_line="$(sed -n 's/^Exec=//p' "$AUTOSTART" | head -1)"
  target="${exec_line%% *}"
  [[ -x "$target" ]] || return 1
  printf '%s\n' "$target"
}

autostart_ok() { ! wants_autostart || autostart_exec >/dev/null; }

# op and the desktop app have to come from the same install. The app integration
# refuses a CLI it cannot match to the running app -- a brew op against a
# container app, or the reverse, fails with "connecting to desktop app".
app_check() { have 1password && have op && autostart_ok; }

app_install() {
  if ! have brew; then
    # No brew means a traditional system, where the rpm installs cleanly.
    add_1password_repo
    have op || install_rpm 1password-cli
    have 1password || install_rpm 1password
    return 0
  fi

  # Trusting the tap lets brew run its Ruby, and these casks use sudo: they
  # install a polkit policy to /etc/polkit-1/actions, create the onepassword
  # group, and set the setgid bit on 1Password-BrowserSupport and setuid on
  # chrome-sandbox. That is more than a user-level install, and it is why the
  # tap is named at each point of use rather than trusted blanket-wise.
  say "trusting $UBLUE_TAP; its casks run sudo for the polkit policy and setuid bits"
  brew_tap_trusted "$UBLUE_TAP"

  # Prompts for sudo, for the polkit policy and setuid bits above.
  have 1password || run brew install --cask "$GUI_CASK"
  have op || run brew install --cask "$CLI_CASK"

  say "sign in, then enable Settings -> Developer -> 'Use the SSH agent'"
  say "and 'Integrate with 1Password CLI' for op"

  install_autostart
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

# 1Password's own RPM repo, for systems without brew. Neither the desktop app
# nor `op` is in Fedora's repos.
#
# gpgkey is written unquoted, unlike 1Password's own snippet: rpm-ostree has
# been reported to fail with "Signing key not found" on the quoted form
# (fedora-silverblue/issue-tracker#658).
add_1password_repo() {
  [[ -f /etc/yum.repos.d/1password.repo ]] && return 0

  run sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
  if dry; then
    printf '    [dry-run] write /etc/yum.repos.d/1password.repo\n'
  else
    printf '%s\n' \
      '[1password]' \
      'name="1Password Stable Channel"' \
      'baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch' \
      'enabled=1' \
      'gpgcheck=1' \
      'gpgkey=https://downloads.1password.com/linux/keys/1password.asc' |
      sudo install -Dm644 /dev/stdin /etc/yum.repos.d/1password.repo
  fi
}

app_checks() {
  if have 1password; then
    check_ok "1password app" "$(command -v 1password)"
  else
    check_warn "1password app" "not installed" "./modules/packages/install.sh 1password"
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
      "./modules/packages/install.sh 1password"
  else
    check_warn "1password autostart" \
      "'Start at login' is on, but no autostart entry implements it" \
      "./modules/packages/install.sh 1password"
  fi

  # The socket is the point of the whole entry, and it is absent whenever the
  # app is closed or the SSH agent setting was never turned on -- neither of
  # which the installer can do anything about.
  if [[ -S "$AGENT_SOCK" ]]; then
    check_ok "1password ssh agent" "$AGENT_SOCK"
  else
    check_warn "1password ssh agent" "no socket; app closed or agent not enabled" \
      "open 1Password, then Settings -> Developer -> 'Use the SSH agent'"
  fi

  local op_path
  op_path="$(command -v op || true)"
  if [[ -z "$op_path" ]]; then
    check_warn "op cli" "not on PATH" "./modules/packages/install.sh 1password"
  elif [[ "$op_path" == "$HOME/.local/bin/"* ]]; then
    # A distrobox-exported wrapper left over from running the app in a
    # container. op and the app have to be the same side of the container
    # boundary, so this cannot reach an app installed on the host.
    check_warn "op cli" "$op_path is a container wrapper; it cannot reach the host app" \
      "rm $op_path && ./modules/packages/install.sh 1password"
  elif rpm -q 1password-cli >/dev/null 2>&1; then
    # Works against the brew app -- both are on the host, which is all the app
    # integration requires. Layered rather than brewed is untidy against the
    # ranking above, not broken, so it is not a warning.
    check_ok "op cli" "$op_path (layered rpm; the $CLI_CASK cask would unlayer it)"
  else
    check_ok "op cli" "$op_path"
  fi

  # op-ssh-sign ships with the app rather than the CLI, and the git module's
  # signing block resolves it through PATH.
  if have op-ssh-sign; then
    check_ok "op-ssh-sign" "$(command -v op-ssh-sign)"
  else
    check_warn "op-ssh-sign" "absent; git ssh commit signing would fail" \
      "./modules/packages/install.sh 1password"
  fi
}