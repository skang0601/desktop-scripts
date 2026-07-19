#!/usr/bin/env bash
# GNOME shortcut adjustments (Layer 2). Idempotent.
#
# Window management is mostly GNOME's default already; this only handles what
# keyd's layer collides with. See docs/decisions/0002-macos-keybindings.md
set -euo pipefail

echo "==> Super+A is Cmd+A (select all); moving the app grid off it"
# A key mapped in keyd's [mac] layer never reaches GNOME, with or without Shift,
# so the app grid needs a key the layer does not touch.
gsettings set org.gnome.shell.keybindings toggle-application-view "['<Shift><Super>space']"

echo "==> Super+Space -> overview"
# toggle-overview is unbound in the schema; stock GNOME reaches the overview via
# the Super tap (overlay-key). This is an addition, not a restored default.
gsettings set org.gnome.shell.keybindings toggle-overview "['<Super>space']"

echo "==> re-asserting stock defaults so machines with old customizations converge"
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Super>Tab', '<Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Super>Tab', '<Shift><Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-group "['<Super>Above_Tab', '<Alt>Above_Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-group-backward "['<Shift><Super>Above_Tab', '<Shift><Alt>Above_Tab']"
gsettings set org.gnome.desktop.wm.keybindings minimize "['<Super>h']"

echo
echo "current state:"
for k in switch-applications switch-group minimize; do
  printf '  %-28s %s\n' "$k" "$(gsettings get org.gnome.desktop.wm.keybindings $k)"
done
for k in toggle-overview toggle-application-view; do
  printf '  %-28s %s\n' "$k" "$(gsettings get org.gnome.shell.keybindings $k)"
done
