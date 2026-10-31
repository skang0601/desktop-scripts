# opencode-desktop

OpenCode's desktop app, from the `opencode-desktop` brew cask, which installs
OpenCode's own AppImage. The app runs the same opencode server as the CLI, and
both read `~/.config/opencode`.

## Config

`opencode.json` and `AGENTS.md` are symlinked from here into
`~/.config/opencode`, so edits made there land in the repo. `service.json`
beside them is the app's generated server password and is not managed.

The config uses the current `providers` and `agents` keys. Its schema marks
the older `provider` and `agent` keys as deprecated.

- The primary agent runs a hosted model.
- `explore` and `general` run `ollama/qwen3.8:27b`, the model the
  [ollama](../ollama) tier table picks for the pooled 4080 + 2070.
- `coder` runs `ollama/devstral-small-2:24b-48k`, for bounded implementation
  and debugging work.

`AGENTS.md` says when to delegate to which. The two local models cannot both
stay loaded (~31GB against 24GB of VRAM), so it asks for one delegation per
task rather than alternating models mid-task.

Models are named literally rather than read from ollama's `roles.env`, so on
a host where the tier table picks something else the qwen agents name a model
that is not pulled. `app_checks` warns about that.

## The Devstral alias

ollama applies `OLLAMA_CONTEXT_LENGTH` (64K) and the pooled tensor split to
every model. Devstral uses full attention, so its KV cache at 64K is ~5GB,
against ~2.3GB for qwen3.8's hybrid attention, and the load fails with a CUDA
OOM on the 2070's share. `devstral-small-2-48k.Modelfile` pins it to 48K,
which stays fully on the cards. The installer pulls the base model, builds
the alias, and rebuilds it if the Modelfile's `num_ctx` changes.

Measured against qwen3.8 on the same server:

| | qwen3.8:27b @ 64K | devstral-small-2 @ 48K |
| --- | --- | --- |
| generation | 52-59 tok/s | ~35 tok/s |
| prompt processing | 761 tok/s | 1303 tok/s |
| reasoning tokens | on by default | none |
