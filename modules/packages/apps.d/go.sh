# shellcheck shell=bash
APP_NAME=go

app_check() { have go; }

app_install() {
  # Fedora calls it golang, brew calls it go.
  install_cli golang go
}