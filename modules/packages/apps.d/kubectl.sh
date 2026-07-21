# shellcheck shell=bash
APP_NAME=kubectl

app_check() { have kubectl; }

app_install() {
  # Fedora names it for the role, brew for the project. The `k` alias and the
  # completion that follows it into the alias live in modules/shell.
  install_cli kubernetes-client kubernetes-cli
}
