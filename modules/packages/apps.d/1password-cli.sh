APP_NAME=1password-cli

app_check() { have op; }

app_install() {
  # Not in Fedora's repos, and the Flathub listing is the desktop app only, so
  # the CLI comes from 1Password's own repo either way.
  add_1password_repo
  if is_atomic; then
    warn "layering 1password-cli (needs a reboot before it is usable)"
    run sudo rpm-ostree install 1password-cli
    : > "$LAYERED_MARKER"
  else
    run sudo dnf install -y 1password-cli
  fi
}
