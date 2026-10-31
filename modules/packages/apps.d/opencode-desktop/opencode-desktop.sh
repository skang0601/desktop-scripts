# shellcheck shell=bash
APP_NAME=opencode-desktop

# Reported with the rest of the local-LLM stack it is a client of.
APP_GROUP="local llm"

CASK=opencode-desktop

# The desktop app runs the same opencode server as the CLI, and both read the
# global config here. service.json beside it is the app's own generated server
# password and is not touched.
CONFIG_DIR="$HOME/.config/opencode"
CONFIG_FILES=(opencode.json AGENTS.md)

# The coder agent runs Devstral, which opencode.json names by this alias. ollama
# applies OLLAMA_CONTEXT_LENGTH and the pooled tensor split to every model, and
# at that 64K Devstral's full-attention KV cache (~5GB, against ~2.3GB for
# qwen3.8's hybrid attention) overflows the 2070's share and fails the load
# with a CUDA OOM. The alias pins it to 48K, which stays entirely on the cards.
CODER_BASE=devstral-small-2:24b
CODER_ALIAS=devstral-small-2:24b-48k
CODER_MODELFILE() { printf '%s/devstral-small-2-48k.Modelfile\n' "$APP_DIR"; }

ROLES="$HOME/.local/share/ollama/roles.env"
role() { awk -F= -v k="$1" '$1 == k { print $2; exit }' "$ROLES" 2>/dev/null; }

app_blocked() {
  have brew && return 1
  echo "no brew; the cask is how OpenCode's own AppImage is installed here"
  return 0
}

cask_installed() { brew list --cask "$CASK" >/dev/null 2>&1; }

configs_linked() {
  local f
  for f in "${CONFIG_FILES[@]}"; do
    [[ "$(readlink -f "$CONFIG_DIR/$f" 2>/dev/null)" == "$(readlink -f "$APP_DIR/$f")" ]] || return 1
  done
}

# Compared against the Modelfile rather than only checking the tag exists, so
# a changed num_ctx in the repo is noticed and the alias rebuilt.
coder_current() {
  local want
  want="$(awk '/^PARAMETER num_ctx/ { print $3 }' "$(CODER_MODELFILE)")"
  ollama show "$CODER_ALIAS" --modelfile 2>/dev/null | grep -qx "PARAMETER num_ctx $want"
}

# opencode.json names its models literally rather than reading roles.env, so on
# a host where ollama's tier table picked a different model the qwen agents
# point at one that is not pulled.
config_names_ollama_model() {
  local model
  model="$(role OLLAMA_MODEL)"
  [[ -n "$model" ]] && grep -q "\"ollama/$model\"" "$APP_DIR/opencode.json"
}

app_check() { cask_installed && configs_linked && coder_current; }

app_install() {
  require_app ollama

  cask_installed || run brew install --cask "$CASK"

  local f
  for f in "${CONFIG_FILES[@]}"; do
    link_config "$APP_DIR/$f" "$CONFIG_DIR/$f"
  done

  if ! coder_current; then
    say "pulling $CODER_BASE (~14GB) for the coder agent"
    run ollama pull "$CODER_BASE" || return 1
    run ollama create "$CODER_ALIAS" -f "$(CODER_MODELFILE)" || return 1
  fi

  config_names_ollama_model \
    || warn "opencode.json does not name ollama's model ($(role OLLAMA_MODEL)); the qwen agents will not load"

  dry || say "restart OpenCode to pick up the config"
}

app_checks() {
  if configs_linked; then
    check_ok "opencode config" "linked to the repo"
  else
    check_fail "opencode config" "$CONFIG_DIR is not linked to the repo" \
      "./modules/packages/install.sh opencode-desktop"
  fi

  if coder_current; then
    check_ok "$CODER_ALIAS" "coder agent model"
  else
    check_fail "$CODER_ALIAS" "missing, or its num_ctx differs from the repo's Modelfile" \
      "./modules/packages/install.sh opencode-desktop"
  fi

  if config_names_ollama_model; then
    check_ok "opencode models" "names ollama's $(role OLLAMA_MODEL)"
  else
    check_warn "opencode models" "opencode.json does not name ollama's $(role OLLAMA_MODEL)" \
      "edit $APP_DIR/opencode.json"
  fi
}
