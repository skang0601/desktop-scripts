# 0005 - Prefer user-level installs over layering

- Status: accepted
- Date: 2026-07-19, revised 2026-07-20 to add containers and brew casks
- Extends: [0004](0004-installing-on-atomic-systems.md)

## Context

ADR 0004 established that installers must work on atomic images. The packages
module makes the cost of getting that wrong concrete: it installs six things,
and if each one layered a package, a fresh Bazzite install would need several
reboots and would accumulate six chances for a future image to conflict and
block a rebase.

Bazzite ships infrastructure that avoids this: Homebrew is baked into the image
with `brew-setup.service` enabled, Flathub is preconfigured in
`/etc/flatpak/remotes.d`, and Steam is already installed. None of that is true
on a traditional Fedora install, where dnf is simply the right answer.

Three cases had no answer in the first version of this ranking:

**Software not published for this distro.** Anthropic ship claude-desktop as a
`.deb` only. The alternatives were a third-party repackage or nothing.

**Software whose package will not install.** 1Password's rpm runs
`mkdir -p /usr/local/bin` in `%post`. On an ostree system `/usr/local` is a
symlink into `/var`, which rpm-ostree's bwrap sandbox leaves unpopulated; the
mkdir gets `EEXIST` on the dangling symlink and the scriptlet aborts, which
rpm-ostree treats as fatal where dnf only warns. Flatpak does not help either:
its manifest has no `--filesystem=home` and redirects `$HOME`, so
`~/.1password/agent.sock` is created inside the sandbox and never reaches the
ssh module. Confirmed on this machine rather than from the manifest -- with the
Flatpak installed and running, no socket appeared on the host.

**Build-time dependencies.** Crates binding system libraries need `-devel`
packages no atomic image ships. Layering headers makes the host carry them
across every image update to produce binaries that never load them.

## Decision

Installers pick a method by how little it disturbs the system:

1. **Homebrew** for CLI tooling -- user-level, no reboot, no layering.
2. **dnf** on traditional systems.
3. **Flatpak** for GUI apps.
4. **distrobox** where the host cannot package the software, or where the
   dependency is only needed at build time. Prefer a brew cask that packages
   the vendor's own build first: 1Password reaches the host that way, and only
   claude-desktop has no such cask.
5. **Vendor installers** where nothing else is published, confined to `$HOME`.
6. **`rpm-ostree` layering** last, with an explicit reboot warning.

Every app declares an `app_check` that gates its install, so the module is
idempotent and re-running it after adding an entry only installs the new one.

The keybindings module is the standing exception: keyd needs root-level evdev
access, so it layers. That is the case layering exists for.

Containers are declared by apps in `modules/packages/apps.d/`, and two exist:

| Box | Image | For |
| --- | --- | --- |
| `ubuntu` | `quay.io/toolbx/ubuntu-toolbox:24.04` | claude-desktop, shipped only as `.deb` |
| `dev` | `registry.fedoraproject.org/fedora-toolbox:44` | `-devel` packages for building |

`DEB_BOX` and `distrobox_ensure` live in `modules/packages/lib.sh` so several
apps share one box rather than each pulling an image of its own.

## Containers come in two shapes

The ranking above is about *acquiring* software. A container that has to keep
running is a second question, and distrobox is the wrong tool for it: it exists
to share `$HOME` with an interactive shell, not to supervise a daemon.

A long-running service takes a **podman quadlet** instead -- a `.container`
file symlinked into `~/.config/containers/systemd/`, which podman's systemd
generator turns into a `--user` service. Rootless, no root and state in `$HOME`,
so it keeps what the ranking protects while podman owns the lifecycle, the
image pull and the cleanup. The alternative, a hand-written unit wrapping
`podman run`, means an `ExecStartPre`/`ExecStopPost` pair that has to stay
correct through every failure mode.

| Shape | Mechanism | For | Example |
| --- | --- | --- | --- |
| Interactive box | distrobox | a shell with the host's `$HOME` | `dev-box` |
| Long-running service | podman quadlet | a daemon | `open-webui`, `searxng` |

Two consequences are worth writing down, because both have already cost a
debugging session:

- **Quadlet units are generated, so they cannot be `systemctl --user enable`d.**
  There is no unit file to link. The `[Install]` section inside the
  `.container` is what the generator acts on.
- **Editing a `.container` does not restart anything.** The symlink path is
  unchanged, so an `app_check` comparing paths still passes while systemd keeps
  running the unit generated from the old file. An app therefore asserts
  something observable about the *running* container -- the address it is bound
  to, the model it was told to use -- rather than only the files on disk.

