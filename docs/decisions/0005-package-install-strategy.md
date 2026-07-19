# 0005 - Prefer user-level installs over layering

- Status: accepted
- Date: 2026-07-19
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

## Decision

Installers pick a method by how little it disturbs the system:

1. **Homebrew** for CLI tooling -- user-level, no reboot, no layering.
2. **dnf** on traditional systems.
3. **Flatpak** for GUI apps.
4. **Vendor installers** where nothing else is published, confined to `$HOME`.
5. **`rpm-ostree` layering** last, with an explicit reboot warning.

Every app declares an `app_check` that gates its install, so the module is
idempotent and re-running it after adding an entry only installs the new one.

The keybindings module is the standing exception: keyd needs root-level evdev
access, so it layers. That is the case layering exists for.

## Consequences

- The same app can arrive by different routes on different machines -- brew on
  Bazzite, dnf on Workstation. Version skew between machines is possible and
  accepted; pinning versions is a bigger commitment than this repo wants.
- Homebrew's Linux builds are less exercised than its macOS ones. If a formula
  misbehaves, the fallback is to install natively and let `app_check` find it.
- GUI apps under Flatpak are sandboxed. That is usually fine and occasionally
  is not, which is why emacs is installed natively instead: a development editor
  has to reach compilers, LSP servers and toolchains outside the sandbox.
- `app_check` tests for the *result* (is the binary there, is the Flatpak
  installed) rather than for a package name, so an app installed by some other
  means is correctly left alone.
