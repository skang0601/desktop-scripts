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

echo "==> gtk-key-theme stays Default; the Emacs theme is incompatible with Cmd"
# Considered and rejected, so don't re-try it. The Emacs gtk-key-theme binds
# Ctrl+A/E/F/N/W inside GtkEntry and GtkTextView, and the mac layer delivers
# Super+A/E/F/N/W as exactly those keystrokes -- once keyd has rewritten Cmd+A
# into a literal Ctrl+A, nothing downstream can tell the two apart. Setting the
# theme therefore breaks Cmd+A, Cmd+F and Cmd+W in every GTK3 text field, which
# is the whole point of the layout.
#
# The emacs motions live in keyd's nav layer instead (default.conf), where they
# stay distinct from Cmd and work in GTK4 and Electron too -- the theme only
# ships a gtk-3.0 set. A reset rather than a `set Default`, to clear the dconf
# override outright on a machine that has tried this.
gsettings reset org.gnome.desktop.interface gtk-key-theme

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
printf '  %-28s %s\n' gtk-key-theme \
  "$(gsettings get org.gnome.desktop.interface gtk-key-theme)"
