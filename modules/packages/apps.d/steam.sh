# shellcheck shell=bash
APP_NAME=steam

# Bazzite ships Steam in the image, so this is usually a no-op there.
app_check() { have steam || flatpak_installed com.valvesoftware.Steam; }

app_install() {
  install_flatpak com.valvesoftware.Steam
}