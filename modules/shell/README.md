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

## PATH

Added when the directory exists, guarded so re-sourcing doesn't accumulate
duplicates:

- Doom Emacs `bin/` -- `~/.config/emacs/bin`, or legacy `~/.emacs.d/bin`
- `~/go/bin`, `~/.cargo/bin`, `~/.local/bin`, `~/bin`
- Homebrew, via `brew shellenv`, which is how CLI tooling arrives on atomic
  systems (ADR 0005)

JetBrains Toolbox is deliberately not here: it writes its own PATH line into
`~/.bash_profile` and `~/.profile` on first run.

## Scope

This covers shells only. GUI apps launched from the GNOME overview do not read
`~/.bashrc` -- they read `~/.config/environment.d/`. If something launched from
the overview needs a PATH entry, that is where it goes.
