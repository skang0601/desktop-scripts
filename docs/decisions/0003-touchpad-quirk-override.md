# 0003 - Tag keyd's virtual keyboard as internal for libinput

- Status: accepted
- Date: 2026-07-19

## Context

keyd works by grabbing the real keyboard's evdev device and re-emitting events
through a uinput device named `keyd virtual keyboard`. To the rest of the stack,
all typing now originates from what looks like a newly plugged-in external
keyboard.

libinput's disable-while-typing / palm rejection deliberately only engages for
keyboards it believes are built into the laptop -- an external USB keyboard
shouldn't suppress the touchpad, since your hands aren't over it. So on a laptop,
installing keyd silently disables palm rejection and the cursor starts jumping
mid-sentence.

The failure is easy to misattribute to the touchpad driver or a GNOME
regression rather than to the remapper.

## Decision

Ship `modules/keybindings/local-overrides.quirks` -> `/etc/libinput/local-overrides.quirks`,
matching on the device name and asserting `AttrKeyboardIntegration=internal`.

## Consequences

- Palm rejection behaves as it did before keyd.
- The match is on the literal device name `keyd virtual keyboard`; if upstream
  renames the uinput device this silently stops applying. Verify with
  `libinput list-devices` after a keyd upgrade.
- Irrelevant on a desktop, harmless there.
