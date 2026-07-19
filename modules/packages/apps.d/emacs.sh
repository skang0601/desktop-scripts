APP_NAME=emacs

# Doom's config dir: $DOOMDIR, then ~/.config/doom, then legacy ~/.doom.d.
# Doom itself: ~/.config/emacs, with legacy ~/.emacs.d still taking precedence.
# Detect what a machine already has rather than forcing the modern layout onto
# an existing install, which would leave two copies and load the wrong one.
DOOM_DIR="$HOME/.config/emacs"
DOOM_LEGACY="$HOME/.emacs.d"
DOOMDIR="$HOME/.config/doom"
DOOMDIR_LEGACY="$HOME/.doom.d"

doom_installed() { [[ -x "$DOOM_DIR/bin/doom" || -x "$DOOM_LEGACY/bin/doom" ]]; }
doom_bin()       { [[ -x "$DOOM_LEGACY/bin/doom" ]] && echo "$DOOM_LEGACY/bin/doom" || echo "$DOOM_DIR/bin/doom"; }
# Follow the legacy config path only when a legacy Doom is what's installed.
doomdir()        { [[ -x "$DOOM_LEGACY/bin/doom" ]] && echo "$DOOMDIR_LEGACY" || echo "$DOOMDIR"; }

app_check() { have emacs && doom_installed && [[ -L "$(doomdir)" ]]; }

app_install() {
  # Native rather than Flatpak: the Flatpak sandbox makes emacs awkward as a
  # development editor, since LSP servers, compilers and toolchains live outside
  # it and have to be punched through one by one.
  have emacs || install_cli emacs

  # Doom's own requirements, plus what the enabled modules need:
  # ripgrep and fd for :completion and :tools lookup, shellcheck for the
  # :checkers syntax module against :lang sh.
  have git || install_cli git
  have rg  || install_cli ripgrep
  have fd  || install_cli fd-find fd
  have shellcheck || install_cli ShellCheck shellcheck

  local fresh=0
  if ! doom_installed; then
    if [[ -e "$DOOM_LEGACY" ]]; then
      warn "$DOOM_LEGACY exists but holds no Doom install, and it shadows $DOOM_DIR"
      warn "move it aside, then re-run"
      return 1
    fi
    run git clone --depth 1 https://github.com/doomemacs/doomemacs "$DOOM_DIR"
    fresh=1
  fi

  link_doom_config || return 1

  if (( fresh )); then
    # Interactive: asks about fonts and an env file.
    run "$(doom_bin)" install
  else
    # Doom is already set up; the config just changed underneath it.
    run "$(doom_bin)" sync
  fi
  say "run 'doom sync' after editing $MODULE/doom"
}

# Symlink the tracked config into place so edits land in the repo.
link_doom_config() {
  local target="$MODULE/doom" dest; dest="$(doomdir)"

  if [[ -L "$dest" ]]; then
    skip "doom config" "already linked"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    local backup="$dest.bak"
    warn "$dest is a real directory; backing it up to $backup"
    run mv "$dest" "$backup"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -s "$target" "$dest"
}
