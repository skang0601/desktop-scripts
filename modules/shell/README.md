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
| `20-aliases.sh` | interactive aliases, `kubectl` shorthands |
| `30-completion.sh` | brew's completions, which nothing else loads |

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

## Aliases

Nothing here changes what an existing command does. There is no `alias
grep=...`, so a line copied out of a script or a doc behaves the same when
pasted into a shell. The exceptions are `rm`, `cp` and `mv`, which take
interactive flags -- `rm -I` rather than `-i`, so a recursive delete prompts
once instead of per file, which is the difference between a question and a
reflex.

Git shorthands are deliberately absent. They live in [git](../git)'s gitconfig
as `git s`, `git lg`, `git last` and `git unstage`, which work over ssh and
inside editors that never read this file.

`kubectl` gets `k` plus the usual verb pairs, and `kctx`/`kns` as functions:
each prints the current value when called bare and switches when given an
argument. They are what `kubectx`/`kubens` are usually installed for, and
`kubectl config` has done it natively since 1.10.

## Completion

Brew installs each formula's bash completion to
`$HOMEBREW_PREFIX/etc/bash_completion.d` and nothing reads it. `bash-completion`
loads from XDG data directories and from one compat directory it hardcodes to
`/etc`, and brew's is neither -- so `kubectl`, `rg`, `fd`, `op` and the rest
ship completions that sit there inert.

`30-completion.sh` sources the directory. Eagerly, not on demand: the lazy path
would mean registering a loader with `bash-completion`, which only searches
directories it already knows. The whole directory measures ~14ms, under what
that machinery would cost.

Aliases are separate names as far as bash is concerned, so `k` completes on
filenames until it is pointed at `kubectl`'s completion function by hand. That
binding is here rather than beside the alias because it depends on the sourcing
above having happened.

## Scope

This covers shells only. GUI apps launched from the GNOME overview do not read
`~/.bashrc` -- they read `~/.config/environment.d/`. If something launched from
the overview needs a PATH entry, that is where it goes.
