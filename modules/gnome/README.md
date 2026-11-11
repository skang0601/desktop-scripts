# gnome

GNOME desktop setup that lives outside the keybindings module:

- **Brightness:** brightness control for an Apple Studio Display / Studio
  Display XDR through the
  [asd-brightness](https://github.com/skang0601/asd-brightness) GNOME Shell
  extension. It adds a Quick Settings slider, the brightness keys (plus
  `Super+F1`/`Super+F2`), and automatic brightness from the display's light
  sensors, switched in the extension's preferences.
- **Login screen:** the login screen uses the session's display layout, so it
  runs at 2x on the Studio Display.

```sh
./install.sh --dry-run
./install.sh                # the login screen step asks for sudo
```

## Brightness

1. Clones asd-brightness to `~/Workspace/asd-brightness` (override with
   `ASD_SRC`) if it is not already there. An existing checkout is never pulled;
   update it yourself and re-run.
2. Builds and installs the extension through the project's own `install.sh`,
   which builds in podman or docker. It rebuilds only when the checkout's
   `HEAD` differs from the commit recorded in the installed extension's
   `.source-commit`, or the checkout has uncommitted changes.
3. Enables the extension.

Gotchas:

- **The extension loads only at login.** On Wayland the Shell scans for
  extensions at login, so the first install, and every rebuild, takes effect
  after logging out and back in. Until then `gnome-extensions` does not know the
  extension exists, so the installer enables it by appending to
  `org.gnome.shell enabled-extensions` directly.
- **The display has no kernel backlight.** Brightness is a USB HID feature
  report, so the helper needs read/write access to the display's `hidraw` nodes.
  The installer copies the project's `uaccess` rule to
  `/etc/udev/rules.d` and re-triggers the existing nodes, and `doctor.sh`
  checks both the rule and that the helper can reach the display.
- **GNOME's brightness keys are rebound while the extension is enabled.** GNOME
  50 binds `XF86MonBrightnessUp/Down` in the Shell itself, where they drive only
  built-in backlights. The extension empties `org.gnome.shell.keybindings
  screen-brightness-up/down` on enable and restores them on disable.

## Login screen

The login screen runs its own mutter, which cannot read `~/.config/monitors.xml`
and auto-detects 1x for the Studio Display. The installer copies the session's
layout to `/etc/xdg/monitors.xml`, the system-wide layout mutter reads beneath
each user's own. The login screen picks it up whichever user GDM runs it as.

Gotchas:

- **It's a copy, so it goes stale.** Changing anything in Settings > Displays
  rewrites `~/.config/monitors.xml` and leaves the system copy behind.
  `doctor.sh` warns when they differ; re-run `install.sh` to sync them.
- **It is every user's fallback.** Any account without its own
  `monitors.xml` starts with this layout.
- **All saved layouts come along.** mutter picks the `<configuration>` that
  matches the monitors connected at the time, so docked and undocked layouts
  both carry over.
- **A greeter-level `monitors.xml` overrides it.** A file in GDM's own config
  home (under `/var/lib/gdm`) wins over the system copy. Remove any such file so
  this one applies.
- `/etc` is preserved and merged across image updates on atomic systems (see
  [ADR 0004](../../docs/decisions/0004-installing-on-atomic-systems.md)).
