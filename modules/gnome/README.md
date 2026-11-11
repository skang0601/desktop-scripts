# gnome

GNOME desktop setup outside the keybindings module:

- **Brightness:** brightness control for an Apple Studio Display / Studio
  Display XDR through the
  [asd-brightness](https://github.com/skang0601/asd-brightness) GNOME Shell
  extension. It adds a Quick Settings slider, the brightness keys (plus
  `Super+F1`/`Super+F2`), and automatic brightness from the display's light
  sensors, switched in the extension's preferences.
- **Login screen:** the login screen uses the session's display layout, so it
  runs at 2x on the Studio Display.
- **Power:** the machine never suspends on its own, in the session or at the
  login screen, so the local LLM and the OpenCode server stay reachable.

```sh
./install.sh --dry-run
./install.sh                # the udev, login screen and power steps ask for sudo
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
  The installer installs the project's `uaccess` rule as
  `/etc/udev/rules.d/70-apple-studio-display.rules` and re-triggers the nodes.
  It must sort before systemd's `73-seat-late.rules`, which turns `uaccess` tags
  into ACLs; under the project's own `99-` name the nodes are tagged and stay
  root-only. `doctor.sh` checks the rule and that the helper reaches the display.
- **GNOME's brightness keys are rebound while the extension is enabled.** GNOME
  binds `XF86MonBrightnessUp/Down` in the Shell itself, where they drive only
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

## Power

GNOME suspends an idle machine on AC after 15 minutes, in the session and at
the login screen separately.

- **Session:** `org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type`
  is set to `nothing`.
- **Login screen:** the same key is set in GDM's dconf database, from
  `gdm-power.dconf` installed as `/etc/dconf/db/gdm.d/90-desktop-scripts-power`,
  then compiled with `dconf update`. Without it, the machine suspends while it
  sits at the login screen after a reboot.

The screen still blanks when idle.
