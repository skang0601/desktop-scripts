# The GNOME/Wayland focus bridge (Layer 3)

Everything here is optional. Layer 1 (`/etc/keyd/default.conf`) is a working
setup on its own; this adds the per-application behaviour, chiefly making
`Super+C` mean Ctrl+Shift+C inside a terminal. See
[ADR 0002](../../docs/decisions/0002-macos-keybindings.md) for why it's built this way.

## How it works

On Wayland no client may ask which window has focus -- that's the keylogging
surface Wayland was designed to close. Only the compositor knows.

```
GNOME Shell extension          keyd-application-mapper        keyd (root)
  reads focus_window     ->      reads ~/.config/keyd/    ->    emits keys
  .get_wm_class()                app.conf, calls              via uinput
  writes $XDG_RUNTIME_DIR/       `keyd bind ...`              (kernel level)
  keyd.fifo
```

The extension only *reports focus*. It never injects keystrokes -- that would be
blocked. keyd does the emission down in the kernel, where Wayland's restrictions
don't apply. This split is the whole trick.

## The extension is not third-party

It ships inside the keyd source tree at `data/gnome-extension-45/`, is installed
by keyd's Makefile, and is **not** published on extensions.gnome.org. Don't go
looking for it there.

- UUID (GNOME 45+): `keyd@keyd.rvaiya.github.com`
- UUID (GNOME 42-44): `keyd`

Running `keyd-application-mapper` once on GNOME installs it for you. The
extension then manages the daemon's lifecycle itself -- it spawns
`keyd-application-mapper -d` on enable and kills it on disable, so no systemd
user unit is needed.

## Setup

```sh
# 1. keyd must be running, and you must be in the keyd group.
#    On nss-altfiles systems (Bazzite, Silverblue) the keyd group lives in
#    /usr/lib/group, and usermod only amends /etc/group -- it finds nothing to
#    change there and exits 0 without adding you. Copy the record over first.
grep -q '^keyd:' /etc/group || getent group keyd | sudo tee -a /etc/group
sudo usermod -aG keyd "$USER"      # log out and back in for this to take effect
getent group keyd | grep -qw "$USER" || echo "membership did not take"
ls -l /var/run/keyd.socket         # must be group-readable by you

# 2. install the config from this repo
install -Dm644 keyd/app.conf ~/.config/keyd/app.conf

# 3. first run installs the GNOME extension
keyd-application-mapper

# 4. enable it, then restart the session (Wayland cannot reload the Shell)
gnome-extensions enable keyd@keyd.rvaiya.github.com
```

Verify:

```sh
gnome-extensions info keyd@keyd.rvaiya.github.com
ls "$XDG_RUNTIME_DIR/keyd.fifo"    # created by the extension when active
keyd-application-mapper -v         # prints the focused window class as it changes
tail -f ~/.config/keyd/app.log
```

## GNOME version compatibility

**This is the fragile part.** As of keyd v2.6.0 the extension's `metadata.json`
declares `"shell-version": ["45","46","47","48","49"]`. GNOME **50 is not
listed**, so on GNOME 50+ it will be flagged incompatible and refuse to load.

Bazzite currently builds on Fedora 44, which ships GNOME 50 -- so this applies
there too, not only on Fedora Workstation.

That's a declaration, not necessarily a real incompatibility. Two workarounds:

```sh
# Option A -- bump the declared version (per-user install)
EXT=~/.local/share/gnome-shell/extensions/keyd@keyd.rvaiya.github.com
# edit metadata.json, add your GNOME major version to shell-version

# Option B -- disable validation globally (blunter; affects all extensions)
gsettings set org.gnome.shell disable-extension-version-validation true
```

Then restart the session. Whether the extension's *code* still works is
separate: it uses `Shell.WindowTracker.get_default()`,
`global.display.focus_window`, `Main.layoutManager.connectObject` and the ESM
`Extension` base class. None are known removed, but this is unverified on 50 --
check `journalctl -f -o cat /usr/bin/gnome-shell` for exceptions after enabling.

If it doesn't work, nothing essential is lost. Terminals fall back to
Ctrl+Shift+C, or to Ctrl+Insert/Shift+Insert if your terminal accepts them.

## Writing app.conf sections

The window class is **normalised** before matching: non-alphanumerics collapse
to `-`, then lowercased. So `org.gnome.Ptyxis` is written `[org-gnome-ptyxis]`.
Don't guess -- run `keyd-application-mapper -v`, focus the window, and read the
class it prints.

Each line uses the `keyd bind` grammar, `<layer>.<key> = <action>`:

```
[org-gnome-ptyxis]

mac.c = C-S-c
```

There is no directive to *disable* a layer for an app; you override the
individual bindings. Apps with no matching section revert to
`/etc/keyd/default.conf`. All matching sections apply cumulatively, later ones
winning.
