# Install strategies for the packages module.
# shellcheck shell=bash

# app_install calls `blocked` to mean "this cannot be installed here, the
# reason is known, and re-running will not change it" -- an upstream bug, an
# unsupported platform. The summary keeps these apart from failures so a
# standing block doesn't read as a fresh error on every run, and doesn't fail
# the module's exit status.
BLOCKED=79
# Continuation lines are indented under the "!!" so a reason that carries an
# upstream thread to watch still reads as one message.
blocked() { warn "${*//$'\n'/$'\n'    }"; exit "$BLOCKED"; }

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

# When one formula owns a directory under the prefix, brew links the directory
# itself as a single symlink into that keg rather than its files. The next
# formula to ship files there writes through that symlink into the first one's
# Cellar, which is read-only during post_install, so its post_install fails and
# `brew install` exits nonzero with the keg installed and working. Currently hit
# by share/pwsh, which fd claims and rustup then adds to.
#
# Sets BREW_SPLIT_OWNER to the formula that held the directory. Relinking it has
# to wait until the new keg has put its file in there -- brew collapses a
# directory holding one formula's files straight back into a symlink -- so the
# caller relinks with brew_relink after the install.
brew_split_shared_dir() {
  local rel="$1" dir
  BREW_SPLIT_OWNER=""

  have brew || return 0
  dir="$(brew --prefix)/$rel"
  [[ -L "$dir" ]] || return 0

  BREW_SPLIT_OWNER="$(readlink -f "$dir")"
  BREW_SPLIT_OWNER="${BREW_SPLIT_OWNER#*/Cellar/}"
  BREW_SPLIT_OWNER="${BREW_SPLIT_OWNER%%/*}"

  say "splitting $rel out of the $BREW_SPLIT_OWNER keg so other formulae can add files"
  run rm "$dir"
  run mkdir -p "$dir"
}

brew_relink() {
  run brew unlink "$1"
  run brew link "$1"
}

# ublue-os repackage several vendors' own Linux builds as casks -- the vendor's
# binary by a different route, which on an atomic system beats both a container
# and layering (ADR 0005).
UBLUE_TAP=ublue-os/tap

# Homebrew refuses to load anything from a tap it has not been told to trust,
# because loading a cask runs its Ruby. Trust is per tap, so an app calls this
# after saying what that particular tap's casks do with it.
brew_tap_trusted() {
  run brew tap "$1"
  run brew trust "$1"
}

# `distrobox list` prints a padded table with the name in the second column.
distrobox_exists() {
  distrobox list 2>/dev/null | awk -F'|' 'NR>1 {gsub(/ /,"",$2); print $2}' | grep -qx "$1"
}

# Vendors who ship .deb and nothing else share one box rather than each pulling
# an image of its own (ADR 0005).
DEB_BOX=ubuntu
DEB_BOX_IMAGE=quay.io/toolbx/ubuntu-toolbox:24.04

distrobox_ensure() {
  local name="$1" image="$2"
  shift 2
  distrobox_exists "$name" && return 0
  say "creating the $name distrobox from $image"
  run distrobox create --name "$name" --image "$image" --yes "$@"
}

# distrobox mounts $HOME at the same path with the same uid, so a file the
# container writes there is the same inode the host sees. That is the whole
# reason an app whose value is a socket in $HOME can live in one (ADR 0005).
in_distrobox() {
  local name="$1"
  shift
  distrobox enter --name "$name" -- "$@"
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

# An app may define app_checks() to report state beyond installed/not, using the
# same path detection its app_install uses rather than a second copy of it in the
# module's checks.sh. Optional, so a missing one is not an error.
run_app_checks() {
  local name="$1" f
  f="$(app_path "$name")" || return 0
  ( APP_DIR="$(dirname "$f")"
    # Nest this app's rows under it, and under its APP_GROUP when it declares
    # one, so related apps read as one thing rather than scattering through an
    # alphabetical list.
    CHECK_GROUP="$(app_group_path "$name")"
    export CHECK_GROUP
    # shellcheck source=/dev/null
    source "$f"
    # The guard exits 0 for an app without app_checks. Folding it into
    # `&& app_checks` would return nonzero there, and the caller runs under
    # errexit.
    declare -F app_checks >/dev/null || exit 0
    app_checks )
}

# "GROUP/name" when the app declares APP_GROUP, otherwise just "name". Sourced
# in a subshell because reading APP_GROUP means loading the app file.
app_group_path() {
  local name="$1" f
  f="$(app_path "$name")" || { printf '%s\n' "$name"; return 0; }
  ( APP_DIR="$(dirname "$f")"
    # shellcheck source=/dev/null
    source "$f" >/dev/null 2>&1
    if [[ -n "${APP_GROUP:-}" ]]; then
      printf '%s/%s\n' "$APP_GROUP" "$name"
    else
      printf '%s\n' "$name"
    fi )
}

# Apps in group order, then name order, so a group's members are adjacent.
app_names_grouped() {
  local name
  while read -r name; do
    printf '%s\t%s\n' "$(app_group_path "$name")" "$name"
  done < <(app_names) | sort -t/ -k1,1 | cut -f2
}

# An app may define app_blocked() to say it cannot be installed on this machine:
# it prints the reason and succeeds when blocked, and fails when it is not. Both
# app_install and the checks consult it, so the condition has one definition
# rather than a copy in each that can drift apart.
app_blocked_reason() {
  local name="$1" f
  f="$(app_path "$name")" || return 1
  ( APP_DIR="$(dirname "$f")"
    # shellcheck source=/dev/null
    source "$f"
    declare -F app_blocked >/dev/null || exit 1
    app_blocked )
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
