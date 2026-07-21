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

# op and the desktop app have to come from the same install. The app integration
# refuses a CLI it cannot match to the running app -- a brew op against a
# container app, or the reverse, fails with "connecting to desktop app".
app_check() { have 1password && have op; }

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