# ssh

SSH client config, symlinked to `~/.ssh/config`.

```sh
./install.sh --dry-run
./install.sh
```

## Keys live in 1Password, not on disk

There is no `IdentityFile` here and no `~/.ssh/id_*`. 1Password's SSH agent
holds the keys and answers over `~/.1password/agent.sock`, which the config
points at with `IdentityAgent`.

Consequences worth knowing:

- **The agent is a feature of the 1Password desktop app, not the `op` CLI.** The
  desktop app must be installed and unlocked for git-over-ssh to work; `op`
  alone is not enough.
- Enable it in 1Password under **Settings > Developer > Use the SSH agent**. The
  socket only exists while the app is running.
- `$SSH_AUTH_SOCK` usually points at gnome-keyring, which holds nothing here.
  To inspect what 1Password offers, ask it directly:

  ```sh
  SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
  ```

- A fresh machine needs the desktop app installed and signed in *before* git
  over ssh will work -- which includes cloning this repo. Clone over HTTPS the
  first time, or authenticate with a token.

Optionally, `~/.config/1Password/ssh/agent.toml` restricts and orders which keys
the agent offers. Absent, it offers all of them.
