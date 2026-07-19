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

**Physical Ctrl is never remapped.** Ctrl+C is SIGINT in every terminal, ssh
session, TUI and REPL; Ctrl+A/E/K keep editing lines. Everything else here is
negotiable, this is not.

This is also what rules out the obvious approach. Swapping Ctrl and Super at the
hardware level reproduces the macOS *layout*, but destroys the property that
makes the layout worth having.

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
meta = layer(mac)

[mac:M]
c = C-insert
...
```

Three details, each verified against keyd 2.6.0 rather than assumed:

**`layer()`, not `overload()`.** `meta = overload(mac, meta)` does not parse --
`meta` is a left-hand-side alias, not a key name, and `keyd check` rejects it.
`overload(mac, leftmeta)` parses but keyd silently rewrites the tap action to
`layer(meta)`, which never opens the overview. Plain `layer()` is correct
regardless: keyd special-cases an isolated tap of a layer key and emits a clean
meta down/up pair, so tap-Super still opens Activities.

**`[mac:M]`, not `[mac]`.** In a modifier layer, keys with no explicit mapping
are emitted *with that modifier applied*. So `Super+Tab` still reaches GNOME as
Super+Tab. A plain `[mac]` would drop Super and emit a bare Tab, silently
breaking every GNOME Super binding. This is the single most important character
in the file.

**Explicit bindings ignore the layer's own modifier**, but not physically held
ones. `c = C-insert` inside `[mac:M]` emits exactly Ctrl+Insert, not
Super+Ctrl+Insert. Holding Shift as well passes through, so `Super+Shift+T`
correctly becomes `Ctrl+Shift+T` rather than `Ctrl+T` -- the multi-modifier
chord case works without extra configuration.

### Layer 2 - GNOME, mostly already done

Most of GNOME's defaults are already macOS-shaped, which is easy to miss and
means Layer 2 is far smaller than it looks:

| Binding | Stock GNOME default? | macOS equivalent |
| --- | --- | --- |
| `switch-applications` = `<Super>Tab` | yes | Cmd+Tab |
| `switch-group` = `<Super>Above_Tab` | yes | Cmd+\` |
| `minimize` = `<Super>h` | yes | Cmd+H |
| `overlay-key` = `Super` (tap) | yes | Mission Control |
| `toggle-overview` = `<Super>space` | **no -- unbound by default** | Cmd+Space / Spotlight |

The first four need no configuration at all; they only need Super to *survive*
keyd, which is what `[mac:M]` guarantees.

`toggle-overview` is the exception and was initially mis-recorded here as a
default. Checking `dconf read` rather than `gsettings get` -- the latter happily
returns a user override -- shows the schema default is `@as []`, i.e. unbound.
Stock GNOME reaches the overview via the Super *tap* (`overlay-key`), not
Super+Space. So `Super+Space` for Spotlight is a real change `gsettings.sh` has
to make, not something inherited.

Keys deliberately left out of the keyd layer so GNOME can have them: `tab`,
`` ` ``, `space`, `h`.

The general lesson, worth repeating for any future module: read `dconf read` to
tell a default from a local customization. `gsettings get` cannot distinguish
them, and a setup script built by reading one machine's `gsettings get` output
will quietly encode that machine's accidents as though they were universal.

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

Note the division of labour, which is what makes this Wayland-legal: the
extension only *reports focus*. It never injects keys -- keyd does the emission,
in the kernel, where Wayland's restrictions don't apply.

Status caveat: the bundled extension declares support through GNOME 49 and not
50. See `modules/keybindings/gnome-wayland-bridge.md` for the workaround and current state.

### Layer 4 - terminal config

Not used, and worth recording why, because it looks attractive.

The proposal is to let terminals bind Super+C natively and skip the special-case
entirely. It cannot work here: if keyd maps `c` in the layer, the terminal never
sees Super+C. To let it through, `c` would have to be unmapped -- and then
Super+C does nothing in every GUI app. The two requirements are mutually
exclusive without focus awareness, which is exactly why Layer 3 exists.

What *does* buy graceful degradation is the choice of `C-insert`/`S-insert` over
`C-c`/`C-v` for the clipboard. GTK4 binds both spellings, and many terminals
accept the Insert forms too, so `Super+C` has a good chance of copying correctly
in a terminal with no Layer 3 at all. Treat that as a cushion, not a guarantee:
**verify it in your actual terminals**, and if it fails, that terminal needs an
`app.conf` section and therefore a working extension.

## Consequences

- Ctrl reflexes and remote ssh sessions are untouched.
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
