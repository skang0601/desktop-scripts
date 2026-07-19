# desktop-scripts

Linux desktop customization, kept in git so a distro reinstall is a checkout and
one script rather than an afternoon of rediscovery.

**Target environment:** Fedora 44 Workstation - GNOME Shell 50 - Wayland

## What this does

Recreates the macOS separation of modifier concerns:

- **Super behaves like Cmd** for GUI actions -- `Super+C` copies, `Super+T` new
  tab, `Super+Q` quits.
- **Ctrl is never remapped.** `Ctrl+C` is SIGINT in every terminal, every ssh
  session, forever. This is the constraint the whole design is built around.
- **Terminals are context-aware.** With the focused window bridged in from
  GNOME, `Super+C` becomes `Ctrl+Shift+C` inside a terminal instead of a copy.

## Setup after a reinstall

```sh
git clone git@github.com:skang0601/desktop-scripts.git ~/Workspace/desktop-scripts
cd ~/Workspace/desktop-scripts
./scripts/install-keyd.sh          # or: ./scripts/install-keyd.sh full-swap
```

Then follow [docs/gnome-wayland-bridge.md](docs/gnome-wayland-bridge.md) for the
per-application layer, which needs a GNOME extension and a user service.

## Layout

```
keyd/profiles/       modifier profiles -> /etc/keyd/default.conf
keyd/app.conf        per-application overrides -> ~/.config/keyd/app.conf
keyd/*.quirks        libinput overrides -> /etc/libinput/
scripts/             installers, idempotent, safe to re-run
docs/decisions/      ADRs -- why things are the way they are
```

## Why is it like this?

Start with [docs/decisions/](docs/decisions/). The short version:

- [0002](docs/decisions/0002-keyd-as-remapping-layer.md) -- why `keyd` and not
  xremap / Toshy / dconf.
- [0003](docs/decisions/0003-super-as-primary-gui-modifier.md) -- why Ctrl is
  untouched, and the two profiles.
- [0004](docs/decisions/0004-application-aware-terminal-layer.md) -- how the
  terminal exception works on Wayland.
- [0005](docs/decisions/0005-touchpad-quirk-override.md) -- why there's a
  libinput quirk file in a keyboard repo.

## Debugging

```sh
sudo keyd monitor            # live view of what keyd sees and emits
systemctl status keyd
sudo keyd reload             # after editing /etc/keyd/default.conf
```

A bad config can leave the keyboard unusable. Keep a second keyboard or an SSH
session open while iterating; `sudo systemctl stop keyd` restores stock
behaviour.
