# shellcheck shell=bash
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
doom_legacy()    { [[ -x "$DOOM_LEGACY/bin/doom" ]]; }
doom_home()      { doom_legacy && echo "$DOOM_LEGACY" || echo "$DOOM_DIR"; }
doom_bin()       { echo "$(doom_home)/bin/doom"; }
# Follow the legacy config path only when a legacy Doom is what's installed.
doomdir()        { doom_legacy && echo "$DOOMDIR_LEGACY" || echo "$DOOMDIR"; }

# Fedora's emacs is built four ways and the RPM picks pgtk, which draws
# natively on Wayland. brew's Linux bottle is configured --without-x and only
# ever runs in a terminal, so "is emacs installed" is not the question -- this
# asks the binary whether it can open a frame at all.
emacs_gui() {
  have emacs || return 1
  emacs -Q --batch --eval '(kill-emacs (if (fboundp (quote x-create-frame)) 0 1))' 2>/dev/null
}

# External programs `doom doctor` asks for, given the modules enabled in
# doom/init.el: the binary, then the Fedora and brew package names for it.
#
# Only the ones no other app already installs are here. Language servers live
# with their languages -- gopls under go, zls under zig, rust-analyzer in the
# rustup toolchain -- so a machine gets them whether or not it runs emacs.
#
# sqlite is deliberately absent: org +roam wants it, and Emacs 29 and later have
# it built in, which is what org-roam uses.
DOOM_DEPS=(
  # doom itself, and :tools magit
  "git        git         git"
  # :completion vertico, :tools lookup
  "rg         ripgrep     ripgrep"
  "fd         fd-find     fd"
  # :lang sh -- shellcheck for :checkers syntax, shfmt for :editor format
  "shellcheck ShellCheck  shellcheck"
  "shfmt      shfmt       shfmt"
  # :lang markdown -- markdown-mode shells out to `markdown` for the preview
  "markdown   discount    markdown"
  # :lang org +roam -- graphviz's `dot` renders the roam graph
  "dot        graphviz    graphviz"
)

# app_check gates on this, so adding a row above installs it on the next run.
doom_deps_present() {
  local dep
  for dep in "${DOOM_DEPS[@]}"; do
    # shellcheck disable=SC2086  # deliberate word splitting of the table row
    set -- $dep
    have "$1" || return 1
  done
}

# The config link is compared by target, not by existence: -L alone is true of a
# link left dangling by a moved or renamed source, which is exactly the state
# that needs relinking.
app_check() {
  emacs_gui && doom_installed && doom_deps_present \
    && [[ "$(readlink -f "$(doomdir)" 2>/dev/null)" == "$(readlink -f "$APP_DIR/doom")" ]]
}

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

  local dep
  for dep in "${DOOM_DEPS[@]}"; do
    # shellcheck disable=SC2086  # deliberate word splitting of the table row
    set -- $dep
    have "$1" || install_cli "$2" "$3"
  done

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
  link_config "$APP_DIR/doom" "$(doomdir)" || return 1

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
  say "run 'doom sync' after editing $APP_DIR/doom"
  say "the shell module puts Doom's bin/ on PATH"
}

# Follows whichever layout the machine actually has, not the modern one.
app_checks() {
  if ! doom_installed; then
    check_warn "doom" "not installed" "./modules/packages/install.sh emacs"
    return 0
  fi
  check_ok "doom" "$(doom_home)"

  check_symlink "doom config" "$(doomdir)" "$APP_DIR/doom" \
    "./modules/packages/install.sh emacs"

  # brew's Linux bottle is built --without-x and takes precedence on PATH once
  # `brew shellenv` has run, so a working GUI build can be shadowed by one that
  # only ever opens a terminal frame.
  if emacs_gui; then
    check_ok "emacs GUI build" "$(command -v emacs)"
  else
    check_fail "emacs GUI build" "$(command -v emacs || echo emacs) cannot open a frame" \
      "./modules/packages/install.sh emacs"
  fi
}