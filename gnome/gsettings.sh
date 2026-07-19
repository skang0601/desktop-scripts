#!/usr/bin/env bash
# GNOME shortcut adjustments (Layer 2). Idempotent.
#
# Most of the macOS-shaped window management is already GNOME's default --
# Super+Tab, Super+`, Super+space and Super+H all work as Cmd equivalents with
# no configuration. This script only fixes the collisions keyd's layer creates.
#
# See docs/decisions/0002-macos-keybindings.md
set -euo pipefail

echo "==> Super+A is Cmd+A (select all); moving the app grid off it"
# Any key mapped in keyd's [mac] layer never reaches GNOME, Shift held or not,
# so the app grid has to land on a key the layer doesn't touch.
# Super+Space = Spotlight, Super+Shift+Space = Launchpad.
gsettings set org.gnome.shell.keybindings toggle-application-view "['<Shift><Super>space']"

echo "==> asserting the macOS-shaped defaults (no-ops on a stock GNOME)"
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Super>Tab', '<Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Super>Tab', '<Shift><Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-group "['<Super>Above_Tab', '<Alt>Above_Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-group-backward "['<Shift><Super>Above_Tab', '<Shift><Alt>Above_Tab']"
gsettings set org.gnome.shell.keybindings toggle-overview "['<Super>space']"
gsettings set org.gnome.desktop.wm.keybindings minimize "['<Super>h']"

echo
echo "current state:"
for k in switch-applications switch-group minimize; do
  printf '  %-28s %s\n' "$k" "$(gsettings get org.gnome.desktop.wm.keybindings $k)"
done
for k in toggle-overview toggle-application-view; do
  printf '  %-28s %s\n' "$k" "$(gsettings get org.gnome.shell.keybindings $k)"
done
