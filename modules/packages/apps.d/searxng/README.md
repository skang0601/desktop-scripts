# searxng

A local metasearch engine on `127.0.0.1:8888`, used as the web-search backend
for both [open-webui](../open-webui) and Doom's gptel tools.

Self-hosted rather than an API service so there is no key to hold and no
account, and so one backend serves both consumers: open-webui has a native
`searxng` engine, and the Emacs tool queries the same JSON endpoint.

## The JSON API is off by default

The image ships `formats: [html]`, and SearXNG answers **403** to
`format=json` — which is exactly what both consumers send. `settings.yml` here
adds `json`, and `use_default_settings: true` keeps the image's ~3000-line
configuration as the base so this file does not have to track upstream's engine
list.

`limiter` is left off. Its bot detection rejects non-browser clients, which is
what both consumers are. That is only safe because the service is bound to
loopback.

`app_install` proves the JSON endpoint answers rather than assuming it, since
this is the whole point of the override.

## Loopback is enforced by podman, not by the app

`PublishPort=127.0.0.1:8888:8888`, and deliberately **not** `Network=host`.

This image serves through granian, which ignores `SEARXNG_BIND_ADDRESS` and
listens on all interfaces whatever that variable is set to. Under host
networking it therefore lands on the LAN, and setting the variable gives a
false sense that it has not. Publishing the port puts the restriction in podman,
where the application cannot override it, and open-webui still reaches it
because host networking shares the host's loopback.

`app_check` asserts the bound address rather than only reporting it, so a
`.container` edit is enough to get the change applied. The symlink path is
identical when only file contents change, and systemd will keep running a unit
generated from the old version — the bound address is the observable that says
which one is live.

## settings.yml is copied, not symlinked

A symlink into the repo resolves to a path that does not exist inside the
container, so `app_install` copies it and `app_check` uses `cmp` to notice the
repo's copy changing.

Only the file is mounted, not the directory holding it. The entrypoint chowns
its config directory to `searxng:searxng`, which under rootless podman lands on
a mapped subuid the host user can no longer write — mounting the directory
makes the *next* install fail with `EPERM` on its own settings file. If that
has already happened, `podman unshare chown -R 0:0 ~/.local/share/searxng`
takes it back: inside that namespace the host user is uid 0.

## Secret

`SEARXNG_SECRET` is generated once into `~/.local/share/searxng/secret.env` at
mode 600 and kept out of the repo. It is not regenerated on later runs, since
rolling it would invalidate sessions for no gain.
