# The per-app layer on GNOME/Wayland

`app.conf` gives terminals and Emacs their own translations (see
[KEYMAP.md](KEYMAP.md)). Applying them needs to know which window has focus,
and on Wayland only the compositor knows that.

```
keyd's GNOME extension      keyd-application-mapper        keyd (root)
  watches focus        ->     matches the window     ->     applies the
  writes the window class     against app.conf and          bindings to the
  to $XDG_RUNTIME_DIR/        runs `keyd bind ...`          keys it emits
  keyd.fifo                   on /run/keyd.socket
```

The extension only reports focus and never injects keys. keyd emits them from
below the display server, so Wayland's restrictions do not apply.

## Pieces

- **The extension** ships in the keyd package at
  `/usr/share/keyd/gnome-extension-45/` (UUID `keyd@keyd.rvaiya.github.com`)
  and is not on extensions.gnome.org. The repo carries an adjusted copy in
  `gnome-extension/`, which `install.sh` installs:
  - **`shell-version` is 45 through 60.** The packaged list ends at the GNOME
    release current when keyd shipped, and the Shell silently skips an
    extension whose list omits the running version, so every GNOME upgrade
    would disable it.
  - **It does not start or kill the mapper.** The packaged extension starts
    `keyd-application-mapper -d` on enable and kills it on disable; the systemd
    unit owns the mapper instead.
  - **It reports the overview** as the class `gnome-shell-overview`, and the
    focused window again when the overview closes. The overview is not a
    window, so otherwise the last window's section applies to its search
    entry.

  The installer records the hash of the packaged `extension.js` the copy was
  made from, and warns when the installed keyd ships a different one.
- **The mapper** runs as `keyd-application-mapper.service`, a user unit. It
  waits up to a minute for the extension's FIFO, runs in the foreground so
  systemd can restart it, and logs to the journal.
- **The `keyd` group** grants access to `/run/keyd.socket`. On nss-altfiles
  systems (Bazzite, Silverblue) the group lives in `/usr/lib/group`, and
  `usermod -aG` exits 0 without adding anyone until the record is copied into
  `/etc/group`. `install.sh` does both. The membership takes effect at the next
  login.

The extension's code uses `Shell.WindowTracker`, `global.display.focus_window`
and the ESM `Extension` class. A new GNOME major can break it at load time;
`journalctl -o cat /usr/bin/gnome-shell` shows the exception.

## Checking it

```sh
gnome-extensions info keyd@keyd.rvaiya.github.com   # State: ACTIVE
ls -l "$XDG_RUNTIME_DIR/keyd.fifo"                   # exists while the extension runs
systemctl --user status keyd-application-mapper
journalctl --user -u keyd-application-mapper -f
```

## Writing app.conf sections

Sections match the window class after normalising it: runs of
non-alphanumerics become `-` and the result is lowercased, so
`org.gnome.Ptyxis` is `[org-gnome-ptyxis]`. To find a window's class, stop the
unit, run `keyd-application-mapper -v`, and focus the window.

Each line is `<layer>.<key> = <action>`, the `keyd bind` grammar:

```
[org-gnome-ptyxis]
mac.c = C-S-c
```

There is no way to disable a whole layer for an app; each binding is
overridden individually. Apps without a matching section use `default.conf`,
and when several sections match they all apply, the later ones winning.
