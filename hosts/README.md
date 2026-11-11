# hosts

One file per machine: `<hostname>.modules`, listing the modules that machine
should run. One name per line, `#` for comments, blank lines ignored.

```
# hosts/bazzite.modules
keybindings
packages
```

`bootstrap.sh` reads `hosts/$(hostname).modules`. With no matching file it stops
and asks for `--host <name>` or `--all`, since an unmatched hostname more often
means the wrong machine than a fresh one. `doctor.sh` only reads, so there it
checks every module instead.

## Hostname is a weak identifier

Fedora ships `/etc/hostname` empty and lets systemd fall back to
`DEFAULT_HOSTNAME` from `/etc/os-release`, so a machine that has never had a
hostname set reports `fedora` -- and so does every other such machine, including
Bazzite, which inherits the same default. Two unrelated installs will happily
share one host file.

Set it explicitly on each machine:

```sh
sudo hostnamectl set-hostname bazzite
hostnamectl status | grep Static      # shows the name, not (unset)
```

Or bypass the guesswork entirely:

```sh
./bootstrap.sh --host bazzite
```

Anything a module needs to vary beyond on/off belongs in that module's own
config, not here.
