# keybindings

macOS-style keys on GNOME/Wayland, implemented with
[keyd](https://github.com/rvaiya/keyd). [KEYMAP.md](KEYMAP.md) specifies what
every key does; [ADR 0002](../../docs/decisions/0002-macos-keybindings.md)
explains the design.

```sh
./install.sh        # keyd, its config, the per-app layer
./gsettings.sh      # the GNOME shortcuts that collide with the keymap
```

## How it fits together

1. **keyd** (`default.conf`) grabs the keyboards below the display server and
   re-emits them through a virtual keyboard. Super is the `mac` layer (Cmd),
   Ctrl the `nav` layer (Emacs motion), Alt the `opt` layer (Option). On its
   own this is a complete setup, minus the terminal exceptions.
2. **GNOME** (`gsettings.sh`) moves the app grid to Shift+Super+Space, binds
   Super+Space to the overview, and clears the input-source switcher off
   Super+Space.
3. **The per-app layer** (`app.conf`) gives terminals and Emacs their own
   translations. `keyd-application-mapper` pushes them into keyd whenever the
   focused window changes, and keyd's GNOME extension tells it which window
   that is. See [gnome-wayland-bridge.md](gnome-wayland-bridge.md).

Each layer works without the ones after it. With the per-app layer down,
terminals still get Ctrl verbatim, but Cmd+C/V do nothing in them.

## Files

| File | Installed to |
| --- | --- |
| `default.conf` | `/etc/keyd/default.conf` |
| `app.conf` | `~/.config/keyd/app.conf` |
| `keyd-restart.conf` | `/etc/systemd/system/keyd.service.d/restart.conf` |
| `keyd-application-mapper.service` | `~/.config/systemd/user/`, linked |
| `local-overrides.quirks` | `/etc/libinput/local-overrides.quirks` ([ADR 0003](../../docs/decisions/0003-touchpad-quirk-override.md)) |
| `gnome-extension/` | `~/.local/share/gnome-shell/extensions/keyd@keyd.rvaiya.github.com` |

`gnome-extension/` is keyd's own GNOME extension, adjusted: it declares GNOME
45 through 60, leaves the mapper to the systemd unit, and reports the overview
as a window class of its own. The header of its `extension.js` lists the
changes, and the installer warns when the packaged original changes.

## keyd 2.6.0

- **It segfaults on the first key event after `keyd reload`.** The installer
  only restarts it, and only when an installed file changed. The restart
  drop-in brings it back within a second after any crash. `doctor.sh` warns
  only about crashes that did not follow a config load.
- **There are no trailing comments.** `c = C-insert  # copy` takes the rest of
  the line as the action and drops the binding. `keyd check` reports that as a
  WARNING and exits 0, so the installer treats any warning as fatal.
- **After a restart, the per-app layer is missing until the next focus change,**
  because the mapper pushes bindings only when the focused window changes.

## Debugging

```sh
sudo keyd monitor                         # what keyd sees and emits
keyd check modules/keybindings/default.conf
sudo systemctl restart keyd               # never `keyd reload`
journalctl --user -u keyd-application-mapper -f
./doctor.sh keybindings
```

A broken config can leave the keyboard unusable. Keep a second keyboard or an
ssh session open while changing it; `sudo systemctl stop keyd` gives the stock
keyboard back.

## Untested

- Whether foot accepts Ctrl+Insert/Shift+Insert. Ptyxis does not.
- Electron apps handle accelerators individually; VS Code and Slack need
  checking against KEYMAP.md.
- How `[mac+nav]` handles keys it does not list, such as Ctrl+Super+1 (GNOME:
  open a new window of app 1).
