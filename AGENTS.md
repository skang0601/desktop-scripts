# Working in this repo

Desktop setup for GNOME/Wayland, organized as modules under `modules/`, with
decision records in `docs/decisions/`. README.md has the layout and how the
pieces fit; each module's README covers that module.

## Testing

Scope to the module you changed; the full run is slower and no more informative.

```sh
./modules/<name>/install.sh --dry-run   # print every command, change nothing
./modules/<name>/install.sh             # then again, to confirm the no-op
./doctor.sh <name>                      # actual state; nonzero if a check failed
shellcheck -s bash <file>

./modules/packages/install.sh <app>     # one app, not the whole module
./doctor.sh                             # everything this host enables
```

The second installer run is part of the test, not a formality: it is what
catches an `app_check` that does not detect what its own `app_install` just did.

## Where things go

- A new module: `modules/<name>/install.sh`, plus a line in `hosts/*.modules`.
  Nothing else registers it.
- A new app: one file in `modules/packages/apps.d/` defining `APP_NAME`,
  `app_check`, `app_install`. Read that module's README first.
- A shared helper: `lib/common.sh` for anything a module needs,
  `modules/packages/lib.sh` for install strategies.
- A PATH entry: `modules/shell/bashrc.d/10-path.sh`, even when the thing on it
  is installed by another module -- entries constrain each other's order.
- Anything answering "why is it like this", where the answer outlives the code:
  `docs/decisions/`.

## Acting on this machine

These installers change the machine they run on. `--dry-run` first.

Ask before: layering with `rpm-ostree` (needs a reboot and rides along on every
image update), removing or replacing a package the user did not name,
`systemctl enable`, and anything that changes GNOME session state. Committing is
the user's call, not a step in finishing the work.

Fine to run unprompted: `--dry-run` anything, `doctor.sh`, `shellcheck`, and
re-running an installer whose changes are already agreed.

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
