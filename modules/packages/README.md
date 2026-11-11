# packages

Every package the repo installs, listed in a [Brewfile](Brewfile) and applied
with `brew bundle`, plus the setup that a package manager cannot do, in
`apps.d/` (ADR 0006).

```sh
./install.sh              # the Brewfile, then every app in apps.d/
./install.sh emacs rust   # only these apps
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

A tool that exists to support another sits beside it in the Brewfile, under a
comment saying what it is for: `gopls` with go, `zls` with zig, and what Doom's
modules shell out to under one heading.

Homebrew is required. Bazzite ships it, and the module stops if it is absent.

## apps.d

An entry here is setup beyond installing a package, or an install brew cannot
do:

| App | What it does | Why not just the Brewfile |
| --- | --- | --- |
| [1password](apps.d/1password) | repairs the autostart entry, reports the SSH agent | the app writes an autostart `Exec` that misses the cask's binary |
| [emacs](apps.d/emacs) | Fedora's emacs, Doom, and its config | only the rpm is a GUI build; brew's is headless |
| rust | `rustup default stable` | rustup is in the Brewfile; the toolchain is a second step |
| claude-code | vendor installer | lands in `~/.local/bin` and updates itself |
| claude-desktop | official apt repo, in a distrobox | Anthropic ship Debian/Ubuntu only |
| [dev-box](apps.d/dev-box) | Fedora toolbox | `-devel` headers for building against system libraries, without layering |
| [ollama](apps.d/ollama) | tarball | brew's bottle has no CUDA; pins the GPUs and picks a model for them |
| [searxng](apps.d/searxng) | podman quadlet | local metasearch on loopback; web-search backend for gptel |
| [opencode-desktop](apps.d/opencode-desktop) | config links, coder model | the cask is in the Brewfile; this is its config |
| [opencode](apps.d/opencode) | podman quadlet | sandboxed `opencode serve` on loopback, for the phone over Tailscale |

When a package can come from the Brewfile, it does. The other routes, from
least to most disturbance to an atomic system (ADR 0005): distrobox, where the
host cannot package the software; a vendor installer kept to `$HOME`, where
nothing else is published; and `rpm-ostree` layering as the last resort, with a
loud reboot warning.

Containers cover two different shapes (ADR 0005). `distrobox` is for
interactive boxes that share `$HOME` -- see [dev-box](apps.d/dev-box). A
long-running service instead takes a podman **quadlet**: a `.container` file
symlinked into `~/.config/containers/systemd/`, which podman's systemd
generator turns into a `--user` service.
[searxng](apps.d/searxng) and [opencode](apps.d/opencode) are the examples.

Three properties of quadlets that an app has to account for:

- They are **generated**, so they cannot be `systemctl --user enable`d. The
  `[Install]` section inside the `.container` is what the generator acts on.
- **Editing one restarts nothing.** The symlink path does not change, so an
  `app_check` comparing paths still passes while systemd keeps running the unit
  built from the old file. Assert something observable about the running
  container instead -- the address it is bound to, the model it was given.
- Host-derived configuration goes in via `EnvironmentFile=`, which becomes
  `--env-file` and reaches inside the container. A systemd drop-in does not: it
  sets the variable on the `podman` process, where the application never sees
  it.

## Adding an app

A package goes in the Brewfile. An `apps.d/` entry is for setup around it, and
the whole contract is three things:

```sh
APP_NAME=rust

app_check()   { [[ -n "$(rustup show active-toolchain 2>/dev/null)" ]]; }
app_install() { run rustup default stable; }
```

`app_check` gates the install, which is what makes re-running a no-op. Each file
is sourced in its own subshell, so definitions can't leak between apps.

An app that ships files of its own takes a directory instead, named for the app
and holding a script of the same name:

```
apps.d/rust.sh             # script only
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
the one this script would install to. Doom, for instance, installs to
`~/.config/emacs`, and an existing `~/.emacs.d` shadows it.

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

Helpers available: `install_rpm`, `require_app`, `brew_bundle`,
`distrobox_ensure`, `blocked` from `lib.sh`; `have`, `run`, `dry`, `say`, `warn`,
`is_atomic`, `link_config`, `install_file` from `../../lib/common.sh`.

An app needing a PATH entry adds it to [shell](../shell)'s `10-path.sh` rather
than shipping a fragment of its own. Entries constrain each other -- rustup's
shims have to beat brew's `bin` -- and that ordering is only reviewable while
one file holds all of them.

Anything doing more than a simple command -- pipes, redirects, heredocs -- must
handle `--dry-run` itself with an explicit `if dry; then ... fi`, or the dry-run
output will lie about what it does.
