# packages

Apps and tooling, installed only when missing.

```sh
./install.sh              # everything in apps.d/
./install.sh emacs go     # only these
./install.sh --dry-run    # show what would happen, change nothing
```

## What's here

An app with more to say than fits this table has a README beside its script.

| App | Method | Notes |
| --- | --- | --- |
| [1password](apps.d/1password) | brew cask from `ublue-os/tap` (rpm on traditional) | desktop app + `op`; the SSH agent socket is the point |
| [emacs](apps.d/emacs) | brew / dnf | native, not Flatpak; includes Doom and its config |
| go | brew / dnf | Fedora calls it `golang` |
| rust | brew / dnf | `rustup`, not a fixed toolchain; keg-only, so [shell](../shell) puts its shims on PATH |
| zig | brew / dnf | |
| git-lfs | brew / dnf | |
| claude-code | vendor installer | lands in `~/.local/bin`, no root |
| claude-desktop | official apt repo, in a distrobox | Anthropic ship Debian/Ubuntu only |
| [dev-box](apps.d/dev-box) | Fedora toolbox | `-devel` headers for building against system libraries, without layering |
| steam | Flatpak | preinstalled on Bazzite, so usually a no-op |
| jetbrains-toolbox | tarball | bootstraps to `~/.local/bin`, then self-updates |
| [ollama](apps.d/ollama) | tarball | brew's bottle has no CUDA; auto-pins to the GPU not driving the display |
| [searxng](apps.d/searxng) | podman quadlet | local metasearch on loopback; web-search backend for open-webui and gptel |
| [open-webui](apps.d/open-webui) | podman quadlet | browser front end for ollama at ai.localhost:1234; published only as an image |

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

The ranking is a default, not a rule: an app takes a lower method when a higher
one cannot deliver what the app exists for. [1password](apps.d/1password) and
[emacs](apps.d/emacs) both skip Flatpak, and [ollama](apps.d/ollama) skips brew,
each for a reason recorded in its own README.

Containers cover two different shapes. `distrobox` is for interactive boxes that
share `$HOME` -- see [dev-box](apps.d/dev-box). A long-running service instead
takes a podman **quadlet**: a `.container` file symlinked into
`~/.config/containers/systemd/`, which podman's systemd generator turns into a
`--user` service. [open-webui](apps.d/open-webui) is the example. Quadlet units
are generated, so they cannot be `systemctl --user enable`d; the `[Install]`
section inside the `.container` file is what the generator acts on.

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
apps.d/emacs/README.md
```

Both forms are one app with one `APP_NAME`, and `./install.sh emacs` names
either. Inside the script, **`$APP_DIR` is the directory its own file lives in**
-- use it to reach bundled files, so config sits beside the code that installs
it rather than elsewhere in the module.

An app whose reasoning outgrows a table cell takes the directory form and a
`README.md` in it, so what is true of one app stays with that app. This file
covers the module: the contract, the helpers, and the ranking every app is
choosing against. Anything answering "why is this app like this" belongs in the
app's own README, and anything outliving the code belongs in `docs/decisions/`.

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

`module_checks` already reports an app as installed or missing, so `app_checks`
adds only what it alone can know. Each app runs with stdin closed, because a
check that shells out to podman or distrobox would otherwise read the rest of
the app list and end the loop partway down.

An app that cannot be installed on some machines defines `app_blocked()`, which
prints the reason and **succeeds when blocked**. `app_install` calls
`blocked "$reason"` on it and `doctor.sh` reports it as **blocked** rather than a
warning, so a standing upstream bug stops reading as a fresh problem on every
run:

```sh
app_blocked() {
  is_atomic || return 1
  echo "<what cannot work here and why>"
  echo "<the upstream thread that will say when it changes>"
}
```

Getting that return sense backwards makes the app look permanently blocked, and
`doctor.sh` will skip its `app_checks` entirely.

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
