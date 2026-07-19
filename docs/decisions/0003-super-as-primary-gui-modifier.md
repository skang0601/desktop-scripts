# 0003 - Super is the GUI modifier; Ctrl is never touched

- Status: accepted
- Date: 2026-07-19

## Context

The whole point of the setup: on macOS, Cmd owns GUI actions (copy, paste, new
tab, quit) and Ctrl owns terminal/Unix semantics (Ctrl+C = SIGINT, Ctrl+D = EOF,
Ctrl+R = reverse search). Linux collapses both onto Ctrl, which is why terminals
had to invent Ctrl+Shift+C to get copy back.

The naive fix -- swapping Ctrl and Super at the hardware level -- reproduces the
mac layout but destroys the property that makes it worth having: the physical
key under your pinky would no longer send SIGINT, breaking every CLI reflex and
every ssh session into a machine that isn't remapped.

## Decision

**Physical Ctrl is left completely unmapped.** Ctrl+C is SIGINT, always,
everywhere, including inside the remapped layer. No exceptions.

**Physical Super gains a layer** that emits GUI shortcuts. Two profiles ship,
because the right trade-off here isn't obvious:

### `whitelist` (default, `keyd/profiles/whitelist.conf`)

Super only intercepts an explicit list of keys (c, v, x, a, z, s, f, t, n, w, r,
q). Everything else -- `Super+Left` to tile, `Super+A` for the app grid,
`Super+1..9` for the dock -- falls through to GNOME untouched.

### `full-swap` (`keyd/profiles/full-swap.conf`)

Super acts as Ctrl for *every* key via a `[mac:C]` modifier layer. Complete mac
muscle memory with nothing to maintain, at the cost of every GNOME Super binding.

Default is `whitelist` because it is strictly additive: nothing that works today
stops working. Switch with `./scripts/install-keyd.sh full-swap`.

## Sub-decisions

**`overload(layer, meta)` rather than `layer(...)`.** A bare
`meta = layer(mac_shortcuts)` means the Super key never emits Super, which kills
the tap-Super-for-Activities gesture that GNOME's `overlay-key` provides.
`overload` sends real Super on tap and enters the layer on hold, keeping both.
Cost is a small hold-vs-tap decision latency; if it feels wrong in practice,
drop back to `layer()` and bind the overview to something else.

**Copy/paste go through `C-insert` / `S-insert`, not `C-c` / `C-v`.**
Ctrl+Insert and Shift+Insert are honoured by GTK, Qt, and terminal emulators
alike, which means `Super+C` copies correctly in a terminal *without* needing to
know it's a terminal. This makes the setup degrade gracefully: if the
application-awareness layer (0004) is broken or not yet installed, copy/paste
still does the right thing everywhere. It is the single highest-value line in
the config.

## Consequences

- Ctrl-based CLI reflexes and remote ssh sessions are unaffected.
- `whitelist` needs a config edit whenever a new Cmd+key reflex turns up missing.
- Anything that reads raw modifier state (games, VMs, remote desktop) sees the
  remapped keys. keyd's `[ids]` section can exclude specific devices if needed.
