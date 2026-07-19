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

# Fedora's emacs is built four ways and the RPM picks pgtk, which draws
# natively on Wayland. brew's Linux bottle is configured --without-x and only
# ever runs in a terminal, so "is emacs installed" is not the question -- this
# asks the binary whether it can open a frame at all.
emacs_gui() {
  have emacs || return 1
  emacs -Q --batch --eval '(kill-emacs (if (fboundp (quote x-create-frame)) 0 1))' 2>/dev/null
}

app_check() { emacs_gui && doom_installed && [[ -L "$(doomdir)" ]]; }

app_install() {
  # Distro package rather than brew: only the RPM is a GUI build (see
  # emacs_gui). Native rather than Flatpak: the Flatpak sandbox makes emacs
  # awkward as a development editor, since LSP servers, compilers and
  # toolchains live outside it and have to be punched through one by one.
  if ! emacs_gui; then
    # brew's bin/ precedes /usr/bin once `brew shellenv` has run, so leaving
    # the headless build installed would shadow the one being installed here.
    if have brew && brew list --formula emacs >/dev/null 2>&1; then
      say "removing brew's headless emacs; it would shadow the GUI build"
      run brew uninstall --ignore-dependencies emacs
    fi
    install_rpm emacs
  fi

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

  # Tracked config, symlinked so edits land in the repo.
  link_config "$MODULE/doom" "$(doomdir)" || return 1

  # Cloning Doom and linking the config need no emacs, but byte-compiling the
  # package tree does. A layered emacs isn't on PATH until the reboot, so on a
  # first run there is nothing to sync with yet.
  if ! have emacs; then
    warn "emacs is layered but not yet on PATH; reboot, then re-run to sync Doom"
    return 0
  fi

  if (( fresh )); then
    # Interactive: asks about fonts and an env file.
    run "$(doom_bin)" install
  else
    # Doom is already set up; the config just changed underneath it.
    run "$(doom_bin)" sync
  fi
  say "run 'doom sync' after editing $MODULE/doom"
  say "the shell module puts Doom's bin/ on PATH"
}
