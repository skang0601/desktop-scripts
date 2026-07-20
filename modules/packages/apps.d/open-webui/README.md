# open-webui

A browser front end for [ollama](../ollama), at <http://ai.localhost:1234>.

`ai.localhost` costs nothing: systemd-resolved resolves the whole reserved
`.localhost` TLD to loopback (RFC 6761), so there is no hosts entry to install
and nothing under `/etc` to edit. Any label works -- `chat.localhost` reaches
the same place. `.local` was rejected: it is reserved for mDNS, and getting it
working would mean either editing `/etc/hosts` in place or advertising a
loopback-only service to the whole LAN.

Port 1234 rather than 8080, which is busy enough on a desktop to be worth
avoiding. It is also LM Studio's default server port, so those two cannot share
a machine unmodified.

## Why a container

Open WebUI is published as a container image and nothing else -- no Flatpak, no
rpm, no brew formula -- so ADR 0005's ranking runs out before it reaches
something better. It is rootless podman under a `--user` unit, so it still needs
no root and keeps its state in `$HOME`, which is what the ranking is protecting.

This is the module's first long-running container service; `dev-box` is an
interactive box, not a daemon.

## Quadlet, not a hand-written unit

`open-webui.container` is a [quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html):
podman's systemd generator turns it into `open-webui.service` at daemon-reload.
The container's lifecycle, image pull and cleanup become podman's concern rather
than an `ExecStartPre`/`ExecStopPost` pair that has to stay correct.

The file is symlinked from the repo, so edits land here rather than in
`~/.config`. Quadlet follows the symlink.

Generated units cannot be `systemctl --user enable`d -- there is no unit file to
link. The `[Install]` section inside the `.container` is what the generator acts
on, so `app_install` only reloads and starts.

## Networking

`Network=host`, which is the part worth understanding.

ollama binds `127.0.0.1` only. A bridge-networked container reaches the host
through a gateway address ollama is not listening on, and the usual fix --
setting `OLLAMA_HOST=0.0.0.0` -- would put the model server on the LAN to avoid
putting the UI there. Host networking lets the container use the host's loopback
directly and neither is exposed.

The cost is that the app binds the host's interfaces itself, and the image
defaults to `HOST=0.0.0.0`. `HOST=127.0.0.1` in the quadlet is what keeps the UI
off the LAN, and `app_checks` asserts the listener really is on loopback rather
than trusting that the variable still works.

## Configuration that is not optional

- `OLLAMA_BASE_URL` is set explicitly. The image ships `OLLAMA_BASE_URL=/ollama`,
  which it rewrites to `host.docker.internal` under `ENV=prod`, and an empty
  value makes it probe for a Docker Model Runner on port 12434 instead.
- `WEBUI_SECRET_KEY_FILE` points into the mounted volume. Left alone, the
  container's `start.sh` generates the key into `/app/backend`, which is *not*
  the volume, so every recreate would roll it and log the user out.

## Auth

Left on, which is the default. The first account created becomes the admin
(the role is assigned post-insert once the user count reaches one).

`WEBUI_AUTH=False` is deliberately not used. It does not mean "no login" so much
as "everyone is the admin": the signin handler ignores the submitted credentials
and hands back a token for a built-in `admin@localhost` account, so anything
that can reach the port has full access. It also only works on a fresh data
volume -- with users already present the server refuses to start with auth off.

## State

`~/.local/share/open-webui`, mounted at `/app/backend/data`. It holds
`webui.db` and, if RAG or speech features get used, the whisper,
sentence-transformers and HuggingFace caches, so it can grow well beyond the
image.

The image tag and the port are set in `open-webui.container`, which is the only
place either appears; the script reads them back rather than keeping a second
copy that can drift.
