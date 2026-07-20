# desktop-scripts

My Linux desktop setup, kept in git so a reinstall is a checkout and one command
rather than an afternoon of rediscovery -- and so several machines can share the
parts they have in common without pretending to be identical.

**Target environment:** GNOME on Wayland. The distro underneath is not
load-bearing; the installers branch on traditional (`dnf`) vs atomic/image-based
(`rpm-ostree`, bootc) systems. Developed on Fedora Workstation, headed for
Bazzite.

## Setup on a new machine

```sh
git clone git@github.com:skang0601/desktop-scripts.git ~/Workspace/desktop-scripts
cd ~/Workspace/desktop-scripts
./bootstrap.sh
```

`bootstrap.sh` looks for `hosts/$(hostname).modules` -- a plain list of module
names -- and runs each module's `install.sh` in order. With no host file it runs
everything and tells you it did. Every installer is idempotent, so re-running
after adding a module is the normal way to work.

Note that Fedora leaves the hostname unset, falling back to `fedora` for every
such machine, so set one per install or pass `--host`. See
[hosts/](hosts/README.md).

```sh
./bootstrap.sh --list          # what's available and what this host enables
./bootstrap.sh --dry-run       # print every command, change nothing
./bootstrap.sh --host bazzite  # pick a profile explicitly
./bootstrap.sh keybindings     # run one module, ignoring the host file
```

`--dry-run` is passed through to each module, so it's the way to inspect what a
fresh machine is about to have done to it before committing.

## Layout

```
bootstrap.sh          runs each enabled module's install.sh
doctor.sh             runs each module's checks.sh and reports actual state
lib/common.sh         say/warn/run/dry, link_config, is_atomic
lib/checks.sh         check_ok / check_warn / check_fail / check_blocked
hosts/*.modules       which modules a given machine enables
modules/<name>/       install.sh + checks.sh + config + README
docs/decisions/       ADRs
```

## Checking state

```sh
./doctor.sh                 # every module this host enables
./doctor.sh packages shell  # specific modules
./doctor.sh --html          # the same, as a page
```

`doctor.sh` reports what is actually installed and configured, as opposed to
what the installers believe, and exits nonzero if any check failed -- which
makes it usable as a post-install gate. It is read-only: anything it has to
start in order to look inside, it puts back.

A module opts in by adding `checks.sh` defining `module_checks()`. As with
`install.sh`, there is no list anywhere to update.

## Modules

| Module | What it does |
| --- | --- |
| [`keybindings`](modules/keybindings/) | macOS-style Cmd/Ctrl split via keyd, plus the GNOME shortcut adjustments that go with it |
| [`packages`](modules/packages/) | apps and tooling -- emacs/Doom, go, rust, zig, claude-code, steam, 1password + CLI, jetbrains-toolbox -- installed only when missing, one file per app in `apps.d/` |
| [`shell`](modules/shell/) | bash PATH and editor defaults |
| [`git`](modules/git/) | global git config |
| [`ssh`](modules/ssh/) | ssh client config; keys come from the 1Password agent |

Each module owns its own config, installer and README. Adding one means creating
`modules/<name>/install.sh` and listing it in the relevant host file -- there is
no central registry to update. Shared shell helpers live in `lib/common.sh`.

## Per-machine differences

Machines differ in ways worth encoding rather than remembering: a desktop
doesn't need the touchpad quirk, a work laptop may not want the same shortcuts.
`hosts/<hostname>.modules` is the whole mechanism -- one module name per line,
`#` for comments. Anything a module needs to vary beyond "on or off" belongs in
that module's own config.

## Decisions

`docs/decisions/` holds the ADRs. They're the reason this repo exists in a form
more elaborate than a tarball of dotfiles: config records *what*, and the
expensive thing to rediscover after a reinstall is *why*.

- [0001](docs/decisions/0001-use-adrs.md) -- why ADRs at all
- [0002](docs/decisions/0002-macos-keybindings.md) -- the keybinding design
- [0003](docs/decisions/0003-touchpad-quirk-override.md) -- the libinput quirk
- [0004](docs/decisions/0004-installing-on-atomic-systems.md) -- supporting atomic
  systems (Bazzite, Silverblue) in every installer
- [0005](docs/decisions/0005-package-install-strategy.md) -- preferring
  user-level installs over layering

## Conventions

[AGENTS.md](AGENTS.md) (also readable as `CLAUDE.md`) holds the conventions for
working in this repo, including the comment rule: comments explain why, not
what, and never narrate how the author got there.
