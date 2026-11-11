# packages

Every package the repo installs, listed in a [Brewfile](Brewfile) and applied
with `brew bundle` (ADR 0006), plus the two small setups that follow from it.

```sh
./install.sh              # install what the Brewfile lists and is missing
./install.sh --upgrade    # also upgrade everything the Brewfile lists
./install.sh --dry-run    # show what would happen, change nothing
```

## The Brewfile

Formulae, casks, taps and Flatpaks, in Homebrew's own format, which Bazzite also
uses for `ujust`. Adding a package is one line there, by hand, with
`brew bundle add --file=Brewfile <name>`, or through `bbrew`. `install.sh` runs
`brew bundle install --no-upgrade` only when `brew bundle check` reports
something missing, so a re-run changes nothing. `--upgrade` also brings every
listed entry up to date, and touches nothing the Brewfile does not list.
`doctor.sh packages` names anything missing.

A tool that exists to support another sits beside it, under a comment saying
what it is for: `gopls` with go, `zls` with zig, and what Doom's modules shell
out to under one heading.

Homebrew is required. Bazzite ships it, and the module stops if it is absent.

The 1Password casks run `sudo`. brew would route that through `SUDO_ASKPASS`,
whose dialog Xwayland refuses under brew's stripped environment, so
`brew_bundle` in [lib.sh](lib.sh) unsets it and `sudo` prompts on the terminal.

## Setup

- `rust.sh` sets rustup's default toolchain, which rustup's own install leaves
  unset.
- `claude-code.sh` runs Anthropic's installer, which lands in `~/.local/bin`
  and updates itself.

Each is a *part* (`install_part` in [lib/common.sh](../../lib/common.sh)). A
setup larger than a few lines, or one that is not about a package, gets a
module of its own: [emacs](../emacs), [llm](../llm), [boxes](../boxes), and
1Password's autostart in [ssh](../ssh).

A PATH entry goes in [shell](../shell)'s `10-path.sh` rather than a fragment of
its own. Entries constrain each other -- rustup's shims have to beat brew's
`bin` -- and that ordering is only reviewable while one file holds all of them.
