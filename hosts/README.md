# hosts

One file per machine: `<hostname>.modules`, listing the modules that machine
should run. One name per line, `#` for comments, blank lines ignored.

```
# hosts/bazzite.modules
keybindings
packages
```

`bootstrap.sh` reads `hosts/$(hostname).modules`. With no matching file it runs
every module and says so, which is the right default for a fresh install -- add
a host file when a machine needs to diverge, not before.

## Hostname is a weak identifier

Fedora ships `/etc/hostname` empty and lets systemd fall back to
`DEFAULT_HOSTNAME` from `/etc/os-release`, so a machine that has never had a
hostname set reports `fedora` -- and so does every other such machine, including
Bazzite, which inherits the same default. Two unrelated installs will happily
share one host file.

Set it explicitly on each machine:

```sh
sudo hostnamectl set-hostname bazzite
hostnamectl status | grep Static      # should no longer say (unset)
```

Or bypass the guesswork entirely:

```sh
./bootstrap.sh --host bazzite
```

Anything a module needs to vary beyond on/off belongs in that module's own
config, not here.
