# 0002 - macOS-style keybindings on GNOME/Wayland

- Status: accepted
- Date: 2026-07-19
- Supersedes: earlier split ADRs on tool choice, modifier layout, and the
  terminal exception; those were three views of one decision.

## Context

macOS splits modifier duty: Cmd owns GUI actions (copy, paste, new tab, quit),
Ctrl owns Unix semantics (SIGINT, EOF, reverse-search, Emacs line editing).
Linux collapses both onto Ctrl, which is why terminals had to invent
Ctrl+Shift+C to get copy back. The goal is to recover the split.

Environment is GNOME on Wayland. The distro is not load-bearing; GNOME is.

## The load-bearing constraint

**Ctrl+C is SIGINT in every terminal, ssh session, TUI and REPL, and nothing
here may endanger that.** Everything else is negotiable, this is not.

This is what rules out the obvious approach. Swapping Ctrl and Super at the
hardware level reproduces the macOS *layout*, but destroys the property that
makes the layout worth having.

The constraint governs Ctrl+C and the shell's editing keys, not the Ctrl
modifier wholesale. Ctrl carries an emacs navigation layer (see Layer 1),
because "Ctrl owns Emacs line editing" is half of the split this ADR exists to
recover -- a Ctrl that does nothing is not the macOS behaviour, just an absence.
The layer is scoped so the constraint holds by construction: `[nav:C]` leaves
every unlisted key carrying Ctrl, so Ctrl+C is never a mapped key at all.

## Super is not Cmd for free

The tempting framing is "make Super a genuinely separate modifier like Cmd, and
bind everything to it." That cannot work for in-application shortcuts. GTK, Qt,
Electron and web apps hardcode Ctrl+C for copy. There is no global switch that
makes Firefox listen for Super+C, and rebinding every shortcut in every app is
not a project, it is a hobby.

So Super+X must be **translated** into the Ctrl+X the app is already listening
for. That translation is the actual work, and it is the same mechanism as the
terminal special-case -- not a separate feature.

Where the translation can live is decided by Wayland: there is no `XGrabKey`,
and no client may inject synthetic keys into another client. Anything built on
"query the focused window, then send a keystroke" is dead on arrival. What still
works is remapping *below* the display server, at the kernel evdev layer, which
is what `keyd` does -- it grabs the real keyboard and re-emits through uinput,
so the compositor is irrelevant to the emission path.

`xremap` occupies the same layer and was the runner-up. `Toshy` and
`gnome-macos-remap-wayland` were both tried previously and set aside: capable,
but large opinionated stacks that are hard to debug or diverge from. keyd is one
small C daemon with an INI config that diffs cleanly in git.

## Decision

### Layer 1 - keyd, `/etc/keyd/default.conf`

```
[main]
meta    = layer(mac)
control = layer(nav)

[mac:M]
c = C-insert
...

[nav:C]
a = home
b = left
...
```

**Navigation belongs in keyd, not in GNOME's Emacs `gtk-key-theme`.** The theme
is the obvious route and cannot work: by the time a key reaches GTK, the `mac`
layer has already rewritten `Super+A` into a literal `Ctrl+A`, so the theme
captures both spellings and `Super+A` stops selecting all. Cmd and Ctrl are
distinguishable on macOS because they are genuinely different modifiers; here
they are collapsed by construction, and only keyd -- upstream of the collapse --
can tell them apart. The theme is also GTK3-only, so it is inert in the GTK4
apps that make up most of GNOME 49.

**Text editing comes from a custom gtk-key-theme, not the nav layer.**
`Ctrl+D/H/K/U/Y` and the Alt word-wise set live in `gtk-keys/MacEmacs`, linked
into `~/.themes`. GNOME's stock `Emacs` theme cannot be used: it binds
`<ctrl>a/e/f/n/w`, exactly what the mac layer emits for `Cmd+A/E/F/N/W`, so it
breaks select-all, find and close in every GTK3 text field. `MacEmacs` binds
only keys neither keyd layer claims.

