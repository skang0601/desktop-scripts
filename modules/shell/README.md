# shell

bash environment: PATH and editor defaults.

```sh
./install.sh --dry-run
./install.sh
```

Everything is a fragment in `bashrc.d/`, symlinked into `~/.bashrc.d/` so edits
land in the repo. Fedora's stock `~/.bashrc` already sources that directory; on
an image that doesn't, `install.sh` appends a loader.

Fragments are numbered to fix their order.

| Fragment | |
| --- | --- |
| `10-path.sh` | PATH entries and `$EDITOR` |

## Editor

`$EDITOR` and `$VISUAL` are `emacs -nw`, and [git](../git) sets `core.editor` to
match. Deliberately not `emacsclient`: that needs a server, which is a standing
background session this setup does without. The trade is Doom's startup on every
invocation, against never having to care whether a daemon is up -- and against
an `emacsclient -a <other>` fallback, which on a machine with no server running
means every commit is edited in `<other>` while the config still claims emacs.

## PATH

Added when the directory exists, guarded so re-sourcing doesn't accumulate
duplicates:

- Doom Emacs `bin/` -- `~/.config/emacs/bin`, or legacy `~/.emacs.d/bin`
- `~/go/bin`, `~/.cargo/bin`, `~/.local/bin`, `~/bin`
- Homebrew, via `brew shellenv`, which is how CLI tooling arrives on atomic
  systems (ADR 0005)
- rustup's shims, `$HOMEBREW_PREFIX/opt/rustup/bin`

Order is the point of keeping these in one file. Several entries only work in
relation to another -- rustup's shims have to beat brew's own `bin`, which
`brew shellenv` prepends -- and that is reviewable here in a way it would not be
spread across fragments owned by different modules. So an entry lives here even
when the thing it points at is installed by [packages](../packages): Doom, Go
and rustup all arrive that way.

JetBrains Toolbox is deliberately not here: it writes its own PATH line into
`~/.bash_profile` and `~/.profile` on first run.

## Scope

This covers shells only. GUI apps launched from the GNOME overview do not read
`~/.bashrc` -- they read `~/.config/environment.d/`. If something launched from
the overview needs a PATH entry, that is where it goes.
