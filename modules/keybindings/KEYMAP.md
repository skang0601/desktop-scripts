# Keymap contract

What each key does on this desktop, with macOS as the reference. Whatever
remapper implements it -- keyd today, see [ADR 0002](../../docs/decisions/0002-macos-keybindings.md)
-- it is measured against this file, and a change to the behaviour is a change
here first.

## Principles

1. **Cmd (Super) owns GUI actions.** Copy, paste, select all, undo, find, save,
   tabs, windows. Linux apps hardcode Ctrl for these, so Cmd+X is translated
   into whatever spelling of Ctrl+X the focused app listens for.
2. **Ctrl owns text navigation, Emacs-style, as in macOS's Cocoa text system.**
   macOS gives every text field Emacs motions from AppKit's
   `StandardKeyBinding.dict`; this layer reproduces the subset listed below.
3. **Ctrl+C is SIGINT, always.** In terminals, ssh, TUIs and REPLs Ctrl reaches
   the program verbatim. Nothing in this contract may break that, including
   when the per-application layer is down.
4. **GNOME keeps the Super bindings macOS already agrees with.** Cmd+Tab,
   Cmd+\`, Cmd+H, and a Super tap for the overview are GNOME defaults and stay
   GNOME's.

Principle 3 decides every conflict between the others.

## Cmd -- GUI actions, everywhere but terminals and Emacs

| Keys | macOS meaning | Sent to the app | Status |
| --- | --- | --- | --- |
| Cmd+C | Copy | Ctrl+Insert | done |
| Cmd+V | Paste | Shift+Insert | done |
| Cmd+X | Cut | Shift+Delete | done |
| Cmd+A | Select all | Ctrl+A | done |
| Cmd+Z | Undo | Ctrl+Z | done |
| Shift+Cmd+Z | Redo | Ctrl+Shift+Z | done (held Shift passes through) |
| Cmd+S | Save | Ctrl+S | done |
| Cmd+F | Find | Ctrl+F | done |
| Cmd+T | New tab | Ctrl+T | done |
| Shift+Cmd+T | Reopen closed tab | Ctrl+Shift+T | done |
| Cmd+N | New window/document | Ctrl+N | done |
| Cmd+W | Close tab/window | Ctrl+W | done |
| Cmd+R | Reload | Ctrl+R | done |
| Cmd+Q | Quit | Ctrl+Q | done; Ctrl+Q is a convention, not a guarantee |
| Cmd+G / Shift+Cmd+G | Find next/previous | Ctrl+G / Ctrl+Shift+G | not mapped |
| Cmd+O | Open | Ctrl+O | not mapped |
| Cmd+P | Print | Ctrl+P | not mapped; Super+P is GNOME's display switcher |
| Cmd+L | Address bar | Ctrl+L | not mapped; Super+L is GNOME's lock screen |

The clipboard uses the Insert spellings so that Ctrl+C itself is never sent
for copy: GTK, Qt, Electron and browsers accept both, and a stray Ctrl+C in a
terminal is SIGINT.

Every Cmd+key in the table is a Super binding removed from GNOME. A row moves
from "not mapped" to "done" only after checking it does not take a GNOME
binding worth more (`gsettings list-recursively | grep -i super`).

## Ctrl -- Emacs navigation

Reference: AppKit's `StandardKeyBinding.dict`, plus Apple's text-editing
shortcuts.

| Keys | macOS (Cocoa) | Here | Status |
| --- | --- | --- | --- |
| Ctrl+A | Beginning of line/paragraph | Home | done |
| Ctrl+E | End of line/paragraph | End | done |
| Ctrl+B | Back one character | Left | done |
| Ctrl+F | Forward one character | Right | done |
| Ctrl+P | Previous line | Up | done |
| Ctrl+N | Next line | Down | done |
| Ctrl+D | Delete forward | -- | not mapped: EOF in a terminal |
| Ctrl+H | Delete backward | -- | not mapped: backspace in a terminal already |
| Ctrl+K | Kill to end of paragraph | -- | not mapped: needs a kill buffer separate from the clipboard |
| Ctrl+Y | Yank the kill buffer | -- | not mapped, with Ctrl+K |
| Ctrl+T | Transpose characters | -- | not mapped: no GUI equivalent |
| Ctrl+O | Open line | -- | not mapped |
| Ctrl+V | Page down | -- | not mapped: literal-next in a terminal |
| Ctrl+L | Centre selection | -- | not mapped: clear screen in a terminal |

The rule for this layer: **a Ctrl key is mapped only if its mapping is harmless
in a terminal.** The per-app layer is what gives terminals Ctrl back verbatim,
and it can be down -- a GNOME upgrade, a crashed mapper. Home, End and the
arrows are harmless if a terminal receives them. Delete instead of Ctrl+D, or
PageDown instead of Ctrl+V, is not. In a terminal the shell's readline supplies
Ctrl+D/H/K/Y/T itself, so the unmapped keys work there anyway.

**Shift+Ctrl+A/E/B/F/P/N pass through unchanged** as Ctrl+Shift+key. macOS
uses them to extend the selection. Here they stay as they are because Linux
apps bind Ctrl+Shift+key heavily: Ctrl+Shift+T reopens a tab, Ctrl+Shift+P
opens a command palette, Ctrl+Shift+F searches a project. Selection works with
Shift+Home/End and Shift+arrows.

Ctrl alone, and Ctrl with any key not in this table, reaches the app unchanged.

## Not mapped, by design

| Keys | macOS meaning | Why not |
| --- | --- | --- |
| Cmd+Left/Right | Line start/end | GNOME tiles windows with Super+Left/Right |
| Cmd+Up/Down | Document start/end | GNOME maximizes/restores with Super+Up/Down |
| Option+Left/Right | Word left/right | Ctrl+Left/Right already does it; Alt+Left is "back" in browsers |
| Option+Delete | Delete word | Ctrl+Backspace already does it; Alt+Backspace is readline's word rub-out |
| Ctrl+Cmd+Q | Lock screen | Super+L |

## Terminals (Ptyxis, foot)

| Keys | Sent | Why |
| --- | --- | --- |
| Ctrl+anything | verbatim | Principle 3; the nav layer is lifted |
| Cmd+C / Cmd+V | Ctrl+Shift+C / V | the terminal clipboard |
| Cmd+T / N / W | Ctrl+Shift+T / N / W | tabs and windows |
| Cmd+F | Ctrl+Shift+F (Ptyxis), Ctrl+Shift+R (foot) | search |
| Cmd+A | Ctrl+Shift+A | select all |

## Emacs

Ctrl is Emacs's own, verbatim. Cmd+key becomes Meta+key (`M-c`, `M-v`, ...),
which the Emacs config binds to its macOS-style meanings.

## GNOME

| Keys | Action | Source |
| --- | --- | --- |
| Super (tap) | Overview | GNOME default (`overlay-key`) |
| Super+Space | Overview / search | `gsettings.sh` (macOS Spotlight) |
| Shift+Super+Space | App grid | `gsettings.sh`; Super+A is select all |
| Super+Tab | Switch apps | GNOME default (macOS Cmd+Tab) |
| Super+\` | Switch windows of an app | GNOME default (macOS Cmd+\`) |
| Super+H | Hide (minimize) | GNOME default (macOS Cmd+H) |

## Requirements on the implementation

These come from the contract, not from keyd:

- **A Super tap must reach GNOME as a clean Super press and release, and Cmd+key
  must not.** A remapper that releases Super around each translated key makes
  GNOME see a lone tap and open the overview on every Cmd+C. keyd's `layer()`
  holds Super back until a key needs it. xremap's key-combo output releases and
  re-presses held modifiers, so it has exactly that problem on GNOME.
- **Held Super must survive for unmapped keys,** so Super+Tab can be held and
  cycled.
- **Ctrl+C is never mapped,** so no failure of the remapper can turn it into
  something else.

## References

- Apple, [Mac keyboard shortcuts](https://support.apple.com/102650):
  Cmd shortcuts and text-editing shortcuts.
- Apple, [Text System Defaults and Key Bindings](https://developer.apple.com/library/mac/documentation/cocoa/conceptual/eventoverview/TextDefaultsBindings/TextDefaultsBindings.html),
  and a [dump of `StandardKeyBinding.dict`](https://gist.github.com/hym3242/8e8bc10a2fed8e55973c500f1798c234):
  the Ctrl bindings.
- [Kinto](https://github.com/rbreaves/kinto) and [Toshy](https://github.com/RedBearAK/toshy):
  per-app macOS keymaps for Linux, the most complete prior work; ADR 0002 says
  why they are not used here.
- [Omarchy discussion #175](https://github.com/omacom/omarchy/discussions/175):
  the same keyd, application-mapper and terminal-exception design on Hyprland.
