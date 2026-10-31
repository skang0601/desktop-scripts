# ollama

Local coding models. Editor integrations talk to it over `127.0.0.1:11434`, its
default.

## Not brew

Homebrew's Linux bottle ships only `libggml-cpu-*.so`. There is no
`libggml-cuda.so` and no bundled cublas in it, because the formula declares no
CUDA toolkit and passes no `-DGGML_CUDA`. A brew install runs every token on
the CPU with nothing in the output to say so. The vendor tarball carries the
CUDA runners, so that is what this app installs -- ADR 0005 rank 5, a vendor
build confined to `$HOME`.

It unpacks to `~/.local/share/ollama` with the binary symlinked into
`~/.local/bin`, which [shell](../../../shell) already puts on `PATH`. Nothing is
written outside `$HOME` and no `sudo` is involved. `ollama` resolves its runners
through `/proc/self/exe`, which follows the symlink, so `lib/ollama` is found
relative to the unpacked prefix rather than to `~/.local/bin`.

The release asset is `ollama-linux-amd64.tar.zst`, pinned to `$VERSION`.
Upstream moved away from `.tgz`, and the old `ollama-linux-amd64.tgz` URL 404s
on current releases.

## Choosing the GPU and the model

Neither the cards nor the model are named in the script. `nvidia-smi` reports
`display_active` per GPU, so the installer prefers a card with no display
attached -- inference on the card driving GNOME competes with the compositor
for VRAM and stutters the desktop -- and falls back to the largest card when
every card drives one.