Doing it in the theme rather than in keyd removes the Layer 3 dependency
entirely: the selectors match `entry` and `textview`, and a terminal draws in a
VTE widget, so `Ctrl+D` stays EOF in a shell with no per-app exemption. The
price is reach -- GTK4 dropped key themes, so this covers GTK3 apps only, and
Flatpak apps need `~/.themes` mounted. Motion keys stay in keyd, where they
work in every toolkit.

**The `nav` layer holds only keys that are safe in a terminal without Layer 3.**
`a`, `e`, `b`, `f`, `p`, `n` become Home, End and the arrows. `d`, `h`, `k`,
`w`, `u` and `y` stay out: they are EOF and readline editing, and a terminal
escapes the layer only via `app.conf`, which depends on the fragile Layer 3.
Anything in the layer has to be survivable when that daemon is down. Home and
the arrows are; Delete is not.

Four details of keyd 2.6.0 that the config depends on:

**Comments cannot follow a binding.** keyd has no trailing-comment syntax and
takes the rest of the line as the action, so `c = C-insert  # copy` is an
invalid action and the binding is dropped. `keyd check` calls this a `WARNING`
and exits 0, so an entire layer can be inert while the config validates. The
installer treats any warning as fatal and checks the repo copy before installing
it, so a config that lost its bindings this way cannot reach `/etc`.

**`layer()` is the only workable form.** keyd special-cases an isolated tap of a
layer key and emits a clean meta down/up pair, so tap-Super still opens
Activities. `overload()` cannot substitute: `meta` is a left-hand-side alias
rather than a key name, so `overload(mac, meta)` does not parse, and
`overload(mac, leftmeta)` is silently rewritten to `layer(meta)`, which never
opens the overview.

**The `:M` on `[mac:M]` is load-bearing.** In a modifier layer, keys with no
explicit mapping are emitted *with that modifier applied*, so `Super+Tab` still
reaches GNOME as Super+Tab. A plain `[mac]` drops Super and emits a bare Tab,
breaking every GNOME Super binding.

**Explicit bindings ignore the layer's own modifier, but not physically held
ones.** `c = C-insert` inside `[mac:M]` emits Ctrl+Insert, not
Super+Ctrl+Insert, while a held Shift passes through -- so `Super+Shift+T` gives
`Ctrl+Shift+T`, and multi-modifier chords need no extra configuration.

### Layer 2 - GNOME, mostly already done

Most of GNOME's defaults are already macOS-shaped, which makes Layer 2 far
smaller than it looks:

| Binding | Stock GNOME default? | macOS equivalent |
| --- | --- | --- |
| `switch-applications` = `<Super>Tab` | yes | Cmd+Tab |
| `switch-group` = `<Super>Above_Tab` | yes | Cmd+\` |
| `minimize` = `<Super>h` | yes | Cmd+H |
| `overlay-key` = `Super` (tap) | yes | Mission Control |
| `toggle-overview` = `<Super>space` | **no -- unbound by default** | Cmd+Space / Spotlight |

The first four need no configuration at all; they only need Super to *survive*
keyd, which is what `[mac:M]` guarantees.

`toggle-overview` is the exception: its schema default is `@as []`, unbound.
Stock GNOME reaches the overview via the Super *tap* (`overlay-key`), not
Super+Space, so `Super+Space` for Spotlight is a change `gsettings.sh` makes
rather than something inherited.

Keys left out of the keyd layer so GNOME can have them: `tab`, `` ` ``, `space`,
`h`.

Establish such defaults with `dconf read`, not `gsettings get`. `gsettings get`
returns a user override indistinguishably from a schema default, so a setup
script written by reading one machine's output will encode that machine's
accidents as though they were universal.

