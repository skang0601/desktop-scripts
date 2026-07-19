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

echo "==> gtk-key-theme stays Default; GTK key themes are a dead end here"
# Considered and rejected twice, so don't reach for it a third time.
#
# Stock 'Emacs' binds <ctrl>a/e/f/n/w, exactly what the mac layer emits for
# Cmd+A/E/F/N/W, so it breaks select-all, find and close.
#
# A custom theme binding only the free keys (d/h/k/u/y) avoids that collision
# and still does nothing useful, because there is nothing left to apply it to:
# GTK4 dropped key themes, and this desktop is GTK4 throughout. Firefox is the
# apparent exception and is not one -- it links GTK3 but draws its own text
# fields, so the `entry` and `textview` selectors match nothing, and its own
# accelerators own Ctrl+D, Ctrl+K and Ctrl+U regardless.
#
# Emacs-style motion lives in keyd's nav layer instead, which works in every
# toolkit. A reset rather than `set Default`, to clear the override outright.
gsettings reset org.gnome.desktop.interface gtk-key-theme

echo "==> Ptyxis: Cmd+A, Cmd+F, Cmd+T, Cmd+N"
# The mac layer emits Ctrl+T and Ctrl+N, and app.conf cannot help here -- it
# needs keyd-application-mapper, which has no working GNOME extension on
# Shell 50. Moving the terminal's own accelerators onto the bare-Ctrl spellings
# gets Cmd+T and Cmd+N working with no Layer 3 at all.
#
# Ctrl+N is free by construction: the nav layer consumes physical Ctrl+N and
# emits Down, so only Cmd+N can produce a real Ctrl+N. Ctrl+T costs readline's
# transpose-chars, which is a cheap trade.
#
# close-tab deliberately stays on Ctrl+Shift+W. `w` is not in the nav layer, so
# physical Ctrl+W still reaches the shell as delete-word-backward -- binding it
# to close-tab would destroy a tab every time a word is erased mid-command.
#
# Ctrl+A and Ctrl+F are free the same way Ctrl+N is: the nav layer turns the
# physical keys into Home and Right, so only Cmd can produce the bare Ctrl
# spelling. Ctrl+T is the one that costs something.
gsettings set org.gnome.Ptyxis.Shortcuts select-all '<ctrl>a'
gsettings set org.gnome.Ptyxis.Shortcuts search '<ctrl>f'
gsettings set org.gnome.Ptyxis.Shortcuts new-tab '<ctrl>t'
gsettings set org.gnome.Ptyxis.Shortcuts new-window '<ctrl>n'

# copy/paste stay on Ctrl+Shift+C/V. Ptyxis does not accept Ctrl+Insert or
# Shift+Insert as accelerators, which is what the mac layer emits for Cmd+C/V,
# so there is no Cmd spelling for the terminal clipboard without Layer 3.

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
