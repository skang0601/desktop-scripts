APP_NAME=emacs

app_check() { have emacs; }

app_install() {
  # Native rather than Flatpak: the Flatpak sandbox makes emacs awkward as a
  # development editor, since LSP servers, compilers and toolchains live outside
  # it and have to be punched through one by one.
  install_cli emacs
}
