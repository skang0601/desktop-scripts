# 0002 - macOS-style keybindings on GNOME/Wayland

- Status: accepted
- Date: 2026-07-19

The key-by-key behaviour is specified in
[`modules/keybindings/KEYMAP.md`](../../modules/keybindings/KEYMAP.md). This
records how it is implemented and why.

## Context

macOS splits modifier duty: Cmd owns GUI actions (copy, paste, new tab, quit),
and Ctrl owns Unix semantics (SIGINT, EOF, readline) and Emacs-style cursor
motion. Linux puts both on Ctrl, which is why terminals use Ctrl+Shift+C for
copy. The goal is the macOS split on GNOME under Wayland.

**Ctrl+C is SIGINT in every terminal, ssh session, TUI and REPL, and nothing
may endanger that.** This rules out swapping Ctrl and Super in hardware, which
reproduces the macOS layout and gives up the property that makes it worth
having.

## Translation, not a new modifier

GTK, Qt, Electron and web apps hardcode Ctrl for their shortcuts, and nothing
makes them listen for Super. So Cmd+X has to be **translated** into the Ctrl+X
the app already handles. The same mechanism provides the terminal exceptions.

Wayland decides where the translation can run. No client may grab keys
globally or inject keys into another client, so the remapping happens below
the display server: grab the evdev devices, re-emit through uinput. keyd does
that.

## Decision

keyd, in three layers.

### 1. keyd (`default.conf`)

```
[main]
meta    = layer(mac)
control = layer(nav)
alt     = layer(opt)

[mac:M]          Cmd: GUI actions, line and document motion
[nav:C]          Ctrl: Emacs motion (Home, End, arrows, Backspace)
[opt:A]          Option: word and paragraph motion
[mac+nav]        Ctrl+Cmd: GNOME's window keys, lock, full screen
[mac+shift]      Shift+Cmd: screenshots, help
```

The keyd behaviour the config depends on:

- **`layer()`, not `overload()`.** keyd sends a clean Super press and release
  for an isolated tap of a layer key, so a Super tap still opens the overview.
  Super is never sent with a translated key, so Cmd+C does not open it either.
  `overload(mac, meta)` does not parse, because `meta` is an alias rather than
  a key name.
- **`:M`, `:C` and `:A` keep the modifier on unmapped keys.** Super+Tab still
  reaches GNOME as Super+Tab, and Ctrl+C as Ctrl+C. Without the suffix, keyd
  would drop the modifier.
- **Explicit bindings drop the layer's modifier but keep physically held
  ones.** `left = home` in `[mac:M]` sends Home, and with Shift held,
  Shift+Home.
- **A composite layer overrides its parts only for the keys it lists,** and
  states every modifier it sends.

**The `nav` layer holds only keys that are harmless in a terminal without the
per-app layer.** Home, End, the arrows and Backspace are. Delete for Ctrl+D,
or Enter for Ctrl+O, are not: terminals escape the layer only through
`app.conf`, which depends on a GNOME extension and a running daemon.

### 2. GNOME (`gsettings.sh`)

GNOME's defaults already match macOS for Super+Tab (Cmd+Tab), Super+\`
(Cmd+\`), Super+H (Cmd+H) and the Super tap (Mission Control). They only need
Super to survive keyd, which `[mac:M]` guarantees. `gsettings.sh` binds
Super+Space to the overview (Spotlight), moves the app grid to
Shift+Super+Space because Super+A is select all, and clears the input-source
switcher off Super+Space.

Each key in `[mac:M]` takes GNOME's Super binding for that key. KEYMAP.md lists
those bindings and where each one moved.

Read GNOME's defaults with `dconf read`, not `gsettings get`, which cannot tell
a schema default from a local override.

### 3. Per-app layer (`app.conf`)

Terminals need Cmd+C to send Ctrl+Shift+C, and Emacs needs Ctrl and Option
untranslated. That needs to know which window has focus, which on Wayland only
the compositor knows. keyd's GNOME extension writes the focused window's class
to a FIFO, and `keyd-application-mapper` applies the matching `app.conf`
section to keyd. The extension reports focus and never injects keys. Details
are in [gnome-wayland-bridge.md](../../modules/keybindings/gnome-wayland-bridge.md).

The clipboard is Ctrl+Insert/Shift+Insert rather than Ctrl+C/V. GTK, Qt,
browsers and Electron accept both spellings, so copying never sends Ctrl+C.
Ptyxis accepts neither as a shortcut, so in terminals Cmd+C/V need the per-app
layer.

## Rejected

- **xremap.** It works at the same level as keyd and does per-app matching
  itself, but its key-combo output releases held modifiers around each
  translated key. GNOME then sees Super pressed and released alone and opens
  the overview on every Cmd+C. The workaround, a virtual modifier, breaks
  holding Super for Super+Tab.
- **Toshy, Kinto, gnome-macos-remap-wayland.** Large opinionated stacks that
  are hard to debug or to diverge from. keyd is one small C daemon with an INI
  config that diffs cleanly.
- **GNOME's Emacs `gtk-key-theme`.** By the time a key reaches GTK, keyd has
  turned Cmd+A into a literal Ctrl+A, so a theme binding Ctrl+A catches both
  and select all breaks. A theme limited to keys neither layer uses does
  nothing in practice: GTK4 has no key themes, and Firefox draws its own text
  fields.
- **Ptyxis shortcuts on bare Ctrl.** Binding `select-all` to Ctrl+A would give
  Cmd+A a meaning in the terminal without the per-app layer. But that layer
  hands Ctrl+A back to the shell, and the shortcut would then take it from
  readline and tmux.
- **Terminals binding Super+C themselves.** keyd translates Super+C before
  any app sees it. Leaving it untranslated breaks copy everywhere else.

## Consequences

- Ctrl+C, EOF and readline editing are untouched, locally and over ssh.
- Ctrl+A/E/B/F/P/N/H mean cursor motion in every app. Apps that bound them to
  something else lose those bindings; Ctrl+A's select all is Cmd+A.
- Without the per-app layer, terminals still navigate and Ctrl is still the
  shell's, but Cmd+C/V do nothing there.
- Anything that reads raw keys (games, VMs, remote desktop) sees the
  translated keys. `[ids]` can exclude a device, and an `app.conf` section can
  send a key back unchanged for a window class.
- keyd runs as root and grabs the keyboards. A broken config can lock the
  keyboard out, so keep a second input device or an ssh session while changing
  it.