Configuration that the host must own is passed by `EnvironmentFile=`, which
becomes `--env-file` and reaches inside the container. A systemd drop-in does
not: it sets the variable on the `podman` process, where the application never
sees it.

## How distrobox works

The property everything rests on is that **distrobox is not a sandbox**. It runs
a container with `--userns keep-id` and bind-mounts the host's real `$HOME` at
the same path with the same uid. A file the container writes under `$HOME` is
the same inode the host opens, and AF_UNIX connections cross the namespace
boundary because a unix socket is a filesystem object, not a network one.

That is the entire difference from Flatpak, and it is the reason a container can
host something whose whole output is a socket in `$HOME` where a Flatpak cannot.
Measured directly while choosing 1Password's route: the app in a box did put a
working agent socket on the host, which the Flatpak never did. Flatpak's
isolation is the feature; distrobox's lack of it is the feature.

Also shared by default: the session D-Bus at `/run/user/$UID/bus`, the Wayland
and X11 sockets, and the udev/dev tree. `distrobox-export` writes host entry
points -- a `.desktop` for an app, a wrapper script in `~/.local/bin` for a
binary -- each of which runs `distrobox-enter` and starts the container on
demand.

Reference: [distrobox useful tips](https://distrobox.it/useful_tips/),
[distrobox-export](https://distrobox.it/usage/distrobox-export/).

## Container limitations

These are the edges found in practice, not a general list:

- **The system bus is not at its canonical path.** It is reachable at
  `/run/host/run/dbus/system_bus_socket`, so anything using polkit needs
  `DBUS_SYSTEM_BUS_ADDRESS` pointed at it. 1Password's "unlock with system
  authentication" is the case that cares.
- **Peer authentication does not survive the container boundary.** 1Password's
  CLI integration refuses across it in both directions: an `op` on the host
  against an app in the box, and an exported `op` from the box against an app on
  the host, both fail with "connecting to desktop app". Host-to-host works, from
  either package source. The boundary is what matters, not where either came
  from -- and note the boxes run with `PidMode=host`, so this is not a pid
  namespace effect. The exact mechanism is unverified.
- **Exported apps do not autostart.** `distrobox-export` writes a launcher, not
  an autostart entry. An app whose value is a background service rather than a
  window needs its own `~/.config/autostart` entry, pointing at the same
  `distrobox-enter` command.
- **A box built from a stale image drifts from the host.** For `dev` this is the
  whole point of pinning the image to the host's Fedora release: binaries built
  inside link the host's libraries when they run, so the headers compiled
  against and the sonames loaded have to be the same version. `doctor.sh`
  reports a `dev` image that has fallen behind.
- **Entering a box costs a container start.** Fine for a GUI app or a build, not
  for anything on a hot path. This is why `$EDITOR` stays on the host.
- **Shared `$HOME` cuts both ways.** Two installs of the same app, one host and
  one container, share their config directory and will fight over it.

## Consequences

- The same app can arrive by different routes on different machines -- brew on
  Bazzite, dnf on Workstation. Version skew between machines is possible and
  accepted; pinning versions is a bigger commitment than this repo wants.
- Homebrew's Linux builds are less exercised than its macOS ones. If a formula
  misbehaves, the fallback is to install natively and let `app_check` find it.
- GUI apps under Flatpak are sandboxed. That is usually fine and occasionally is
  not. emacs is native because a development editor has to reach compilers, LSP
  servers and toolchains outside the sandbox. 1Password comes from
  `ublue-os/tap`, which packages 1Password's own Linux tarball: its agent cannot
  cross a Flatpak sandbox and its rpm cannot be layered, and of the routes that
  leave a working socket on the host, brew is the one that also keeps `op`, the
  polkit policy and browser integration working without special handling.
  Trusting that tap is a real decision -- its casks sudo into
  `/etc/polkit-1/actions` and set setuid bits -- and is named in the app rather
  than granted broadly.
- Sandbox limits are the thing to check before choosing Flatpak, and they are
  not always visible from the app's description. The Flathub manifest's
  `finish-args` is the authority: an app with no `--filesystem=home` cannot
  write anywhere the rest of the system will see.
- `app_check` tests for the *result* (is the binary there, is the Flatpak
  installed) rather than for a package name, so an app installed by some other
  means is correctly left alone.
- Boxes are state that lives outside the repo. `install.sh` recreates them from
  nothing, but their contents are not tracked; a box is rebuilt, not restored.
- Container images are a second update stream. Neither `bootstrap.sh` nor
  `rpm-ostree upgrade` updates what is inside a box; that is `apt`/`dnf` in the
  box, unprompted by anything here.
- Containers do not make an app safer. There is no sandbox: an app in a box has
  the same access to `$HOME` as one on the host. The reason to use a box is
  packaging, never confinement.
