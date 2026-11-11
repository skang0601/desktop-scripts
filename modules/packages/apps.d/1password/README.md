# 1password

The desktop app plus the `op` CLI. The SSH agent socket at
`~/.1password/agent.sock` is the point: the [ssh](../../../ssh) module depends on
it for every git-over-ssh operation.

## Why a brew cask

The app and `op` are `ublue-os/tap` casks in the [Brewfile](../../Brewfile),
which package 1Password's own Linux tarball and install it on the host. The
agent socket, `op`, the polkit policy and browser integration then work as they
do from the vendor's packages (ADR 0005). This entry only repairs autostart and
reports state.

- **Not the Flatpak.** It has no `--filesystem=home` and redirects `$HOME`
  into the sandbox, so the agent socket never appears on the host, and
  1Password documents that the SSH agent does not work under Flatpak.
- **Not the rpm, on an atomic system.** It would be a layered package, which
  needs a reboot per change and rides along on every image update. Its `%post`
  also builds the polkit policy's list of allowed users from `/etc/passwd`
  while layering, and whether that list includes the desktop user on an
  image-based system is untested. Releases before 8.12 cannot be layered at
  all: their `%post` runs `mkdir -p /usr/local/bin` against a dangling
  `/usr/local` symlink and aborts.
- **Not in a distrobox.** The agent works from the `ubuntu` box, but `op`
  cannot reach the app across the container boundary in either direction, and
  polkit, autostart and browser integration each need manual fixes.

The tap's casks run `sudo` to install the polkit policy into
`/etc/polkit-1/actions`, create the `onepassword` group, and set setuid/setgid
bits, so the Brewfile trusts this tap by name rather than taps in general.
`install.sh` runs `brew bundle` with `SUDO_ASKPASS` unset so that `sudo`
prompts on the terminal; see `brew_bundle` in [lib.sh](../../lib.sh).

## Start at login

The app writes `~/.config/autostart/1password.desktop` itself when **Start at
login** is enabled, and hardcodes `Exec=/opt/1Password/1password` -- the path
its own `.deb` and `.rpm` use. The cask installs under brew's prefix, so the
entry the app writes points at nothing.

Nothing announces that. GNOME's exec fails silently at login; the app is simply
not running, `agent.sock` is left with no daemon behind it, and the first
symptom is ssh falling back to a key file and a `Permission denied (publickey)`
from an unrelated `git push`.

`install.sh` repairs the entry, pointing it at whichever binary is on PATH, and
`doctor.sh` reports it. It repairs rather than owns: the app rewrites the file
whenever the setting is toggled, and re-running the installer is the fix.

The app's own setting decides whether the entry should exist at all -- turning
**Start at login** off leaves it alone rather than putting it back.
