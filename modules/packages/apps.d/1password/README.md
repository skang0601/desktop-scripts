# 1password

The desktop app plus the `op` CLI. The SSH agent socket at
`~/.1password/agent.sock` is the point: the [ssh](../../../ssh) module depends on
it for every git-over-ssh operation.

## Not Flatpak

The Flathub build is vendor-verified, but 1Password's docs state the SSH agent
does not work under Flatpak, and the manifest confirms it: no
`--filesystem=home`, and `$HOME` redirected into the sandbox, so the agent
socket cannot appear on the host. The Flatpak would break authentication
outright.

Confirmed on this machine rather than read off the manifest -- with the Flatpak
installed and running, no socket appeared on the host.

## Not the rpm, either

The rpm cannot be layered at all. Its `%post` runs `mkdir -p /usr/local/bin`,
and on an ostree system `/usr/local` is a symlink into `/var` that
rpm-ostree's bwrap sandbox leaves unpopulated; the mkdir gets `EEXIST` on the
dangling symlink and the scriptlet aborts, which rpm-ostree treats as fatal
where dnf only warns.

That leaves a brew cask from `ublue-os/tap`, which packages 1Password's own
Linux tarball and puts the app on the host, where the agent socket, `op`, the
polkit policy and browser integration all work without special handling
(ADR 0005). On a traditional system the rpm is fine and is used instead.

Trusting that tap is a real decision: its casks `sudo` to install a polkit
policy into `/etc/polkit-1/actions`, create the `onepassword` group, and set
setuid/setgid bits. The app names the tap rather than trusting taps in general.

Running the app in the `ubuntu` box was tried and works for the agent, but `op`
does not survive the container boundary in either direction, and the polkit,
autostart and browser paths each need patching up by hand.

This app declared `app_blocked` until the `%post` failure stopped being a dead
end and became a reason to install from the cask instead.
