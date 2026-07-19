APP_NAME=1password

app_check() { flatpak_installed com.onepassword.OnePassword || have 1password; }

app_install() {
  # Flathub listing is vendor-verified (onepassword.com). The alternative is
  # 1Password's own RPM repo, which would mean layering on an atomic system.
  #
  # Known limitation: browser integration needs the extension to reach the
  # desktop app, and a Flatpak app plus a non-Flatpak browser (or the reverse)
  # can fail to connect. If that bites, switch to the RPM repo.
  install_flatpak com.onepassword.OnePassword
}
