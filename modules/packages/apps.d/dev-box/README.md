# dev-box

A Fedora toolbox holding the `-devel` packages needed to build against system
libraries.

```sh
distrobox enter dev -- cargo build --release
```

## Why a container

Crates that bind system libraries -- `hidapi` wants `libudev.pc` -- need
`-devel` packages no Fedora Atomic image ships. Those are build-time only, so
layering them would carry headers on the host across every image update to
produce binaries that never load them (ADR 0005).

## How it is set up

The box is stopped once provisioned and stays that way; `distrobox enter`
starts it on demand. `doctor.sh` has to look inside to report what is there, so
it starts the box and stops it again rather than leaving one running.

The image is pinned to the host's Fedora release, so the headers compiled
against and the sonames the binary loads on the host are the same version.
`doctor.sh` reports a box whose image has fallen behind the host.

Homebrew is mounted at its own prefix, which its bottles hardcode, so
`~/.bashrc` puts the host's rustup on PATH inside the box and there is no second
toolchain to keep in step.
