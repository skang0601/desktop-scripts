# studio-display

Brightness control for an Apple Studio Display / Studio Display XDR: the
[asd-brightness](https://github.com/skang0601/asd-brightness) GNOME Shell
extension, which adds a Quick Settings slider and takes over the brightness keys
(plus `Super+F1`/`Super+F2`).

```sh
./install.sh --dry-run
./install.sh
```

## What it does

1. Clones asd-brightness to `~/Workspace/asd-brightness` (override with
   `ASD_SRC`) if it is not already there. An existing checkout is never pulled;
   update it yourself and re-run.
2. Builds and installs the extension through the project's own `install.sh`,
   which builds in podman or docker. It rebuilds only when the checkout's
   `HEAD` differs from the commit recorded in the installed extension's
   `.source-commit`, or the checkout has uncommitted changes.
3. Enables the extension.

## Gotchas

- **The extension loads only at login.** On Wayland the Shell scans for
  extensions at login, so the first install, and every rebuild, takes effect
  after logging out and back in. Until then `gnome-extensions` does not know the
  extension exists, so the installer enables it by appending to
  `org.gnome.shell enabled-extensions` directly.
- **The display has no kernel backlight.** Brightness is a USB HID feature
  report, so the helper needs read/write access to the display's `hidraw` nodes.
  `doctor.sh` reports a failure if it cannot reach them; the project's
  `install.sh --udev` installs a `uaccess` rule for them.
- **GNOME's brightness keys are rebound while the extension is enabled.** GNOME
  50 binds `XF86MonBrightnessUp/Down` in the Shell itself, where they drive only
  built-in backlights. The extension empties `org.gnome.shell.keybindings
  screen-brightness-up/down` on enable and restores them on disable.
