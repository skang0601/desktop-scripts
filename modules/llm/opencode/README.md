# opencode

A standing OpenCode server for the phone, served over the tailnet by the
[tailscale](../../tailscale) module. It runs `opencode serve` in a rootless
podman container that can edit files in one directory and reach nothing else
on the desktop.

```sh
./modules/llm/install.sh
```

The desktop app's own server is no substitute: it listens on a random port
only while the app is open, and it runs with everything this user can reach.

## What it can reach

| | Inside the container |
| --- | --- |
| `~/Workspace/phone` | mounted at `/workspace`, read-write: the only host files it sees |
| Its config | `~/.local/share/opencode-sandbox-config`, mounted read-only |
| Its state | `~/.local/share/opencode-sandbox`: sessions, the OpenAI login, caches |
| Uploads | `~/.local/share/opencode-sandbox-uploads`, at `/tmp/opencode` |
| ollama | `127.0.0.1:11434`, forwarded by pasta |
| The internet and LAN | reachable |
| The rest of `$HOME`, ssh keys, the 1Password agent, keyrings, browser profiles, the session D-Bus | not mounted |
| Other host loopback ports (searxng, the desktop app) | not reachable |

The container runs as this user's uid (`UserNS=keep-id`) with every capability
dropped, `NoNewPrivileges`, and a read-only root filesystem. Its port is
published on the host's loopback only, so `tailscale serve` is the one way in.

## Models

`sandbox/opencode.json` uses OpenAI as the orchestrator and the local ollama
models as subagents, with the desktop app's `AGENTS.md` for delegation. Every
other provider is denied. The OpenAI login is made once from the phone's
browser (Settings > Providers) and lives only in the sandbox's state
directory. The desktop's credential is never copied in.

Policies are evaluated in order and the last match wins, so `deny *` comes
first and the allowed providers after it.

## Access

The API under `/api` requires HTTP basic auth: user `opencode`, with the
password in `~/.config/opencode-server/env` (mode 600, generated on first
install, never in the repo). The static web app shell at `/` is public and
holds no data. The installer and `doctor.sh` both check that an
unauthenticated request to `/api/session` gets a 401.

## Container details

- **`Tmpfs=/tmp:rw,notmpcopyup`.** Without `notmpcopyup`, podman seeds the
  tmpfs from the image's `/tmp`, including a root-owned `/tmp/opencode`, and
  under `keep-id` the server cannot create its upload directory there.
- **Uploads are a volume.** Sessions refer to attachments by their path under
  `/tmp/opencode/uploads/`, so they have to survive a restart.
- **The image is pinned** to the desktop app's OpenCode version, so both read
  the same config schema.
- **Editing the `.container` restarts nothing.** The installer restarts the
  unit after linking it.
