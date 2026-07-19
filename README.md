# desktop-scripts

Linux desktop customization, kept in git so a distro reinstall is a checkout and
one script rather than an afternoon of rediscovery.

**Target environment:** GNOME on Wayland.

GNOME is the real dependency -- the design leans on Mutter's shortcut defaults
and, optionally, a Shell extension. The distro underneath is not load-bearing,
though the install path differs between traditional package managers and
atomic/image-based systems (Bazzite, Silverblue, Bluefin). Developed on Fedora
Workstation, intended to land on Bazzite.

## What this does

Recovers the macOS split of modifier duty: Cmd owns GUI actions, Ctrl owns Unix
semantics.

- **Physical Ctrl is never remapped.** `Ctrl+C` is SIGINT in every terminal, ssh
  session and REPL, forever. This is the constraint the whole design is built
  around, not a nice-to-have.
- **Super carries a translation layer.** `Super+C` is rewritten to the
  Ctrl-based combo apps actually listen for. Super doesn't become Cmd for free --
  GTK, Qt and Electron all hardcode Ctrl, so the rewrite is the actual work.
- **GNOME's Super bindings survive.** Keys the layer doesn't claim still reach
  GNOME carrying Super, so Cmd+Tab, Cmd+\`, Cmd+Space and Cmd+H keep working --
  they're GNOME defaults already.
- **Terminals get a per-app exception** (optional), so `Super+C` becomes
  Ctrl+Shift+C only where it needs to.

## Setup after a reinstall

```sh
git clone git@github.com:skang0601/desktop-scripts.git ~/Workspace/desktop-scripts
cd ~/Workspace/desktop-scripts
./scripts/install-keyd.sh     # keyd + config + libinput quirk
./gnome/gsettings.sh          # GNOME shortcut collisions
```

Then, optionally, [docs/gnome-wayland-bridge.md](docs/gnome-wayland-bridge.md)
for the per-application layer.

## Layout

```
keyd/default.conf         the modifier layer -> /etc/keyd/default.conf
keyd/app.conf             per-application overrides -> ~/.config/keyd/app.conf
keyd/local-overrides.quirks   libinput fix -> /etc/libinput/
gnome/gsettings.sh        GNOME shortcut adjustments
scripts/                  installers, idempotent, safe to re-run
docs/decisions/           ADRs -- why things are the way they are
```

## Why is it like this?

- [ADR 0002](docs/decisions/0002-macos-keybindings.md) -- the whole keybinding
  design: why Ctrl is untouched, why Super needs an active translation layer,
  why `layer()` and not `overload()`, why `[mac:M]` and not `[mac]`, and which
  GNOME defaults were already macOS-shaped.
- [ADR 0003](docs/decisions/0003-touchpad-quirk-override.md) -- why there's a
  libinput quirk file in a keyboard repo.
- [gnome-wayland-bridge.md](docs/gnome-wayland-bridge.md) -- the optional
  focus-aware layer and its GNOME version fragility.

## Debugging

```sh
sudo keyd monitor            # live view of what keyd sees and emits
keyd check /etc/keyd/default.conf
sudo keyd reload             # after editing the config
systemctl status keyd
```

A bad config can leave the keyboard unusable. Keep a second keyboard or an ssh
session open while iterating; `sudo systemctl stop keyd` restores stock
behaviour.

## Known-unverified

- Whether Ptyxis and foot accept `Ctrl+Insert`/`Shift+Insert` for copy/paste.
  This is the cushion that makes terminals usable without the Layer 3 bridge --
  worth testing first thing after install.
- Whether keyd's GNOME extension works on GNOME 50; it declares support only
  through 49.
