# Install strategies for the packages module.
# shellcheck shell=bash

# CLI/dev tooling. Homebrew first: it is user-level, needs no reboot, and avoids
# layering entirely on atomic systems (ADR 0004/0005). Bazzite ships brew.
install_cli() {
  local pkg="$1" brew_pkg="${2:-$1}"

  if have brew; then
    run brew install "$brew_pkg"
  elif is_atomic; then
    warn "no brew; layering $pkg (needs a reboot before it is usable)"
    run sudo rpm-ostree install "$pkg"
    # Apps run in subshells, so a variable cannot signal the parent.
    : > "$LAYERED_MARKER"
  else
    run sudo dnf install -y "$pkg"
  fi
}

# GUI apps. Flathub is preconfigured on Bazzite; on other systems it may not be.
install_flatpak() {
  local id="$1"
  if ! have flatpak; then
    warn "flatpak not available; skipping $id"
    return 1
  fi
  if ! flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
    run flatpak remote-add --if-not-exists --user \
      flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
  run flatpak install -y --user flathub "$id"
}

flatpak_installed() {
  flatpak info "$1" >/dev/null 2>&1
}

# Install another app.d entry on demand. apps.d runs in filename order, so an
# app that depends on another cannot rely on ordering alone.
require_app() {
  local name="$1"
  ( source "$MODULE/apps.d/$name.sh"
    app_check || { say "installing dependency $APP_NAME"; app_install; } )
}
