# tailscale

Joins this machine to the tailnet and serves the [OpenCode
server](../packages/apps.d/opencode) on its tailnet address, so the phone can
work in projects on this desktop.

Bazzite ships `tailscale` in the image, so there is nothing to install or
layer. The module enables `tailscaled`, runs `tailscale up` on the first run
(it prints a login URL and waits), and configures `tailscale serve`.

## Served, not bound

The OpenCode server listens on `127.0.0.1:4096`. `tailscale serve` terminates
HTTPS on `https://<host>.<tailnet>.ts.net` and proxies to it, so the server is
reachable from the tailnet and not from the LAN, and the certificate comes from
Tailscale. The first serve on a tailnet asks for HTTPS certificates to be
enabled in the admin console and prints the link.

The server's own password still applies. Tailscale decides which devices can
connect, and the password, from `~/.config/opencode-server/env` with user
`opencode`, decides who gets a shell on this machine.

## Order

Run after `packages`, since it proxies to the `opencode` app's server. The
host file lists it after `packages` for that reason.
