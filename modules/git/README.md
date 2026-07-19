# git

Global git config, symlinked to `~/.gitconfig` so `git config --global ...`
edits the tracked file directly.

```sh
./install.sh --dry-run
./install.sh
```

## Notable settings

| | |
| --- | --- |
| `pull.rebase` | no merge commits from routine pulls |
| `push.autoSetupRemote` | `git push` on a new branch just works |
| `rebase.autoStash` | stop rebases aborting on a dirty tree |
| `merge.conflictstyle = zdiff3` | conflicts show the common ancestor, so you can see what each side changed |
| `diff.algorithm = histogram` | more readable diffs on reordered code |
| `rerere.enabled` | remembers conflict resolutions; pays for itself on long rebases |
| `fetch.prune` | drop remote-tracking branches that no longer exist |

## Commit signing

`gitconfig` has a commented block for SSH commit signing through the 1Password
agent. Since the keys already live there (see [../ssh](../ssh)), enabling it is
mostly a matter of filling in the public key:

```sh
op item get "Personal SSH Key" --fields "public key"
```

Put that in `user.signingkey`, uncomment the block, and add the same key to
GitHub as a **signing** key -- GitHub tracks signing and authentication keys
separately, so an existing auth key does not count.

## Precedence

`~/.config/git/config` overrides `~/.gitconfig`. `install.sh` warns if one
exists, since it would silently shadow everything here.
