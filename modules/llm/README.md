# llm

The local LLM stack, set up in dependency order:

| Part | What it is |
| --- | --- |
| [ollama](ollama) | the model server, from the vendor tarball: brew's bottle has no CUDA. Pins the GPUs and picks a model for them |
| [searxng](searxng) | local metasearch on loopback, as a podman quadlet; the web-search backend for gptel |
| [opencode-desktop](opencode-desktop) | config for the desktop app (a Brewfile cask), and the Devstral coder model |
| [opencode](opencode) | a sandboxed `opencode serve` on loopback, as a quadlet, for the phone over [tailscale](../tailscale) |

```sh
./install.sh --dry-run
```

## Quadlets

A long-running service takes a podman quadlet: a `.container` file symlinked
into `~/.config/containers/systemd/`, which podman's systemd generator turns
into a `--user` service. Three properties a part has to account for:

- They are **generated**, so they cannot be `systemctl --user enable`d. The
  `[Install]` section inside the `.container` is what the generator acts on.
- **Editing one restarts nothing.** The symlink path does not change, so an
  `app_check` comparing paths still passes while systemd keeps running the unit
  built from the old file. Assert something observable about the running
  container instead -- the address it is bound to, the model it was given.
- Host-derived configuration goes in via `EnvironmentFile=`, which becomes
  `--env-file` and reaches inside the container. A systemd drop-in does not: it
  sets the variable on the `podman` process, where the application never sees
  it.