One real collision remains: `Super+A` is GNOME's app grid and is also Cmd+A
select-all. Select-all wins -- it is used hundreds of times a day. Any key
present in the layer is fully consumed from GNOME (including with Shift held),
so the app grid must move to a key that is *not* in the layer.
`modules/keybindings/gsettings.sh` moves it to `<Shift><Super>space`, which keeps a tidy
parallel: Super+Space is Spotlight, Super+Shift+Space is Launchpad.

### Layer 3 - keyd-application-mapper + GNOME extension

Terminals need `Super+C` to mean Ctrl+Shift+C, not Ctrl+C. That needs focus
awareness, which on Wayland only the compositor has. keyd's answer:
`keyd-application-mapper` reads `~/.config/keyd/app.conf`, and a GNOME Shell
extension **bundled in the keyd repo** feeds it the focused window's class over
a FIFO.

The division of labour is what makes this Wayland-legal: the extension only
*reports focus* and never injects keys, while keyd does the emission in the
kernel, where Wayland's restrictions don't apply.

The bundled extension declares support through GNOME 49 and not 50. See
`modules/keybindings/gnome-wayland-bridge.md` for the workaround.

### Layer 4 - terminal config

Considered and rejected. The proposal is to let terminals bind Super+C natively
and skip the special-case entirely. It cannot work here: if keyd maps `c` in the layer, the terminal never
sees Super+C. To let it through, `c` would have to be unmapped -- and then
Super+C does nothing in every GUI app. The two requirements are mutually
exclusive without focus awareness, which is exactly why Layer 3 exists.

The choice of `C-insert`/`S-insert` over `C-c`/`C-v` for the clipboard buys
this in GUI apps: GTK4 binds both spellings, so Super+C copies while Ctrl+C
stays SIGINT.

It buys nothing in a terminal. Ptyxis ignores both Insert forms as
accelerators, so Super+C and Super+V do nothing there; rebinding
`copy-clipboard` to `<ctrl>Insert` was tried and does not work. The terminal
clipboard is `Ctrl+Shift+C`/`V`, reached by pressing those keys physically.
There is no Super spelling for it without Layer 3, and this design has no
fallback that changes that.

Where a terminal *can* be met halfway is its other accelerators. Ptyxis exposes
them as gsettings, and the nav layer makes several bare-Ctrl spellings
unreachable from the keyboard -- physical Ctrl+A, Ctrl+F and Ctrl+N become
Home, Right and Down -- so binding `select-all`, `search` and `new-window` to
them gives Super+A/F/N a meaning in the terminal that nothing else can trigger.
That is Layer 2 doing Layer 3's job for the subset of apps that expose their
own keymap, and it survives a GNOME upgrade in a way the extension does not.

## Consequences

- Ctrl+C, EOF and readline editing are untouched, in local terminals and remote
  ssh sessions alike.
- Ctrl+A/E/B/F/P/N no longer reach applications that bound them to something
  else. In a shell they are the readline motions they already were; elsewhere
  Ctrl+A most commonly meant select-all, which now lives on Super+A only.
- Terminals rely on Layer 3 to get Ctrl+A/E/B/F/P/N back verbatim. Without it
  they still navigate, which is survivable, but a tmux prefix on Ctrl+A needs
  either the extension working or that key dropped from the layer.
- Layer 1 alone is a usable setup. Layers 2-3 are refinements, and the design
  degrades in that order rather than collapsing.
- A key added to the layer is a GNOME Super binding removed. That trade is made
  once per key, deliberately.
- `Super+Q` is app-dependent: Ctrl+Q is a convention, not a guarantee, and some
  apps implement no quit accelerator. Alt+F4 remains the reliable close.
- Electron and Chromium apps handle accelerators idiosyncratically and are worth
  testing individually (VS Code, browsers, Slack).
- Anything reading raw modifier state -- games, VMs, remote desktop -- sees the
  remapped keys. keyd's `[ids]` section can exclude devices; an `app.conf`
  section can rebind keys back to their `M-` originals per window class.
- keyd needs root and grabs the keyboard. A bad config can lock you out; keep a
  second input device or an ssh session open while iterating.
