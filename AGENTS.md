# Working in this repo

Desktop setup for GNOME/Wayland, organized as modules under `modules/`, with
decision records in `docs/decisions/`. See README.md for structure.

## Comments

**Comments explain why, not what.** The code already says what it does.

Write a comment when the reader would otherwise reasonably ask "why is it like
this?" -- a constraint, a gotcha, a rejected alternative, a non-obvious
consequence, a link to the upstream issue that forced it. If the line is
self-evident, no comment.

Do not narrate the process of arriving at the code. No "NOT foo()", no "first I
tried X", no "verified rather than assumed", no "this turned out to be wrong",
no marking which parts were hard. That history belongs in git and in ADRs'
supersession notes, not in a comment. State the current reason in the present
tense as a fact about the system.

```sh
# bad -- restates the code
sudo systemctl enable --now keyd     # enable keyd

# bad -- narrates the author
# I initially used overload() here, but it turned out not to parse, so
# after checking with keyd check I switched to layer().
meta = layer(mac)

# good -- why, stated as a fact
# keyd emits a clean meta down/up on an isolated tap of a layer key, so
# tap-Super still reaches GNOME's overlay-key.
meta = layer(mac)
```

Same rule in docs: ADRs record the decision and its rationale, not the path the
author took to it. "Considered and rejected" is legitimate content -- it tells a
future reader not to re-litigate. "I got this wrong at first" is not.

Exception: a comment marking a real, current defect or limitation is a why. Keep
those, and be specific about the condition rather than vague.

## Conventions

- Installers are idempotent and safe to re-run, and accept `--dry-run`.
- Source `lib/common.sh` and wrap state-changing commands in `run`, so
  `--dry-run` prints them instead of executing. Anything with a pipe, redirect
  or heredoc needs an explicit `if dry; then ... fi` -- otherwise the dry-run
  output claims to do something it doesn't.
- Scripts call `sudo` inline; they are never run as root.
- Config lives in the repo and is installed to its system location by the
  module's `install.sh`. Nothing is edited in place under `/etc`.
- Installers branch on `[[ -f /run/ostree-booted ]]` to support atomic systems
  (ADR 0004).
- Read `dconf read` rather than `gsettings get` when establishing what GNOME's
  default for a key is; `gsettings get` cannot distinguish a schema default from
  a local override.
