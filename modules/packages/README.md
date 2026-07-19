# packages

Apps and tooling, installed only when missing.

```sh
./install.sh              # everything in apps.d/
./install.sh emacs go     # only these
./install.sh --dry-run    # show what would happen, change nothing
```

## What's here

| App | Method | Notes |
| --- | --- | --- |
| 1password | 1Password's RPM repo | Flatpak cannot serve the SSH agent |
| 1password-cli | 1Password's RPM repo | not on Flathub at all |
| emacs | brew / dnf | native, not Flatpak; includes Doom and its config |
| go | brew / dnf | Fedora calls it `golang` |
| zig | brew / dnf | |
| claude-code | vendor installer | lands in `~/.local/bin`, no root |
| claude-desktop | official apt repo, in a distrobox | Anthropic ship Debian/Ubuntu only |
| steam | Flatpak | preinstalled on Bazzite, so usually a no-op |
| jetbrains-toolbox | tarball | bootstraps to `~/.local/bin`, then self-updates |

## Install strategy

Ordered by how little they disturb the system, which matters on atomic images
where layering costs a reboot and can block a rebase (ADR 0005):

1. **Homebrew** for CLI tooling. User-level, no reboot, no layering. Bazzite
   ships it; on a traditional system it's usually absent, so dnf takes over.
2. **dnf** on traditional systems.
3. **Flatpak** for GUI apps. Flathub is preconfigured on Bazzite.
4. **Vendor installers** where nothing else is published, kept to `$HOME`.
5. **`rpm-ostree` layering** only as a last resort, with a loud reboot warning.

Two apps deliberately skip Flatpak:

**emacs** -- as a development editor it needs to reach compilers, LSP servers
and toolchains outside the sandbox, and punching those through one by one is
worse than the alternative.

**1password** -- the Flathub build is vendor-verified, but 1Password's docs
state the SSH agent does not work under Flatpak, and the manifest confirms it:
no `--filesystem=home`, and `$HOME` redirected into the sandbox, so
`~/.1password/agent.sock` cannot appear on the host. The [ssh](../ssh) module
depends on that socket for every git-over-ssh operation, so the Flatpak would
break authentication outright. It layers on atomic systems instead -- one of the
few cases that justifies it.

## Adding an app

Drop a file in `apps.d/`. The whole contract is three things:

```sh
APP_NAME=ripgrep

app_check()   { have rg; }
app_install() { install_cli ripgrep rg; }   # (fedora_name, brew_name)
```

`app_check` gates the install, which is what makes re-running a no-op. Each file
is sourced in its own subshell, so definitions can't leak between apps.

Files run in filename order. An app that needs another one first calls
`require_app <name>` rather than relying on that order.

Write `app_check` against every location the app might already occupy, not just
the one this script would install to. Doom, for instance, lives at
`~/.config/emacs` now but `~/.emacs.d` still shadows it.

Helpers available: `install_cli`, `install_flatpak`, `flatpak_installed` from
`lib.sh`; `have`, `run`, `dry`, `say`, `warn`, `is_atomic` from
`../../lib/common.sh`.

Anything doing more than a simple command -- pipes, redirects, heredocs -- must
handle `--dry-run` itself with an explicit `if dry; then ... fi`, or the dry-run
output will lie about what it does.

## Doom Emacs

`emacs` installs Emacs, Doom, Doom's dependencies, and the tracked config in
`doom/`, which is symlinked into place so edits land in the repo.

Dependencies come from the modules enabled in `doom/init.el`: `git`, `ripgrep`
and `fd` for `:completion` and `:tools lookup`, and `shellcheck` for
`:checkers syntax` against `:lang sh`. Adding a module may add a dependency --
`doom doctor` will say so.

Path layout is a mess of Doom's own history and is detected rather than forced:

| | current | legacy |
| --- | --- | --- |
| Doom | `~/.config/emacs` | `~/.emacs.d` |
| config | `~/.config/doom` | `~/.doom.d` |

The legacy paths win when both exist. A fresh install gets the current layout; a
machine already using the legacy one keeps it, since relocating a working Doom
is not this script's business. Any real config directory found in the way is
renamed to `.bak` before the symlink goes in.

`init.elc` is a build artifact of `doom sync` and is not tracked.
