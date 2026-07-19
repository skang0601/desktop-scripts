# keybindings

macOS-style modifier behaviour on GNOME/Wayland, via [keyd](https://github.com/rvaiya/keyd).

```sh
./install.sh        # keyd + config + libinput quirk
./gsettings.sh      # GNOME shortcut collisions
```

Full reasoning is in [ADR 0002](../../docs/decisions/0002-macos-keybindings.md);
this is the operator's view.

## What you get

Cmd owns GUI actions, Ctrl owns Unix semantics -- the split Linux collapsed.

- **Physical Ctrl is never remapped.** `Ctrl+C` is SIGINT in every terminal, ssh
  session and REPL. This is the constraint the design is built around.
- **Super carries a translation layer.** `Super+C` is rewritten to the Ctrl-based
  combo apps actually listen for. Super doesn't become Cmd for free -- GTK, Qt
  and Electron hardcode Ctrl, so the rewrite is the whole job.
- **GNOME's Super bindings survive.** Keys the layer doesn't claim still reach
  GNOME with Super attached.
- **Terminals get a per-app exception** (optional third layer), so `Super+C`
  becomes Ctrl+Shift+C only where it needs to.

## Bindings

Translated by keyd (`default.conf`):

| Key | Emits | |
| --- | --- | --- |
| `Super+C` / `V` / `X` | `Ctrl+Insert` / `Shift+Insert` / `Shift+Delete` | copy / paste / cut |
| `Super+Z` | `Ctrl+Z` | undo |
| `Super+A` | `Ctrl+A` | select all |
| `Super+S` `F` `T` `N` `W` `R` | `Ctrl+`… | save, find, new tab, new window, close, reload |
| `Super+Q` | `Ctrl+Q` | quit -- app-dependent, see below |

Extra modifiers pass through, so `Super+Shift+T` correctly becomes
`Ctrl+Shift+T`, not `Ctrl+T`.

Left out of the keyd layer so GNOME can keep them -- most are already
macOS-shaped by default:

| Key | GNOME action | Stock default? | |
| --- | --- | --- | --- |
| `Super` (tap) | overview | yes | Mission Control |
| `Super+Tab` | `switch-applications` | yes | Cmd+Tab |
| ``Super+` `` | `switch-group` | yes | Cmd+\` |
| `Super+H` | `minimize` | yes | Cmd+H |
| `Super+Space` | `toggle-overview` | **no** | Spotlight |

`gsettings.sh` makes exactly two changes:

- **`Super+Space` -> overview.** Not a default; `toggle-overview` is unbound out
  of the box (stock GNOME uses the Super tap). Set here to get the Spotlight
  reflex.
- **App grid off `Super+A`.** `Super+A` is both select-all and GNOME's app grid.
  Select-all wins -- it's used hundreds of times a day -- so the app grid moves
  to `Super+Shift+Space`. Spotlight and Launchpad, tidily enough.

The rest of the script re-asserts the stock defaults, which is a no-op on a
fresh install and a convergence step on a machine with old customizations.

## Files

| File | Installed to |
| --- | --- |
| `default.conf` | `/etc/keyd/default.conf` |
| `app.conf` | `~/.config/keyd/app.conf` |
| `local-overrides.quirks` | `/etc/libinput/local-overrides.quirks` |
| `gsettings.sh` | run, not installed |

## The three layers

1. **keyd** (`default.conf`) -- kernel-level remapping, below the display
   server. Works on its own; this alone is a usable setup.
2. **GNOME** (`gsettings.sh`) -- window management. Mostly already correct by
   default.
3. **keyd-application-mapper** (`app.conf`) -- per-application behaviour,
   chiefly the terminal exception. Optional, and the fragile one. See
   [gnome-wayland-bridge.md](gnome-wayland-bridge.md).

The design degrades in that order rather than collapsing.

## Two things worth knowing

**The clipboard uses `Ctrl+Insert`/`Shift+Insert`, not `Ctrl+C`/`Ctrl+V`.** GTK4
binds both spellings, and many terminals accept the Insert forms too -- so
`Super+C` has a good chance of copying correctly in a terminal with no layer 3
at all. That's a cushion, not a guarantee. **Test it in your terminals first
thing**; if it fails there, that terminal needs an `app.conf` section and
therefore a working GNOME extension.

**`Super+Q` is app-dependent.** `Ctrl+Q` is a convention, not a guarantee, and
some apps implement no quit accelerator. `Alt+F4` remains the reliable close.

## Debugging

```sh
sudo keyd monitor                       # live view of what keyd sees and emits
keyd check /etc/keyd/default.conf       # validate before reloading
sudo keyd reload
systemctl status keyd
keyd-application-mapper -v              # prints focused window class as it changes
```

A bad config can leave the keyboard unusable. Keep a second keyboard or an ssh
session open while iterating; `sudo systemctl stop keyd` restores stock
behaviour.

## Untested

- Whether Ptyxis and foot accept `Ctrl+Insert`/`Shift+Insert`.
- Whether keyd's GNOME extension runs on GNOME 50 -- it declares support only
  through 49.
- Electron/Chromium apps handle accelerators idiosyncratically; VS Code,
  browsers and Slack are worth checking individually.
