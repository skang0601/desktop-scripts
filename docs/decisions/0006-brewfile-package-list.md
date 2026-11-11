# 0006 - Keep the package list in a Brewfile

- Status: accepted
- Date: 2026-11-11
- Amends: [0005](0005-package-install-strategy.md)

## Context

The packages module gave every package a script in `apps.d/` with its own
`app_check` and `app_install`, and a library of install helpers behind them:
`install_cli` choosing brew or dnf, `install_cask`, `install_flatpak`, tap
trust. Most entries were a binary test and one install call. Each one carried a
fallback for machines without Homebrew, and the repo has only ever run on
Bazzite, which ships it.

That is a package manager's job done by hand, and done less well: there was no
single list of what the machine should have, and no way to tell which installed
packages the repo accounts for.

## Decision

Every package the repo installs that Homebrew can install -- formulae, casks,
taps and Flatpaks -- is a line in `modules/packages/Brewfile`, applied with
`brew bundle`. That is Homebrew's own format, and the one Bazzite uses for its
`ujust` recipes.

- `install.sh` runs `brew bundle install --no-upgrade` only when
  `brew bundle check --no-upgrade` reports something missing, so a re-run is a
  no-op. Upgrading is a separate, explicit `install.sh --upgrade`, which
  upgrades only what the Brewfile lists.
- What a package manager cannot do -- linking config, toolchain setup,
  quadlets, distroboxes, the CUDA build of ollama, emacs from the distro, the
  autostart repair 1Password needs -- lives in ordinary modules (emacs, llm,
  boxes, ssh). `apps.d/` and its install framework are gone: a module with
  several things to set up runs each as a part with `install_part`.
- Homebrew is required. The dnf fallbacks, the 1Password rpm repo and the
  JetBrains tarball route are gone; without brew the module stops and says so.
- A supporting tool sits beside the package it supports, under a comment saying
  what it is for, rather than inside that package's script.

Considered and rejected:

- **Keeping `apps.d/` as the list.** It is the code this replaces.
- **A plain-text list fed to `brew install`.** It reimplements `brew bundle`'s
  check and has no casks, taps or Flatpaks.
- **Nix / home-manager.** It would manage packages better and replace far more
  than packages, on a host that already has Homebrew, rpm-ostree and Flatpak.

## Consequences

- `brew bundle dump` and `bbrew` read and write the same file, so a package
  installed by hand can be adopted with one command.
- Versions are not pinned. A Brewfile has no lock, so two machines applying it
  get whatever is current that day; Homebrew, the vendor installers and
  `go install`-style tools are the least stable part of a fresh install.
- Flatpaks in the Brewfile install system-wide (`brew bundle` passes
  `--system`), matching how Bazzite installs its own.
- Image-provided packages are not listed. Bazzite ships Steam, tailscale and
  most GNOME Flatpaks, and the Brewfile lists only what this repo adds.
