# emacs

Emacs, Doom, Doom's dependencies, and the tracked config in `doom/`, which is
symlinked into place so edits land in the repo. [doom/README.md](doom/README.md)
covers that config's own layout and the Doom idioms it depends on.

## Not Flatpak

As a development editor it needs to reach compilers, LSP servers and toolchains
outside the sandbox, and punching those through one by one is worse than
installing it on the host.

Note that brew's Linux bottle is built `--without-x` and takes precedence on
PATH once `brew shellenv` has run, so a working GUI build can be shadowed by
one that only ever opens a terminal frame. `doctor.sh` checks for that
specifically.

## Dependencies

They come from the modules enabled in `doom/init.el`: `git`, `ripgrep` and `fd`
for `:completion` and `:tools lookup`, and `shellcheck` for `:checkers syntax`
against `:lang sh`. Adding a module may add a dependency -- `doom doctor` will
say so.

## Local LLM

`:tools llm` is enabled, which brings in [gptel](https://github.com/karthink/gptel)
(plus `gptel-magit` and `ob-gptel`, since `:tools magit` and `:lang org` are on).
Doom's module defaults to ChatGPT and wants an API key; `config.el` points it at
the [ollama](../ollama) this module's sibling installs instead, so nothing leaves
the machine and no key is involved. It is set as `gptel-backend` rather than
offered alongside a cloud default.

The model tag is **not** named in `config.el`. ollama picks it from the GPU's
VRAM and records it in `~/.local/share/ollama/roles.env`, which `+ollama-role`
reads; `+ollama-models` then asks the running server what is actually pulled
and the two are reconciled, since a bare tag like `qwen3.5` is reported as
`qwen3.5:latest`. `+ollama-fallback-model` covers both being unavailable, and
the request has a two-second timeout because it runs when gptel first loads --
a hang there would block the editor rather than a background job.

Changing which model ollama pulls therefore needs no change here.

### Keybindings

Doom's `:tools llm` module already binds gptel under `<leader> o l` from
`config/default`. `config.el` only adds what it leaves out:

| key | command | |
| --- | --- | --- |
| `L` | `+llm/open-in-same-window` | Doom ships this only in `+evil-bindings.el`, and this config has no `:editor evil` |
| `c` | `gptel-context-remove-all` | clear context |
| `d` | `gptel-context-remove` | |
| `y` | `gptel-context-add-current-kill` | |
| `k` | `gptel-abort` | |
| `t` | `gptel-tools` | |
| `p` | `gptel-system-prompt` | |
| `P` | `gptel-preset` | |

The `map!` uses `:prefix "o l"` rather than `:prefix ("l" . "llm")`. The cons
form defines a *new* prefix command and binds it over the existing one, which
silently drops every binding Doom put there -- the additions work and the
originals vanish.

### Tools

gptel is given the same two capabilities open-webui has:

| tool | confirms? | |
| --- | --- | --- |
| `web_search` | no | queries the local [searxng](../searxng) |
| `read_file` | no | |
| `list_directory` | no | |
| `run_command` | **yes** | shell on this host |

`gptel-make-tool` only registers a tool; `gptel-tools` is the list actually
sent with a request, and it is empty by default. Registering without setting it
leaves the model unaware the tools exist, and it will say it cannot search the
web. `config.el` sets all four; `<leader> o l t` picks them per buffer.

`run_command` runs on the host as you, with your files and your credentials.
There is no sandbox: `:confirm t` is the whole of the safety story, and gptel's
prompt showing the exact command is what stands between the model and the
machine. `gptel-confirm-tool-calls` is left at `auto`, which means each tool's
own `:confirm` decides -- so setting it to nil globally would silently disarm
this.

Results are truncated to `+gptel-tool-max-chars`, because a tool result is
spent from the model's context window and a whole file would crowd out the
conversation.

## Path layout

A mess of Doom's own history, so it is detected rather than forced:

| | current | legacy |
| --- | --- | --- |
| Doom | `~/.config/emacs` | `~/.emacs.d` |
| config | `~/.config/doom` | `~/.doom.d` |

The legacy paths win when both exist. A fresh install gets the current layout; a
machine already using the legacy one keeps it, since relocating a working Doom
is not this script's business. Any real config directory found in the way is
renamed to `.bak` before the symlink goes in.

`init.elc` is a build artifact of `doom sync` and is not tracked.
