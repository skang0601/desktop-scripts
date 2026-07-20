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

# switch-input-source defaults to <Super>space and its backward twin to
# <Shift><Super>space, so both bindings above land on keys GNOME already claims
# and the input switcher wins. Clearing them costs nothing while a single
# source is configured; a second layout needs a different key, not these back.
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "[]"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "[]"

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

echo "==> Ptyxis: stock Ctrl+Shift accelerators, reached via Cmd by app.conf"
# Ptyxis keeps its defaults and app.conf supplies the Cmd spellings, which is
# only possible while keyd-application-mapper is running.
#
# Binding these to bare Ctrl instead would collide with the nav layer rather
# than dodge it: app.conf hands Ctrl+A/E/B/F/P/N back to the shell inside a
# terminal, so a bare-Ctrl accelerator here eats the key before readline or tmux
# sees it -- Ctrl+A selects all instead of reaching the tmux prefix. Ctrl+T is
# free for readline's transpose-chars for the same reason.
gsettings reset org.gnome.Ptyxis.Shortcuts select-all
gsettings reset org.gnome.Ptyxis.Shortcuts search
gsettings reset org.gnome.Ptyxis.Shortcuts new-tab
gsettings reset org.gnome.Ptyxis.Shortcuts new-window

# copy/paste are absent from the schema and handled internally by Ptyxis, so
# Ctrl+Shift+C/V work without a binding here. app.conf maps Cmd+C/V onto them.

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
