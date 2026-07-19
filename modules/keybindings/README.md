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

- **`Ctrl+C` is SIGINT, everywhere, always.** In every terminal, ssh session and
  REPL. This is the constraint the design is built around.
- **Ctrl carries an emacs navigation layer.** `Ctrl+A`/`E` are line start/end and
  `Ctrl+B`/`F`/`P`/`N` are the arrows, in every app. Only those six keys are
  claimed; everything else keeps its Ctrl meaning untouched.
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

Navigation on physical Ctrl (`default.conf`, the `nav` layer):

| Key | Emits | |
| --- | --- | --- |
| `Ctrl+A` / `E` | `Home` / `End` | line start / end |
| `Ctrl+B` / `F` | `Left` / `Right` | back / forward one char |
| `Ctrl+P` / `N` | `Up` / `Down` | previous / next line |

This is the other half of the macOS split: Cmd does the editing verbs, Ctrl
moves the cursor. GNOME's Emacs `gtk-key-theme` cannot do this job -- by the
time a key reaches GTK, `Super+A` has already become a literal `Ctrl+A`, so the
theme would capture both and `Super+A` would stop selecting all. The theme also
ships only a `gtk-3.0` set, so it is inert in GTK4 apps. Doing it in keyd keeps
the two apart and works everywhere, GTK4 and Electron included.

`Ctrl+D`, `Ctrl+H`, `Ctrl+K`, `Ctrl+W`, `Ctrl+U` and `Ctrl+Y` are deliberately
**not** in the layer. They are EOF and readline editing in a shell, and a
terminal only escapes the layer through `app.conf` -- which needs layer 3
running. Everything in the layer has to be survivable in a terminal when that
daemon is down, and `Home` and the arrows are; `Delete` is not.

Text editing in GTK3 text fields (`gtk-keys/MacEmacs`):

| Key | Action |
| --- | --- |
| `Ctrl+D` / `Ctrl+H` | delete char forward / back |
| `Ctrl+K` / `Ctrl+U` | kill to end / start of line |
| `Ctrl+Y` | yank (paste) |
| `Alt+B` / `Alt+F` | word back / forward |
| `Alt+D` / `Alt+Backspace` | delete word forward / back |

A **custom** key theme, not GNOME's stock `Emacs` one. Stock `Emacs` binds
`<ctrl>a/e/f/n/w`, which is precisely what the mac layer emits for
`Cmd+A/E/F/N/W`, so setting it breaks select-all, find and close in every GTK3
text field. `MacEmacs` binds only keys neither keyd layer claims.

It needs no terminal exemption: the selectors match `entry` and `textview`, and
a terminal draws in a VTE widget, so `Ctrl+D` stays EOF in a shell. That is why
these keys live here rather than in the nav layer, which would need a working
`keyd-application-mapper` to keep clear of terminals.

The limit is that **GTK4 dropped key themes**, so this reaches GTK3 apps only --
Firefox among them, which is the point. GTK4 apps get the nav layer's motion
keys and nothing more. Flatpak apps additionally need `~/.themes` mounted;
`install.sh` sets that override.

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

`gsettings.sh` also moves two Ptyxis accelerators onto the bare-Ctrl spellings
the mac layer emits, so `Cmd+T` and `Cmd+N` work in the terminal without Layer 3:

| Ptyxis action | Was | Now | Why it is safe |
| --- | --- | --- | --- |
| `select-all` | `Ctrl+Shift+A` | `Ctrl+A` | free -- the nav layer eats physical `Ctrl+A` |
| `search` | `Ctrl+Shift+F` | `Ctrl+F` | free -- the nav layer eats physical `Ctrl+F` |
| `new-window` | `Ctrl+Shift+N` | `Ctrl+N` | free -- the nav layer eats physical `Ctrl+N` |
| `new-tab` | `Ctrl+Shift+T` | `Ctrl+T` | costs readline's transpose-chars |
| `close-tab` | `Ctrl+Shift+W` | *unchanged* | `Ctrl+W` is still delete-word in the shell |
| `copy`/`paste` | `Ctrl+Shift+C`/`V` | *unchanged* | Ptyxis ignores the Insert forms |

`Ctrl+N` is the clean case: the nav layer consumes physical `Ctrl+N` and emits
`Down`, so only `Cmd+N` can produce a real `Ctrl+N`. `close-tab` is deliberately
left alone -- `w` is not in the nav layer, so binding it would close a tab every
time a word is erased mid-command.

The rest of the script re-asserts the stock defaults, which is a no-op on a
fresh install and a convergence step on a machine with old customizations.

## Files

| File | Installed to |
| --- | --- |
| `default.conf` | `/etc/keyd/default.conf` |
| `app.conf` | `~/.config/keyd/app.conf` |
| `gtk-keys/MacEmacs/` | `~/.themes/MacEmacs` (symlink) |
| `local-overrides.quirks` | `/etc/libinput/local-overrides.quirks` |
| `gsettings.sh` | run, not installed |

## The three layers

1. **keyd** (`default.conf`) -- kernel-level remapping, below the display
   server. Works on its own; this alone is a usable setup.
2. **GNOME** (`gsettings.sh`) -- window management. Mostly already correct by
   default.
3. **keyd-application-mapper** (`app.conf`) -- per-application behaviour: the
   terminal clipboard exception, and handing the `nav` keys back to readline in
   Ptyxis and foot. Optional, and the fragile one. See
   [gnome-wayland-bridge.md](gnome-wayland-bridge.md).

The design degrades in that order rather than collapsing.

## Two things worth knowing

**The clipboard uses `Ctrl+Insert`/`Shift+Insert`, not `Ctrl+C`/`Ctrl+V`.** GTK4
binds both spellings, so `Cmd+C` copies in GUI apps while `Ctrl+C` stays SIGINT.

**This does not reach terminals.** Ptyxis ignores both Insert forms as
accelerators -- rebinding `copy-clipboard` to `<ctrl>Insert` was tried and does
not work. So in a terminal the clipboard is `Ctrl+Shift+C`/`V`, and there is no
`Cmd` spelling for it without Layer 3.

**`Super+Q` is app-dependent.** `Ctrl+Q` is a convention, not a guarantee, and
some apps implement no quit accelerator. `Alt+F4` remains the reliable close.

**keyd has no trailing-comment syntax.** `c = C-insert  # copy` takes the rest
of the line as the action, so the binding is invalid and gets dropped. Comments
belong on their own line above a binding. `keyd check` reports this as a
`WARNING` and still exits 0, so a config can lose an entire layer and look
fine; `install.sh` treats any warning as fatal for that reason.

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

- Whether foot accepts `Ctrl+Insert`/`Shift+Insert`. Ptyxis does not.
- Whether keyd's GNOME extension runs on GNOME 50 -- it declares support only
  through 49.
- Electron/Chromium apps handle accelerators idiosyncratically; VS Code,
  browsers and Slack are worth checking individually.
