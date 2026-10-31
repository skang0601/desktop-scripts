# gdm-display

Makes the login screen use the same display layout and scale as the desktop
session, by copying `~/.config/monitors.xml` to GDM.

```sh
./install.sh --dry-run
./install.sh
```

## Why

GDM runs as its own `gdm` user with its own mutter, and reads only
`/var/lib/gdm/.config/monitors.xml`. Without that file mutter auto-detects a
scale. It chose 1x for the Studio Display, while the session runs at 2x.

## Gotchas

- **It's a copy, so it goes stale.** Changing anything in Settings > Displays
  rewrites `~/.config/monitors.xml` and leaves GDM's copy behind. `doctor.sh`
  warns when they differ; re-run `install.sh` to sync them.
- **All saved layouts come along.** mutter picks the `<configuration>` that
  matches the monitors connected at the time, so docked and undocked layouts
  both carry over.
- **SELinux label.** The copy must be labelled `xdm_var_lib_t`. A file carrying
  the user's `config_home_t` label is silently ignored. The installer runs
  `restorecon` after copying.
- `/var/lib/gdm` is host state outside `/usr`, so it survives image updates and
  rebases (see [ADR 0004](../../docs/decisions/0004-installing-on-atomic-systems.md)).
