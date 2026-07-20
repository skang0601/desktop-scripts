# shellcheck shell=bash
APP_NAME=git-lfs

app_check() { have git-lfs; }

app_install() {
  # Required, not optional: modules/fonts stores its .otf files in LFS, so a
  # clone without this checks out pointer files and the installer copies 130-byte
  # text stubs into ~/.local/share/fonts.
  install_cli git-lfs

  # Writes the filter.lfs block to ~/.gitconfig, which is this repo's tracked
  # gitconfig -- so on a machine that already has the config, this is a no-op.
  run git lfs install
}