APP_NAME=doom-emacs

# Doom's current home is ~/.config/emacs, but ~/.emacs.d is the legacy location
# and still takes precedence when both exist. Detect either, or a machine that
# already has Doom under the old path gets a second, unloadable copy.
DOOM_DIR="$HOME/.config/emacs"
DOOM_LEGACY="$HOME/.emacs.d"

app_check() { [[ -x "$DOOM_DIR/bin/doom" || -x "$DOOM_LEGACY/bin/doom" ]]; }

app_install() {
  # apps.d runs in filename order, which puts doom-emacs before emacs.
  require_app emacs
  # doom doctor wants these; installing them up front avoids a confusing
  # first-run report.
  have rg || install_cli ripgrep
  have fd || install_cli fd-find fd

  if [[ -e "$DOOM_LEGACY" ]]; then
    warn "$DOOM_LEGACY exists but holds no Doom install, and it shadows"
    warn "$DOOM_DIR. Move it aside before continuing."
    return 1
  fi

  run git clone --depth 1 https://github.com/doomemacs/doomemacs "$DOOM_DIR"
  # Interactive: asks about fonts and an env file.
  run "$DOOM_DIR/bin/doom" install
  say "add $DOOM_DIR/bin to PATH; run 'doom sync' after editing ~/.config/doom"
}
