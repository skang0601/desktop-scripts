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

```sh
./bootstrap.sh --list          # what's available and what this host enables
./bootstrap.sh keybindings     # run one module, ignoring the host file
```

## Modules

| Module | What it does |
| --- | --- |
| [`keybindings`](modules/keybindings/) | macOS-style Cmd/Ctrl split via keyd, plus the GNOME shortcut adjustments that go with it |

Each module owns its own config, installer and README. Adding one means creating
`modules/<name>/install.sh` and listing it in the relevant host file -- there is
no central registry to update.

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

## Conventions

[AGENTS.md](AGENTS.md) (also readable as `CLAUDE.md`) holds the conventions for
working in this repo, including the comment rule: comments explain why, not
what, and never narrate how the author got there.
