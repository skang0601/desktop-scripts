APP_NAME=1password-cli

app_check() { have op; }

app_install() {
  # Not in Fedora's repos, and the Flathub listing is the desktop app only, so
  # the CLI comes from 1Password's own repo either way.
  add_1password_repo
  install_rpm 1password-cli
}
