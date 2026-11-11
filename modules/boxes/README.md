# boxes

distroboxes, for software the host cannot package (ADR 0005):

| Part | Box | For |
| --- | --- | --- |
| [dev-box](dev-box) | `dev`, Fedora toolbox at the host's release | `-devel` headers for building against system libraries, without layering |
| `claude-desktop.sh` | `ubuntu` | Anthropic's official apt repo; they ship Debian/Ubuntu only. The launcher is exported to the host |

```sh
./install.sh --dry-run
```

A box shares `$HOME` with the host at the same path and uid, so files written
inside are the host's own. That is what makes a box useful and also why it is
no sandbox: an app in a box has the same access to `$HOME` as one on the host.
Vendors shipping only `.deb` share the `ubuntu` box (`DEB_BOX` in
[lib.sh](lib.sh)) rather than each pulling an image.
