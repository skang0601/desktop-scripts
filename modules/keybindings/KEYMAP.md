# Keymap contract

What every key does on this desktop. The reference is Apple's
[Mac keyboard shortcuts](https://support.apple.com/102650) article, its
"common" and "text-editing" sections, which describe current macOS. Every
shortcut in those two sections appears below, either adopted or listed as a
deviation with its reason. Change this file first and the config second.

keyd implements it ([ADR 0002](../../docs/decisions/0002-macos-keybindings.md)):
`default.conf` for every app, `app.conf` for terminals and Emacs.

## Rules

1. **Cmd is Super, Option is Alt, Control is Ctrl.** These are the physical
   keys on a PC keyboard; on the HHKB, Super sits beside the space bar.
2. **Cmd does what it does on a Mac.** Linux apps listen for Ctrl, so keyd
   translates Cmd+X into the Ctrl+X the app expects.
3. **Ctrl moves the cursor Emacs-style,** as in any macOS text field.
4. **Ctrl+C is SIGINT, always.** Terminals get Ctrl verbatim. A mapping is only
   allowed if it stays harmless in a terminal when the per-app layer is down,
   because that layer depends on a GNOME extension and a running daemon.
5. **GNOME keeps the Super bindings macOS agrees with,** and the ones that
   collide with a Mac shortcut move somewhere Mac-like.

Rule 4 overrides the others.

## Common shortcuts

| macOS | Meaning | Here | |
| --- | --- | --- | --- |
| Cmd+X / C / V | Cut, copy, paste | Shift+Delete, Ctrl+Insert, Shift+Insert | ✓ |
| Cmd+Z, Shift+Cmd+Z | Undo, redo | Ctrl+Z, Ctrl+Shift+Z | ✓ |
| Cmd+A | Select all | Ctrl+A | ✓ |
| Cmd+F | Find | Ctrl+F | ✓ |
| Cmd+G, Shift+Cmd+G | Find next, previous | Ctrl+G, Ctrl+Shift+G | ✓ |
| Cmd+H | Hide the app | GNOME minimize (Super+H) | ✓ minimizes the window, not the app |
| Option+Cmd+H | Hide other apps | -- | ✗ GNOME has no equivalent |
| Cmd+M | Minimize | Super+H | ✓ |
| Option+Cmd+M | Minimize all of the app's windows | -- | ✗ no equivalent |
| Cmd+O | Open | Ctrl+O | ✓ |
| Cmd+P | Print | Ctrl+P | ✓ |
| Cmd+Q | Quit | Ctrl+Q | ✓ Ctrl+Q is a convention, not a guarantee; Alt+F4 always closes |
| Cmd+S, Shift+Cmd+S | Save, Save As | Ctrl+S, Ctrl+Shift+S | ✓ |
| Cmd+T | New tab | Ctrl+T | ✓ |
| Cmd+W | Close window/tab | Ctrl+W | ✓ |
| Option+Cmd+W | Close all of the app's windows | -- | ✗ no equivalent |
| Option+Cmd+Esc | Force quit | -- | ✗ no GNOME shortcut |
| Cmd+Space | Spotlight | GNOME overview search | ✓ |
| Ctrl+Cmd+Space | Emoji and symbols | Ctrl+. (GTK emoji chooser) | ✓ GTK apps only |
| Ctrl+Cmd+F | Full screen | F11 | ✓ |
| Space | Quick Look | Space (Nautilus, via Sushi) | ✓ |
| Cmd+Tab | Switch apps | GNOME default | ✓ |
| Cmd+\` | Switch the app's windows | GNOME default | ✓ |
| Shift+Cmd+3 | Screenshot of the screen | Shift+Print | ✓ |
| Shift+Cmd+4, Shift+Cmd+5 | Screenshot or recording of a selection | Print (GNOME's screenshot UI) | ✓ |
| Shift+Cmd+N | New folder | Ctrl+Shift+N | ✓ |
| Ctrl+Cmd+N | New folder with the selection | -- | ✗ no equivalent |
| Cmd+, | Settings | Ctrl+, | ✓ where the app has it |
| Fn+Q | Quick Note | -- | ✗ no equivalent |
| Ctrl+Cmd+Q | Lock screen | Super+L | ✓ |
| Shift+Cmd+? | Help | F1 | ✓ |

Not in Apple's article, but standard in Safari and Chrome, and needed here:

| macOS | Meaning | Here | |
| --- | --- | --- | --- |
| Cmd+[ / Cmd+] | Back, forward | Alt+Left, Alt+Right | ✓ Alt+arrows are word motion now |
| Cmd+= / Cmd+- / Cmd+0 | Zoom in, out, reset | Ctrl+= / Ctrl+- / Ctrl+0 | ✓ |
| Cmd+L | Address bar | Ctrl+L | ✓ |

## Text editing

Apple's note applies here too: what a shortcut does can vary by app.

| macOS | Meaning | Here | |
| --- | --- | --- | --- |
| Cmd+B / I / U | Bold, italic, underline | Ctrl+B / I / U | ✓ |
| Cmd+K | Add a link | Ctrl+K | ✓ |
| Cmd+T | Fonts window | -- | ✗ Cmd+T is new tab |
| Cmd+D | Desktop folder in a file dialog | -- | ✗ Ctrl+D is EOF; see rule 4 |
| Ctrl+Cmd+D | Look up the word | -- | ✗ no equivalent |
| Shift+Cmd+: , Cmd+; | Spelling and grammar | -- | ✗ app-specific |
| Option+Delete | Delete word backward | Ctrl+Backspace | ✓ |
| Ctrl+H | Delete backward | Backspace | ✓ |
| Ctrl+D | Delete forward | -- | ✗ EOF in a terminal (rule 4) |
| Fn+Delete | Forward delete | the keyboard's own Delete | ✓ HHKB Fn+BS |
| Ctrl+K | Cut to end of paragraph into a private kill buffer | -- | ✗ needs a buffer separate from the clipboard; readline and Emacs have their own |
| Ctrl+Y | Paste the kill buffer | -- | ✗ with Ctrl+K |
| Fn+Up / Fn+Down | Page up, page down | the keyboard's own PgUp/PgDn | ✓ |
| Fn+Left / Fn+Right | Document start, end | the keyboard's own Home/End | ✓ in apps where Home/End go that far; Cmd+Up/Down always do |
| Cmd+Up / Cmd+Down | Document start, end | Ctrl+Home, Ctrl+End | ✓ |
| Cmd+Left / Cmd+Right | Line start, end | Home, End | ✓ |
| Option+Left / Option+Right | Previous, next word | Ctrl+Left, Ctrl+Right | ✓ |
| Shift+ any of the six above | Extend the selection | the same with Shift | ✓ |
| Shift+arrows | Extend the selection by character or line | unchanged | ✓ |
| Option+Shift+Up / Down | Extend to paragraph start, end | Ctrl+Shift+Up / Down | ✓ GTK and browsers |
| Ctrl+A / Ctrl+E | Line start, end | Home, End | ✓ |
| Ctrl+F / Ctrl+B | Forward, back one character | Right, Left | ✓ |
| Ctrl+P / Ctrl+N | Up, down one line | Up, Down | ✓ |
| Ctrl+L | Center the selection | -- | ✗ no equivalent; clear-screen in a terminal |
| Ctrl+O | Insert a line after the cursor | -- | ✗ would send Enter to a terminal (rule 4) |
| Ctrl+T | Swap characters | -- | ✗ no GUI equivalent; readline has it |
| Cmd+{ / Cmd+} / Shift+Cmd+\| | Align left, right, center | -- | ✗ app-specific |
| Option+Cmd+F | Go to the search field | -- | ✗ app-specific |
| Option+Cmd+T | Toggle the toolbar | -- | ✗ app-specific |
| Option+Cmd+C / V | Copy, paste style | -- | ✗ app-specific |
| Option+Shift+Cmd+V | Paste and match style | Ctrl+Shift+V | ✓ browsers and Electron |
| Option+Cmd+I | Inspector | -- | ✗ app-specific |
| Shift+Cmd+P | Page setup | Ctrl+Shift+P | passes through; usually a command palette |
| Shift+Cmd+- / Shift+Cmd++ | Smaller, bigger | Ctrl+- / Ctrl+= | ✓ as zoom |

Also mapped, from macOS's text system rather than the article:

| macOS | Meaning | Here |
| --- | --- | --- |
| Cmd+Delete | Delete to line start | Shift+Home, then Backspace |
| Option+Fn+Delete | Delete word forward | Ctrl+Delete |
| Option+Up / Down | Paragraph start, end | Ctrl+Up / Down |

**Shift+Ctrl+A/E/B/F/P/N pass through as Ctrl+Shift+key.** On a Mac they
extend the selection. Linux apps use Ctrl+Shift heavily (reopen tab, command
palette, find in project), so those keys stay with the apps. Shift+Cmd+arrows
and Shift+Option+arrows select instead.

**Ctrl alone, and Ctrl with any key not listed,** reaches the app unchanged.

## GNOME shortcuts that moved

Cmd+key takes the Super+key binding GNOME had. These moved:

| GNOME default | Taken by | Now |
| --- | --- | --- |
| Super+Left/Right (tile) | Cmd+Left/Right | Ctrl+Cmd+Left/Right |
| Super+Up/Down (maximize, restore) | Cmd+Up/Down | Ctrl+Cmd+Up/Down |
| Shift+Super+arrows (move to monitor) | Shift+Cmd+arrows | Ctrl+Shift+Cmd+arrows |
| Super+L (lock) | Cmd+L | Ctrl+Cmd+Q |
| Super+A (app grid) | Cmd+A | Shift+Cmd+Space |
| Super+Space (input source) | Cmd+Space | removed; one layout is configured |
| Super+M, Super+V (notifications) | Cmd+M, Cmd+V | click the clock |
| Super+S (quick settings) | Cmd+S | click the top-right menu |
| Super+N (focus notification) | Cmd+N | -- |
| Super+P (display switcher) | Cmd+P | the display's XF86Display key, or Settings |
| Super+O (rotation lock) | Cmd+O | -- (desktop) |
| Alt+Left/Right in browsers (back, forward) | Option+arrows | Cmd+[ / Cmd+] |

Untouched: Super tap (overview), Super+Tab, Super+\`, Super+H,
Super+1..9, Super+Home/End, Super+PageUp/PageDown, Alt+Tab, Alt+F4.

## Terminals (Ptyxis, foot)

Ctrl is the shell's, Option is Meta, and Cmd uses the terminal's own
Ctrl+Shift shortcuts.

| Keys | Sent | |
| --- | --- | --- |
| Ctrl+any key | verbatim | rule 4 |
| Option+Left / Right | Alt+B / Alt+F | readline word motion |
| Option+Delete, Option+Fn+Delete | Alt+Backspace, Alt+D | readline word deletion |
| Cmd+C / V | Ctrl+Shift+C / V | clipboard |
| Cmd+T / N / W / F / A | Ctrl+Shift+T / N / W / F / A | tab, window, close, find (foot: Ctrl+Shift+R), select all |
| Cmd+Q | Ctrl+Shift+Q | Ptyxis close window |
| Cmd+Delete | Ctrl+U | readline kill to line start |
| Cmd+Left / Right | Home, End | line start, end |
| Cmd+= / - / 0 | Ctrl+= / - / 0 | zoom |
| Cmd+L | Ctrl+L | clear screen |
| Cmd+Z, S, O, G, B, I, U, K, P, `,` | nothing | their Ctrl versions suspend, freeze, or run a command |

When the per-app layer is down, terminals get the global translations
instead: Cmd+C/V do nothing, while Cmd+Z and Cmd+S send Ctrl+Z and Ctrl+S.
`doctor.sh keybindings` reports that state.

## GNOME Shell's own text fields

The overview's search entry and the Shell's dialogs (run, polkit, unlock) are
Clutter text fields. They take Ctrl+C/X/V but not Ctrl+Insert or Shift+Delete,
so there Cmd+C/X/V send Ctrl+C/X/V. Nothing runs in them that Ctrl+C could
interrupt.

## Emacs

Ctrl and Option are Emacs's own, verbatim. Cmd+key reaches Emacs as Super+key
(`s-c`, `s-v`, ...), so the Emacs config decides what each one means. Cmd+arrows
and Cmd+Delete keep their global meaning, which Emacs handles natively.

## Not handled by keyd

- **Fn combinations** are the keyboard's own layer. The HHKB sends real
  Home/End/PgUp/PgDn/Delete.
- **Option+letter for accented characters** is an input-method feature; use
  GNOME's compose key.

## References

- Apple, [Mac keyboard shortcuts](https://support.apple.com/102650): the
  contract's source.
- Apple, [Text System Defaults and Key Bindings](https://developer.apple.com/library/mac/documentation/cocoa/conceptual/eventoverview/TextDefaultsBindings/TextDefaultsBindings.html),
  and a [dump of `StandardKeyBinding.dict`](https://gist.github.com/hym3242/8e8bc10a2fed8e55973c500f1798c234)
  (macOS 13): the Cmd+Delete and Option+Delete rows above.
- [Kinto](https://github.com/rbreaves/kinto) and [Toshy](https://github.com/RedBearAK/toshy):
  the most complete prior per-app macOS keymaps for Linux; ADR 0002 says why
  they are not used here.
- [Omarchy discussion #175](https://github.com/omacom/omarchy/discussions/175):
  the same keyd design on Hyprland.
