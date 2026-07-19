# hosts

One file per machine: `<hostname>.modules`, listing the modules that machine
should run. One name per line, `#` for comments, blank lines ignored.

```
# hosts/fedora.modules
keybindings
```

`bootstrap.sh` reads `hosts/$(hostname).modules`. With no matching file it runs
every module and says so, which is the right default for a fresh install --
you add a host file when a machine needs to diverge, not before.

Find your hostname with `hostname`. Note that this is the *current* hostname, so
renaming a machine means renaming its file.

Anything a module needs to vary beyond on/off belongs in that module's own
config, not here.