When all the cards together clear a larger tier than the preferred card does
alone, the installer pins all of them instead; see [Pooling
cards](#pooling-cards). On this desktop that pools the 2070 Super and the 4080
Super for `qwen3.8:27b`, without either card appearing in the script.

The pin is by GPU UUID rather than by numeric index, which PCI re-enumeration
reorders across reboots. `CUDA_VISIBLE_DEVICES` accepts either, comma-separated
for several cards.

### CUDA_VISIBLE_DEVICES is not enough on its own

It constrains the CUDA backend only. Ollama also enumerates GPUs over Vulkan,
which ignores it, and then schedules onto whichever card has the most free VRAM
-- the display card, precisely the one the pin exists to avoid. The failure is
silent: the unit looks correct, `nvidia-smi` shows the wrong card busy, and the
log admits it only in passing.

```
inference compute  filter_id=GPU-060bb078…  library=CUDA    "RTX 2070 SUPER"
selecting single GPU  library=Vulkan  name=Vulkan0  "RTX 4080 SUPER"  available_gpu_count=2
```

The unit therefore also sets `OLLAMA_VULKAN=0`, leaving CUDA as the only
backend -- correctly pinned, and the faster of the two on NVIDIA. `app_check`
verifies both variables, since with only the first the pin reads as fine while
inference runs on the wrong card.

`OLLAMA_LLM_LIBRARY=cuda` looks like the knob for this and is not: it matches
nothing and drops the server to CPU-only inference.

VRAM selects from `MODEL_TIERS`, largest tier first, with thresholds set above
the raw Q4_K_M file size to leave room for context. An 8192MiB card on its own
selects `qwen3.5:4b`.

The 9b row asks for a 12GB card even though it runs on 8GB. Measured on the
2070 Super:

| model | VRAM used | throughput |
| --- | --- | --- |
| `qwen3.5:9b` | 7072MiB of 8192 | 60 tok/s |
| `qwen3.5:4b` | 4972MiB of 8192 | 92 tok/s |

Both are honest GPU speeds; a model genuinely spilling to host memory runs an
order of magnitude slower. The 8GB tier takes the faster one and the headroom.

Ollama reports `100% GPU` for both while llama.cpp keeps a ~500MiB `CPU model
buffer` either way. That is the token embedding matrix, and it is structural
rather than VRAM pressure -- it is the same size on 4b, which has gigabytes to
spare -- so it is not a signal to size tiers by. `offloaded 34/34 layers` counts
only the repeating layers and says nothing about it.

### Why a general model and not a coder one

There is no `qwen3.5-coder`, and the older `qwen2.5-coder` cannot do tool
calling. It advertises the `tools` capability and then emits a bare JSON object
instead of the tagged call its template parses, so ollama returns
`tool_calls: null` with the JSON left in `content`. Anything that offers it
tools -- open-webui injects its knowledge-base tools by default -- prints that
JSON into the chat instead of answering. Measured against ollama alone, no UI
involved:

| model | same request with `tools` |
| --- | --- |
| `qwen2.5-coder:7b` | `tool_calls: null`, JSON leaks into `content` |
| `qwen3.5:9b` | `tool_calls` parsed |

The same request without `tools` answers normally on both, so it is the model's
limit and not a misconfiguration.

### Pooling cards

`qwen3.8:27b` (16.8GB of weights, plus a 0.9GB vision projector) fits neither
card alone, and it is dense, so every weight is read for every token. The
cards are pooled rather than letting it spill to system RAM. ollama splits the
model by layer and the cards take turns per token, so pooling adds capacity
and not speed. But RAM is roughly a tenth of VRAM's bandwidth, so any layers
left there cost more than the whole difference between the two cards.

Measured on the 4080 Super + 2070 Super (ollama 0.40.13, Q4_K_M, q8_0 KV):

| placement | context | layers on GPU | tok/s |
| --- | --- | --- | --- |
| ollama's default `--fit` margin (1912MiB per card) | 32K | 59/66 | ~28 |
| `--fit`, margins 1024/256 | 32K | 66/66 | 50-55 |
| `--fit`, margins 1024/256 | 64K | 62/66 | ~37 |
| `--tensor-split 7936,13304`, projector on CPU | 64K | 66/66 | 52-59 |

`--fit` underestimates what fits at long contexts, leaving ~2GB per card
unused while spilling, so a pooled tier sets the split explicitly. That also
turns `--fit` off entirely. The installer derives the split from each card's
total VRAM less a reserve (256MiB headless, 3GiB on the display card for
GNOME and its apps), and keeps the vision projector on the CPU, where it costs
time only when an image is attached.

Two consequences follow:

- The split cannot back off at load time. If something holds more than ~3GB
  of the display card when the model loads, the load fails with a CUDA OOM
  rather than spilling.
- `OLLAMA_CONTEXT_LENGTH` and the split apply to every model on the server. A
  full-attention model's KV cache is much larger than qwen3.8's hybrid one,
  and `devstral-small-2:24b` at 64K OOMs on the 2070's share. A second model
  needs a Modelfile alias with its own `num_ctx`; see
  [opencode-desktop](../opencode-desktop).

The iGPU is no help here. It has no memory of its own, and ollama only reaches
it through Vulkan, which is disabled so that the CUDA pin holds.

qwen3.8 needs ollama 0.40 or later. Older clients get a 412 from the registry.

### The chosen model is written down

`app_install` records it at `~/.local/share/ollama/roles.env`:

```
OLLAMA_MODEL=qwen3.8:27b
OLLAMA_CONTEXT_LENGTH=65536
```

The tier table is the only thing that knows what this machine picked, and two
consumers need the answer: [open-webui](../open-webui)'s installer for
`DEFAULT_MODELS`, and Doom's `config.el` for `gptel-model`. Neither guesses
from the name. `ollama pull qwen3.5` lands as `qwen3.5:latest`, so `app_check`
normalises a bare tag before comparing against what `ollama list` reports.

```sh
OLLAMA_MODEL=qwen2.5-coder:14b ./modules/packages/install.sh ollama
OLLAMA_GPU_UUID=GPU-... ./modules/packages/install.sh ollama
OLLAMA_VERSION=0.33.0 ./modules/packages/install.sh ollama
```

It runs as its own `systemctl --user` unit rather than through `brew services`
because the pin has to be an `Environment=` line on the exact process running
`ollama serve`, and brew services' Linux integration gives no way to set one.

A machine with no CUDA card reports blocked rather than failed -- `ollama` on
the CPU is not worth installing here.

## Why the tier table is not a lookup

No online API takes hardware and returns a model, so the table cannot be
replaced by a query.

`https://ollama.com/api/experimental/model-recommendations` is real and
unauthenticated, and annotates entries with `vram_bytes`, but it is a single
global list that ignores query parameters -- the response is byte-identical
whatever VRAM is passed -- and its local entries currently need 12GB and 28GB,
so it offers nothing that fits an 8GB card. HuggingFace's API gives exact file
sizes but no fit judgement, and the model memory calculator Space exposes no
callable endpoint.

Ollama does not choose a quantization either: a tag like `:latest` is a fixed
registry pointer, and the runtime only decides how many layers to offload once
the model is already chosen.

`registry.ollama.ai/v2/library/<model>/manifests/<tag>` is the stable part of
that stack and returns exact bytes for a tag, so it is a reasonable future
addition for a disk-space check. It cannot enumerate tags.

## Cleaning up the install script

Ollama's own install script (`curl -fsSL https://ollama.com/install.sh | sh`)
lands a root-owned tree in `/usr/local`, an `ollama` system user, and a
system-wide unit that would bind 11434 ahead of the `--user` unit here.
`app_install` removes all three before unpacking.

The system user outlives an `rm` of the unit file, so each trace is checked
separately rather than treating the unit as a proxy for the whole install.
Models that install already pulled are left under
`/usr/share/ollama/.ollama/models` and reported, rather than deleted as a side
effect of switching install methods.
