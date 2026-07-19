# 0004 - Application-aware terminal layer via a GNOME compositor bridge

- Status: proposed
- Date: 2026-07-19

## Context

`Super+C` should copy in Firefox and should send `Ctrl+Shift+C` in a terminal,
because that is what terminals accept for copy. Deciding between those two
requires knowing which window has focus -- and keyd, sitting at the evdev layer
(0002), is structurally blind to that. It sees keycodes, not windows.

On X11 this was trivial: `keyd-application-mapper` polls the X server for the
active window's WM_CLASS. Wayland deliberately removes that capability -- no
client may ask the compositor what another client is doing, because that is
exactly the keylogging surface Wayland was designed to close. There is no
protocol an unprivileged process can use to read the focused window's app ID.

So the information has to come *from* the compositor, from code the compositor
trusts. Under GNOME that means a GNOME Shell extension, which runs inside
Mutter's process and can read `global.display.focus_window` directly.

Terminals on this machine: Ptyxis (`org.gnome.Ptyxis`, Fedora's default since
41) and foot (`foot`).

## Decision

Three moving parts:

1. `/etc/keyd/default.conf` -- the base layer (0003), compositor-independent.
2. `~/.config/keyd/app.conf` -- per-application overrides, checked into this
   repo as `keyd/app.conf`.
3. A GNOME Shell extension that pushes the focused window's app ID to the
   `keyd-application-mapper` user daemon.

Status is **proposed**, not accepted: part 3 depends on an extension being
compatible with GNOME Shell 50, which is a fast-moving target. See
`docs/gnome-wayland-bridge.md` for the current state and the fallback.

## Why not solve it inside the terminal instead

A real alternative: skip application awareness entirely and configure each
terminal to accept `Ctrl+Insert`/`Shift+Insert` for copy/paste -- which Ptyxis
and foot already do. That is precisely why 0003 maps `Super+C` to `C-insert`
rather than `C-c`. **The base layer already works correctly in terminals with
no bridge at all.**

The bridge therefore buys refinement, not function: per-app tweaks like
`Super+K` clearing the scrollback, or dropping the mac layer entirely inside a
VM or a remote-desktop window. It is explicitly not a prerequisite for a working
setup, and if GNOME 50 extension support turns out to be broken, nothing
essential is lost.

## Consequences

- The bridge is a GNOME-only, extension-shaped dependency that will break on
  major Shell releases. Keeping it non-load-bearing is the mitigation.
- `keyd-application-mapper` is a per-user daemon and needs a systemd user unit
  to survive login; it is not started by `keyd.service`.
- Adding a new terminal means adding a section to `keyd/app.conf`.
