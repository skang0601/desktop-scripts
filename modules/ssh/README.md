# ssh

SSH client config, symlinked to `~/.ssh/config`.

```sh
./install.sh --dry-run
./install.sh
```

## Keys live in 1Password, not on disk

1Password's SSH agent holds the keys and answers over
`~/.1password/agent.sock`, which the config points at with `IdentityAgent`. An
on-disk `~/.ssh/id_rsa` is named as a fallback for machines where the desktop
app is not available; `ssh_config` is first-obtained-wins, so the agent block
precedes `Host *` and wins when it applies.

### The agent is selected only when it answers

The `Match exec` guard runs `ssh-add -l` against the socket rather than testing
that the socket exists. The socket file outlives the app that served it -- quit
1Password and `~/.1password/agent.sock` is still there, refusing connections --
so `test -S` selects a dead agent as readily as a live one.

`ssh-add` exits 2 when it cannot reach an agent and 1 when it reaches one
holding no keys, so only 2 means unusable. The 1 case is a locked 1Password,
which is still the right identity: it prompts and unlocks.

Consequences worth knowing:

- **The agent is a feature of the 1Password desktop app, not the `op` CLI.** The
  desktop app must be installed and unlocked for git-over-ssh to work; `op`
  alone is not enough.
- **The Flatpak build cannot provide it.** 1Password's docs say the SSH agent
  does not work under Flatpak or Snap, and the Flathub manifest confirms it --
  no `--filesystem=home`, and `$HOME` redirected into the sandbox. The socket
  path is hardcoded and not configurable, so there is no workaround. The
  [packages](../packages/apps.d/1password) module installs a brew cask that
  packages 1Password's own Linux build; the RPM cannot be layered at all,
  because its `%post` aborts under rpm-ostree.
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
