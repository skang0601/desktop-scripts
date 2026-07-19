# 0002 - Use keyd as the remapping layer

- Status: accepted
- Date: 2026-07-19

## Context

Target environment is Fedora 44 Workstation, GNOME Shell 50, Wayland.

Wayland removed the X11 escape hatches that keyboard remappers historically
relied on: there is no global `XGrabKey`, no `xdotool`-style synthetic input
into other clients, and no way for an unprivileged client to read the focused
window. Anything that worked by talking to the X server is out.

Options considered:

| Option | Verdict |
| --- | --- |
| `xremap` | Works at evdev like keyd; Rust, heavier; GNOME window awareness also needs a shell extension. Viable runner-up. |
| `keyd` | evdev-level, C, tiny, runs as a system daemon, config is plain INI. Chosen. |
| GNOME `gsettings` / dconf shortcuts | Only rebinds GNOME's own actions; cannot touch in-app shortcuts like Ctrl+C. Insufficient alone. |
| `Toshy` | Full macOS-emulation suite (`xwaykeyz`). Very capable but a large Python stack with its own service model; opaque to debug. Tried previously, set aside. |
| `gnome-macos-remap-wayland` | Shell-script wrapper around `xremap` + dconf. Tried previously; opinionated, hard to diverge from. Set aside. |

## Decision

Use `keyd`. It intercepts at the kernel evdev layer, below both X11 and Wayland,
so the compositor is irrelevant to the core remapping. It is a single C daemon
with no runtime dependencies and an INI config that diffs cleanly in git.

Install from COPR `alternateved/keyd` -- keyd is not packaged in Fedora proper,
and that COPR is confirmed to build for `fedora-44-x86_64`.

## Consequences

- Remapping happens before any application sees the key, so it works uniformly
  in GTK, Qt, Electron, and TTYs.
- Requires root: keyd runs as a system service reading `/dev/input/event*`. A
  broken config can lock out the keyboard -- keep a second input device or an
  SSH session available while iterating.
- keyd's evdev position is also its blind spot: it cannot see which window is
  focused. That gap is what 0004 addresses.
- Depending on a COPR means the build can lag a Fedora release. Fallback is
  `make && sudo make install` from source; keyd has no build deps beyond a
  C compiler.
