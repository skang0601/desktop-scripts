# doom

The tracked Doom config. `../emacs.sh` symlinks this directory to `$DOOMDIR`
(`~/.config/doom`, or `~/.doom.d` on a machine already using the legacy layout),
so edits here are live and land in the repo.

| file | holds |
| --- | --- |
| `init.el` | which Doom modules are enabled. **Changing it needs `doom sync`.** |
| `config.el` | user configuration. No sync needed. |
| `packages.el` | extra packages and recipe overrides. Needs `doom sync`. Currently only comments. |

What this config adds beyond stock Doom is in [../README.md](../README.md): the
local LLM setup, its tools, and the keybindings.

## Doom 2.2.0 moved the modules

Doom's own modules are **not** in `~/.config/emacs/modules/` any more. That
directory holds only `doom`. They live in:

```
~/.config/emacs/sources/doom+/modules/{tools,config,lang,...}
```

Grepping the old path finds nothing and reads as "the module does not exist",
which is wrong. `:tools llm` is at `sources/doom+/modules/tools/llm/`, and the
keybindings it ships are in `sources/doom+/modules/config/default/`
(`+emacs-bindings.el` and `+evil-bindings.el`, one of which applies depending on
whether `:editor evil` is enabled — here it is **not**).

## Extending a module's package

Doom already configures gptel in `:tools llm`. The documented way to add to that
from `config.el` is a deferred block — `after!` (or `with-eval-after-load`),
which is what `getting_started.org` and the llm module's own README say. A
second `use-package!` for the same package is not the idiom: it is more
machinery for the same effect, and without a deferring keyword it eagerly loads
the package at startup, which `getting_started.org` lists under "common
mistakes".

Two things that look like they work and do not:

- **`:ensure` is inert.** Doom replaces use-package's ensure function with a
  no-op that logs `Ignoring ':ensure t'`. It has never meant "fetch from
  GitHub" in any case. Packages are declared with `package!` in `packages.el`,
  which *only* works in a `packages.el` — the macro errors elsewhere.
- **A recipe override keeps the module's pin.** `package!` merges plists
  key-by-key, so declaring only `:recipe` leaves `:tools llm`'s pinned commit in
  place and straight will try to find that hash in the new repo. Pass `:pin nil`
  too:

  ```elisp
  ;; packages.el
  (package! gptel :recipe (:host github :repo "karthink/gptel") :pin nil)
  ```

  Then `doom sync -u` — plain `doom sync` does not pick up recipe changes.

## map!

Keys are **strings**, never bare symbols. `"L"`, not `L`; a bare symbol reaches
`define-key` as a variable reference and Doom fails to boot with
`(void-variable L)`. `:desc` goes immediately before the key it describes.

`:prefix` has two forms and they are not interchangeable:

| form | effect |
| --- | --- |
| `:prefix "o l"` | adds to whatever is already bound under that prefix |
| `:prefix ("l" . "llm")` | **replaces** the prefix with a fresh keymap |

The docstring warns that "providing a DESCRIPTION here will unset any previous
keys on PREFIX", and it means it: the cons form binds the prefix key to a new
empty sparse keymap first. Using it under `<leader> o` to add a binding silently
deletes the nine gptel bindings `:tools llm` puts there — the additions work,
the originals vanish, and nothing errors.

## Verifying a change

`emacs --batch` does not work: Doom's CLI machinery intercepts it and dies with
a `doom-cli-error` backtrace. Use a throwaway daemon instead, which loads the
real config:

```sh
emacs --fg-daemon=check &
emacsclient -s check --eval '(key-binding (kbd "C-c o l l"))'
emacsclient -s check --eval '(progn (require (quote gptel)) gptel-tools)'
emacsclient -s check --eval '(kill-emacs)'
```

A config error shows up as `An error occurred while booting Doom Emacs` in the
daemon's output rather than as a failed command, so check that too — the daemon
still starts.

Registering something is not the same as activating it. `gptel-make-tool` only
adds to gptel's registry; `gptel-tools` is what is sent with a request and
defaults to empty, so a tool can exist and still be invisible to the model.
Assert the thing the model actually sees, not the thing the config declared.
