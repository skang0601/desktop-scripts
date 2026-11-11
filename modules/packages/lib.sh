# Homebrew helpers for the packages module.
# shellcheck shell=bash

BREWFILE="$MODULE/Brewfile"

# brew passes `sudo -A` whenever SUDO_ASKPASS is set, which Fedora's profile.d
# always sets to gnome-ssh-askpass, but brew's `env -i` allowlist keeps DISPLAY
# and drops XAUTHORITY, so Xwayland refuses the askpass dialog and sudo gets no
# password. The 1Password casks sudo; without SUDO_ASKPASS, sudo prompts on the
# terminal.
brew_bundle() {
  env -u SUDO_ASKPASS brew bundle "$@" --file="$BREWFILE"
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
