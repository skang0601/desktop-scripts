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
| 1password | brew cask from `ublue-os/tap` (rpm on traditional) | desktop app + `op`; the SSH agent socket is the point (ADR 0005) |
| emacs | brew / dnf | native, not Flatpak; includes Doom and its config |
| go | brew / dnf | Fedora calls it `golang` |
| rust | brew / dnf | `rustup`, not a fixed toolchain; keg-only, so [shell](../shell) puts its shims on PATH |
| zig | brew / dnf | |
| claude-code | vendor installer | lands in `~/.local/bin`, no root |
| claude-desktop | official apt repo, in a distrobox | Anthropic ship Debian/Ubuntu only |
| dev-box | Fedora toolbox | `-devel` headers for building against system libraries, without layering (ADR 0005) |
| steam | Flatpak | preinstalled on Bazzite, so usually a no-op |
| jetbrains-toolbox | tarball | bootstraps to `~/.local/bin`, then self-updates |

## Install strategy

Ordered by how little they disturb the system, which matters on atomic images
where layering costs a reboot and can block a rebase (ADR 0005):

1. **Homebrew** for CLI tooling. User-level, no reboot, no layering. Bazzite
   ships it; on a traditional system it's usually absent, so dnf takes over.
2. **dnf** on traditional systems.
3. **Flatpak** for GUI apps. Flathub is preconfigured on Bazzite.
4. **distrobox** where the host cannot package the software, or the dependency
   is only needed at build time. A brew cask packaging the vendor's own build
   beats a container when one exists.
5. **Vendor installers** where nothing else is published, kept to `$HOME`.
6. **`rpm-ostree` layering** only as a last resort, with a loud reboot warning.

Two apps deliberately skip Flatpak:

**emacs** -- as a development editor it needs to reach compilers, LSP servers
and toolchains outside the sandbox, and punching those through one by one is
worse than the alternative.

**1password** -- the Flathub build is vendor-verified, but 1Password's docs
state the SSH agent does not work under Flatpak, and the manifest confirms it:
no `--filesystem=home`, and `$HOME` redirected into the sandbox, so
`~/.1password/agent.sock` cannot appear on the host. The [ssh](../ssh) module
depends on that socket for every git-over-ssh operation, so the Flatpak would
break authentication outright.

It comes from `ublue-os/tap` instead, which packages 1Password's own Linux
tarball. The rpm cannot be layered at all -- its `%post` aborts under
rpm-ostree -- so brew is the remaining route that puts the app on the host,
where the agent socket, `op`, the polkit policy and browser integration all
work without special handling (ADR 0005).

Trusting that tap is a real decision: its casks `sudo` to install a polkit
policy into `/etc/polkit-1/actions`, create the `onepassword` group, and set
setuid/setgid bits. The app names the tap rather than trusting taps in general.

Running the app in the `ubuntu` box was tried and works for the agent, but `op`
does not survive the container boundary in either direction, and the polkit,
autostart and browser paths each need patching up by hand.

## Building against system libraries

Crates that bind system libraries -- `hidapi` wants `libudev.pc` -- need `-devel`
packages no Fedora Atomic image ships. Those are build-time only, so layering
them would carry headers on the host across every image update to produce
binaries that never load them.

`dev-box` is a Fedora toolbox for that instead:

```sh
distrobox enter dev -- cargo build --release
```

The box is stopped once provisioned and stays that way; `distrobox enter` starts
it on demand. `doctor.sh` has to look inside to report what is there, so it
starts the box and stops it again rather than leaving one running.

The image is pinned to the host's Fedora release, so the headers compiled
against and the sonames the binary loads on the host are the same version.
Homebrew is mounted at its own prefix, which its bottles hardcode, so
`~/.bashrc` puts the host's rustup on PATH inside the box and there is no second
toolchain to keep in step. `doctor.sh` reports a box whose image has fallen
behind the host.

## Adding an app

Drop a file in `apps.d/`. The whole contract is three things:

```sh
APP_NAME=ripgrep

app_check()   { have rg; }
app_install() { install_cli ripgrep rg; }   # (fedora_name, brew_name)
```

`app_check` gates the install, which is what makes re-running a no-op. Each file
is sourced in its own subshell, so definitions can't leak between apps.

An app that ships files of its own takes a directory instead, named for the app
and holding a script of the same name:

```
apps.d/ripgrep.sh          # script only
apps.d/emacs/emacs.sh      # script plus the files it installs
apps.d/emacs/doom/
```

Both forms are one app with one `APP_NAME`, and `./install.sh emacs` names
either. Inside the script, **`$APP_DIR` is the directory its own file lives in**
-- use it to reach bundled files, so config sits beside the code that installs
it rather than elsewhere in the module.

Apps run in name order. One that needs another first calls `require_app <name>`
rather than relying on that order.

Write `app_check` against every location the app might already occupy, not just
the one this script would install to. Doom, for instance, lives at
`~/.config/emacs` now but `~/.emacs.d` still shadows it.

An app may also define `app_checks()`, reported by [`doctor.sh`](../../doctor.sh).
`app_check` answers "is it here" in one bit; `app_checks` says what is actually
wrong, using the app's own path detection rather than a second copy of it in the
module's `checks.sh`:

```sh
app_checks() {
  check_ok   "doom" "$(doom_home)"                      # or check_warn / check_fail
  check_symlink "doom config" "$(doomdir)" "$APP_DIR/doom" "<how to fix>"
}
```

An app that cannot be installed on some machines defines `app_blocked()`, which
prints the reason and succeeds when blocked. `app_install` calls `blocked "$reason"`
on it and `doctor.sh` reports it as **blocked** rather than a warning, so a
standing upstream bug stops reading as a fresh problem on every run:

```sh
app_blocked() {
  is_atomic || return 1
  echo "<what cannot work here and why>"
  echo "<the upstream thread that will say when it changes>"
}
```

No app declares one at present. 1Password did, until its `%post` failure stopped
being a dead end and became a reason to install it from a brew cask instead.

Helpers available: `install_cli`, `install_rpm`, `install_flatpak`,
`flatpak_installed`, `require_app`, `brew_split_shared_dir`, `brew_relink`,
`blocked` from `lib.sh`; `have`, `run`, `dry`, `say`, `warn`, `is_atomic`,
`link_config` from `../../lib/common.sh`.

An app needing a PATH entry adds it to [shell](../shell)'s `10-path.sh` rather
than shipping a fragment of its own. Entries constrain each other -- rustup's
shims have to beat brew's `bin` -- and that ordering is only reviewable while
one file holds all of them.

Anything doing more than a simple command -- pipes, redirects, heredocs -- must
handle `--dry-run` itself with an explicit `if dry; then ... fi`, or the dry-run
output will lie about what it does.

## Doom Emacs

`emacs` installs Emacs, Doom, Doom's dependencies, and the tracked config in
`apps.d/emacs/doom/`, which is symlinked into place so edits land in the repo.

Dependencies come from the modules enabled in `apps.d/emacs/doom/init.el`: `git`, `ripgrep`
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
