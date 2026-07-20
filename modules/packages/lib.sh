# Install strategies for the packages module.
# shellcheck shell=bash

# app_install calls `blocked` to mean "this cannot be installed here, the
# reason is known, and re-running will not change it" -- an upstream bug, an
# unsupported platform. The summary keeps these apart from failures so a
# standing block doesn't read as a fresh error on every run, and doesn't fail
# the module's exit status.
BLOCKED=79
blocked() { warn "$*"; exit "$BLOCKED"; }

# CLI/dev tooling. Homebrew first: it is user-level, needs no reboot, and avoids
# layering entirely on atomic systems (ADR 0004/0005). Bazzite ships brew.
install_cli() {
  local pkg="$1" brew_pkg="${2:-$1}"

  if have brew; then
    run brew install "$brew_pkg"
  else
    warn "no brew; falling back to the distro package"
    install_rpm "$pkg"
  fi
}

# Distro package, skipping brew entirely. For anything brew builds wrong for
# this desktop: brew's Linux bottles are headless, so a package that has to
# draw a window comes from the distro even though on atomic systems that means
# layering and a reboot.
install_rpm() {
  local pkg="$1"

  if is_atomic; then
    warn "layering $pkg (needs a reboot before it is usable)"
    run sudo rpm-ostree install "$pkg"
    # Apps run in subshells, so a variable cannot signal the parent. Reached
    # only on success: install.sh runs each app under `set -e`.
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

# An app is a bare apps.d/<name>.sh, or apps.d/<name>/<name>.sh when it carries
# files of its own. Both forms are one app with one APP_NAME; the directory
# exists so config the app installs can sit beside the script that installs it
# rather than elsewhere in the module.
app_path() {
  local name="$1"
  if [[ -f "$MODULE/apps.d/$name.sh" ]]; then
    printf '%s\n' "$MODULE/apps.d/$name.sh"
  elif [[ -f "$MODULE/apps.d/$name/$name.sh" ]]; then
    printf '%s\n' "$MODULE/apps.d/$name/$name.sh"
  else
    return 1
  fi
}

# Every app exactly once, in the order they run. A directory without a matching
# script is not an app -- it is someone's leftover -- so it is skipped rather
# than reported as broken.
app_names() {
  local f name
  {
    for f in "$MODULE"/apps.d/*.sh; do
      [[ -f "$f" ]] && basename "$f" .sh
    done
    for f in "$MODULE"/apps.d/*/; do
      name="$(basename "$f")"
      [[ -f "$f$name.sh" ]] && printf '%s\n' "$name"
    done
  } 2>/dev/null | sort -u
}

# Source an app and run a function from it, with APP_DIR pointing at the
# directory its script lives in. Subshelled so app_check/app_install cannot
# leak between apps.
with_app() {
  local name="$1" fn="$2" f
  f="$(app_path "$name")" || return 2
  ( APP_DIR="$(dirname "$f")"
    # shellcheck source=/dev/null
    source "$f"
    "$fn" )
}

# Install another apps.d entry on demand. apps run in name order, so an app that
# depends on another cannot rely on ordering alone.
require_app() {
  local name="$1" f
  f="$(app_path "$name")" || { warn "no such app: $name"; return 1; }
  ( APP_DIR="$(dirname "$f")"
    # shellcheck source=/dev/null
    source "$f"
    app_check || { say "installing dependency $APP_NAME"; app_install; } )
}
