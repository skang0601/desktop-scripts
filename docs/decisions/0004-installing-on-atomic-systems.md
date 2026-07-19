# 0004 - Support atomic/image-based systems in every module installer

- Status: accepted
- Date: 2026-07-19

## Context

This repo is headed for Bazzite, an image-based (rpm-ostree / bootc) desktop.
That breaks the assumption every install script makes by default:

- `dnf install` does not layer onto the running host. On Bazzite, `dnf5` is used
  only to manage repo files; `rpm-ostree install` does the actual install.
- Layering requires a reboot before the package exists, so an installer cannot
  install-then-configure in one pass.
- `/usr` is read-only, which matters for anything installed from source.

The alternative -- keeping a separate Bazzite branch or a second set of scripts
-- means every future module gets written twice and one copy rots.

## Decision

Every module installer detects the system type with `[[ -f /run/ostree-booted ]]`
and branches. The atomic path layers the package, then **exits** with a reboot
notice; re-running after reboot skips the install and proceeds to configuration.
Idempotency is what makes this two-pass flow tolerable.

Configuration always goes to `/etc`, never `/usr`. On ostree systems `/etc` is
writable and a 3-way merge runs on every upgrade: files with no `/usr/etc`
counterpart persist indefinitely, across image updates *and* rebases. So
`/etc/keyd/default.conf` and `/etc/libinput/local-overrides.quirks` survive
without special handling.

## Consequences

- Package layering is a known liability: layered packages can pause image
  updates or block a rebase when a future image conflicts. Bazzite's own docs
  call layering a last resort and warn against third-party COPRs. Accepted for
  keyd specifically -- it isn't in Fedora, and it needs root-level evdev access,
  so Flatpak and Homebrew are not options. Future modules should prefer Flatpak
  or a user-level install where one exists, and only layer when it doesn't.
- **Prefer packages over `make install` on these systems.** keyd built from
  source puts its unit in `/usr/local/lib/systemd/system/`, which systemd on
  Fedora Atomic does not load at boot; the service reports as enabled and never
  starts (keyd issue #1139).
- Bazzite ships `input-remapper` installed and enabled by default, with its
  desktop entry hidden. It grabs the same evdev devices keyd does, so the
  keybindings installer warns when it sees the service enabled.
- Reboots in the middle of a bootstrap are unavoidable on atomic systems. The
  installers say so loudly rather than appearing to have finished.
