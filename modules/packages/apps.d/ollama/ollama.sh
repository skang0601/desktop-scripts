# shellcheck shell=bash
APP_NAME=ollama

# Reported together in doctor's grouped output: one local-LLM stack rather than
# three apps scattered through an alphabetical list.
APP_GROUP="local llm"

# The vendor tarball, not brew: brew's Linux bottle ships no CUDA runner, so it
# would run inference on the CPU with nothing in the output to say so. See
# README.md.
#
# qwen3.8 needs a 0.40 client: the registry answers older ones with a 412 and
# "requires a newer version of Ollama" rather than serving the manifest.
VERSION="${OLLAMA_VERSION:-0.40.13}"

# Upstream moved the release asset from .tgz to .tar.zst; the older
# ollama-linux-amd64.tgz URL 404s on current releases.
URL="https://github.com/ollama/ollama/releases/download/v$VERSION/ollama-linux-amd64.tar.zst"

PREFIX="$HOME/.local/share/ollama"
BIN="$HOME/.local/bin/ollama"
UNIT="$HOME/.config/systemd/user/ollama.service"
API=http://127.0.0.1:11434

# min VRAM (MiB), model, context. Weights at the default Q4_K_M quantization
# plus room for the KV cache, so the thresholds sit above the raw file size.
# Descending: the first tier the GPUs clear wins -- see select_target for how
# one card and several are weighed.
#
# One general model rather than a code-specialised one. There is no
# qwen3.5-coder, and the older qwen2.5-coder cannot do tool calling: it
# advertises the capability, then emits a bare JSON object instead of the
# tagged call its template parses, so ollama returns no tool_calls and anything
# offering it tools prints the JSON into the chat. qwen3.5 returns parsed
# tool_calls for the same request.
#
# Context is per-tier because it is what the VRAM left over from the weights
# buys.
#
# The 9b row wants a 12GB card even though it runs on 8GB. Measured on the 2070
# Super: 9b sits at 7072MiB of 8192 and gets 60 tok/s, against 4b at 92 tok/s
# with roughly 4GB spare. Both are honest GPU speeds -- a model actually
# spilling to host runs an order of magnitude slower -- so the 8GB tier takes
# the faster one and the headroom rather than the larger weights.
#
# Note that ollama reports "100% GPU" for both while llama.cpp keeps a ~500MiB
# CPU model buffer either way. That buffer is the token embedding matrix and is
# structural, not VRAM pressure: it is the same size on 4b, which has GBs to
# spare. It is not a signal to size tiers by.
#
# qwen3.8:27b is dense, so every weight is read for every token and any of it
# left in system RAM runs at RAM bandwidth, roughly a tenth of VRAM's. Its
# threshold is therefore VRAM only, even though ollama would load it into less
# by spilling to host memory.
MODEL_TIERS=(
  "22000 qwen3.8:27b 65536"
  "12000 qwen3.5:9b  32768"
  "5000  qwen3.5:4b  32768"
  "3000  qwen3.5:2b  8192"
)

# The tier table is the only thing that knows which model this install chose,
# and two consumers need the answer: open-webui's installer for DEFAULT_MODELS,
# and Doom's gptel config. Written once here rather than each of them guessing.
ROLES="$HOME/.local/share/ollama/roles.env"

# Traces of ollama.com/install.sh, whose system unit would bind 11434 ahead of
# the --user unit here.
VENDOR_UNIT=/etc/systemd/system/ollama.service
VENDOR_PATHS=(/usr/local/bin/ollama /usr/local/lib/ollama /usr/bin/ollama)
VENDOR_DATA=/usr/share/ollama/.ollama/models

# The system user outlives an `rm` of the unit file, so each trace is checked
# separately rather than treating the unit as a proxy for the whole install.
vendor_installed() {
  [[ -f "$VENDOR_UNIT" ]] && return 0
  local path
  for path in "${VENDOR_PATHS[@]}"; do
    [[ -e "$path" ]] && return 0
  done
  id ollama >/dev/null 2>&1
}

# Runs before the tarball install so nothing on PATH still resolves to the
# vendor binary. Models it pulled are left in place rather than deleted --
# that is several GB, easy to move by hand, and not this script's call.
cleanup_vendor_install() {
  vendor_installed || return 0
  say "removing the vendor install script's system-wide install"

  if [[ -f "$VENDOR_UNIT" ]]; then
    if systemctl is-enabled --quiet ollama 2>/dev/null || systemctl is-active --quiet ollama 2>/dev/null; then
      run sudo systemctl disable --now ollama
    fi
    run sudo rm -f "$VENDOR_UNIT"
    run sudo systemctl daemon-reload
  fi

  local path
  for path in "${VENDOR_PATHS[@]}"; do
    [[ -e "$path" ]] && run sudo rm -rf "$path"
  done

  id ollama >/dev/null 2>&1 && run sudo userdel ollama

  if [[ -d "$VENDOR_DATA" ]]; then
    warn "models the vendor install pulled are still at $VENDOR_DATA"
    warn "move what you want under ~/.ollama/models, then: sudo rm -rf /usr/share/ollama"
  fi
}

# One "uuid vram display" line per card, preferred first. A card with no
# display attached sorts ahead: inference on the card driving GNOME competes
# with the compositor for VRAM and stutters the desktop. Within each group,
# larger first.
gpu_cards() {
  have nvidia-smi || return 1
  nvidia-smi --query-gpu=uuid,memory.total,display_active \
             --format=csv,noheader,nounits 2>/dev/null \
    | awk -F', *' 'NF >= 3 { print ($3 == "Disabled" ? 0 : 1), $2, $1 }' \
    | sort -k1,1n -k2,2nr \
    | awk '{ print $3, $2, $1 }'
}

# How llama.cpp places layers, written into the unit as LLAMA_ARG_* variables,
# which ollama passes through to the llama-server it spawns.
#
# One card: --fit, with the margin it leaves free. ollama otherwise passes
# ~1.9GB for every card, and a card driving a display keeps a full GB because
# GNOME and every GPU-accelerated app allocate from it after the model loads.
FIT_MARGIN_DISPLAY=1024
FIT_MARGIN_HEADLESS=256
fit_margin() { (( $1 )) && echo "$FIT_MARGIN_DISPLAY" || echo "$FIT_MARGIN_HEADLESS"; }

# Several cards: a fixed --tensor-split instead. --fit's estimate is too
# conservative to pool with: on a 4080 + 2070 at 64K context it leaves ~2.6GB
# and ~1.1GB unused and pushes 4 of qwen3.8:27b's 66 layers to the CPU, at 37
# tok/s against 57 with all of them on the cards. Setting the split makes --fit
# stand down entirely, so this is also what decides the layer count.
#
# The split is each card's total VRAM less a reserve, as raw MiB, which
# llama.cpp takes as proportions. The display card's reserve covers what GNOME
# and the desktop's apps already hold (~2GB measured) plus a GB of headroom.
# Unlike --fit this cannot back off at load time: if something has taken more
# of the display card than that, the load fails rather than spilling to RAM.
SPLIT_RESERVE_DISPLAY=3072
SPLIT_RESERVE_HEADLESS=256
split_reserve() { (( $1 )) && echo "$SPLIT_RESERVE_DISPLAY" || echo "$SPLIT_RESERVE_HEADLESS"; }

# Emits "model context uuids vram placement" for the largest tier that either
# the preferred card holds alone or all cards hold together, preferring the
# single card when both can. placement is fit:<margin> or split:<mib,...>.
#
# ollama splits a model that outgrows one card by layer, and the cards take
# turns per token, so pooling adds capacity and not speed: it is worth it only
# for a model that would otherwise not fit, and then it beats spilling to
# system RAM by the ratio of VRAM to RAM bandwidth.
select_target() {
  local cards="$1" tier min model context
  local one_uuid one_vram one_display all_uuids all_vram all_split
  read -r one_uuid one_vram one_display <<<"$cards"
  all_uuids="$(awk '{ print $1 }' <<<"$cards" | paste -sd,)"
  all_vram="$(awk '{ s += $2 } END { print s + 0 }' <<<"$cards")"
  all_split="$(while read -r _ vram display; do
                 echo $(( vram - $(split_reserve "$display") ))
               done <<<"$cards" | paste -sd,)"

  for tier in "${MODEL_TIERS[@]}"; do
    read -r min model context <<<"$tier"
    if (( one_vram >= min )); then
      printf '%s %s %s %s fit:%s\n' "$model" "$context" "$one_uuid" "$one_vram" "$(fit_margin "$one_display")"
      return 0
    elif (( all_vram >= min )); then
      printf '%s %s %s %s split:%s\n' "$model" "$context" "$all_uuids" "$all_vram" "$all_split"
      return 0
    fi
  done
  return 1
}

# The unit's LLAMA_ARG_* lines for a placement.
#
# A split is only chosen when the model needs every card, so the vision
# projector stays on the CPU rather than taking ~1.1GB of VRAM the layers
# need; it only costs time when an image is attached. Left to ollama, the first
# load fails with the projector on the GPU and is retried without it.
placement_env() {
  case "$1" in
    fit:*)   printf 'Environment=LLAMA_ARG_FIT_TARGET=%s\n' "${1#fit:}" ;;
    split:*) printf 'Environment=LLAMA_ARG_TENSOR_SPLIT=%s\n' "${1#split:}"
             printf 'Environment=LLAMA_ARG_MMPROJ_OFFLOAD=0\n' ;;
  esac
}

placement_current() {
  [[ "$(grep '^Environment=LLAMA_ARG_' "$UNIT" 2>/dev/null)" == "$(placement_env "$PLACEMENT")" ]]
}

# app_check, app_install and app_checks all need the same answers, and each
# nvidia-smi call costs about a tenth of a second. Resolved once per run.
GPU_UUID=""
GPU_VRAM=""
PLACEMENT=""
MODEL=""
CONTEXT=""
resolve_target() {
  [[ -n "$MODEL" ]] && return 0

  local cards target
  cards="$(gpu_cards)" || return 1
  [[ -n "$cards" ]] || return 1
  target="$(select_target "$cards")" || return 1
  read -r MODEL CONTEXT GPU_UUID GPU_VRAM PLACEMENT <<<"$target"

  # Pinning by UUID rather than by index: PCI re-enumeration across reboots
  # reorders indices, and CUDA_VISIBLE_DEVICES accepts either, comma-separated
  # when the tier needs more than one card.
  GPU_UUID="${OLLAMA_GPU_UUID:-$GPU_UUID}"
  MODEL="${OLLAMA_MODEL:-$MODEL}"
  CONTEXT="${OLLAMA_CONTEXT_LENGTH:-$CONTEXT}"
  [[ -n "$MODEL" && -n "$CONTEXT" ]]
}

# Prints the reason and succeeds when ollama cannot be installed here, fails
# when it can -- the convention app_blocked_reason expects.
app_blocked() {
  if ! have nvidia-smi; then
    echo "no nvidia-smi, so no CUDA card to run on -- ollama on the CPU is"
    echo "too slow to be worth installing here"
    return 0
  fi

  local cards
  cards="$(gpu_cards)"
  if [[ -z "$cards" ]]; then
    echo "nvidia-smi reports no GPU"
    return 0
  fi

  if ! select_target "$cards" >/dev/null; then
    local vram
    vram="$(awk '{ s += $2 } END { print s + 0 }' <<<"$cards")"
    echo "no model tier fits ${vram}MiB of VRAM;"
    echo "the smallest needs ${MODEL_TIERS[-1]%% *}MiB"
    return 0
  fi

  return 1
}

# "ollama version is X" against a running server, "client version is X" when it
# cannot reach one, so match the phrase both spellings share.
installed_version() {
  [[ -x "$PREFIX/bin/ollama" ]] || return 1
  "$PREFIX/bin/ollama" --version 2>/dev/null \
    | awk '/version is/ { print $NF; exit }'
}

app_check() {
  ! vendor_installed \
    && resolve_target \
    && [[ "$(installed_version)" == "$VERSION" ]] \
    && [[ "$(readlink -f "$BIN")" == "$(readlink -f "$PREFIX/bin/ollama")" ]] \
    && [[ "$(systemctl --user is-active ollama.service 2>/dev/null)" == active ]] \
    && grep -qx "Environment=CUDA_VISIBLE_DEVICES=$GPU_UUID" "$UNIT" 2>/dev/null \
    && grep -q "OLLAMA_VULKAN=0" "$UNIT" 2>/dev/null \
    && placement_current \
    && grep -q "OLLAMA_CONTEXT_LENGTH=$CONTEXT" "$UNIT" 2>/dev/null \
    && grep -q "OLLAMA_MODEL=$MODEL" "$ROLES" 2>/dev/null \
    && model_pulled
}

# `ollama pull qwen3.5` lands as qwen3.5:latest, so compare against the tag
# ollama reports rather than the string the tier table used.
model_pulled() {
  local want="$MODEL"
  [[ "$want" == *:* ]] || want="$want:latest"
  ollama list 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -qx "$want"
}

install_tarball() {
  if dry; then
    printf '    [dry-run] curl -fsSL %s\n' "$URL"
    printf '    [dry-run]   | tar -x --zstd -C %s   (bin/, lib/; ~1.4GB)\n' "$PREFIX"
    printf '    [dry-run] ln -sfn %s %s\n' "$PREFIX/bin/ollama" "$BIN"
    return 0
  fi

  # Extracted into a fresh directory and swapped in, so an interrupted download
  # cannot leave a half-replaced tree that still looks like the right version.
  local staging="$PREFIX.new"
  rm -rf "$staging"
  mkdir -p "$staging"

  say "downloading ollama $VERSION (~1.4GB)"
  # No --strip-components: the archive's own top level is bin/ and lib/.
  if ! curl -fsSL "$URL" | tar -x --zstd -C "$staging"; then
    rm -rf "$staging"
    warn "download or extract failed"
    return 1
  fi

  rm -rf "$PREFIX"
  mv "$staging" "$PREFIX"

  # ollama resolves its runners via /proc/self/exe, which follows the symlink,
  # so lib/ollama is found relative to $PREFIX and not to ~/.local/bin.
  mkdir -p "$(dirname "$BIN")"
  ln -sfn "$PREFIX/bin/ollama" "$BIN"
}

# Our own unit rather than `brew services`: the GPU pin has to be an
# Environment= line on the exact process running `ollama serve`, and brew
# services' systemd integration on Linux gives no way to set one.
#
# CUDA_VISIBLE_DEVICES only constrains the CUDA backend. Ollama also enumerates
# GPUs over Vulkan, which ignores it, and then picks whichever card has the most
# free VRAM -- the display one. OLLAMA_VULKAN=0 leaves CUDA as the only backend,
# which is both correctly pinned and the faster of the two on NVIDIA.
write_unit() {
  run mkdir -p "$(dirname "$UNIT")"
  if dry; then
    printf '    [dry-run] write %s (CUDA_VISIBLE_DEVICES=%s, %s)\n' "$UNIT" "$GPU_UUID" "$PLACEMENT"
    return 0
  fi
  printf '%s\n' \
    '[Unit]' \
    'Description=Ollama' \
    'After=network-online.target' \
    '' \
    '[Service]' \
    "Environment=CUDA_VISIBLE_DEVICES=$GPU_UUID" \
    'Environment=OLLAMA_VULKAN=0' \
    'Environment=OLLAMA_FLASH_ATTENTION=1' \
    'Environment=OLLAMA_KV_CACHE_TYPE=q8_0' \
    "Environment=OLLAMA_CONTEXT_LENGTH=$CONTEXT" \
    "$(placement_env "$PLACEMENT")" \
    "ExecStart=$PREFIX/bin/ollama serve" \
    'Restart=on-failure' \
    '' \
    '[Install]' \
    'WantedBy=default.target' \
    >"$UNIT"
}

# systemctl returns once the process is spawned, which is before it is
# listening; `ollama pull` talks to the API and would race it.
wait_for_api() {
  for _ in $(seq 1 30); do
    curl -fsS "$API/api/version" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

app_install() {
  cleanup_vendor_install

  resolve_target || blocked "$(app_blocked)"
  say "GPU $GPU_UUID (${GPU_VRAM}MiB) -> $MODEL, ${CONTEXT} ctx"

  install_tarball || return 1
  write_unit
  run systemctl --user daemon-reload
  run systemctl --user enable ollama.service
  # restart rather than `enable --now`, which does nothing to a unit that is
  # already running -- a changed pin or context would never reach the process.
  run systemctl --user restart ollama.service

  if dry; then
    printf '    [dry-run] ollama pull %s\n' "$MODEL"
    write_roles
    return 0
  fi

  wait_for_api || { warn "ollama did not start listening on $API"; return 1; }

  say "pulling $MODEL"
  "$PREFIX/bin/ollama" pull "$MODEL" || return 1

  write_roles
}

write_roles() {
  if dry; then
    printf '    [dry-run] write %s (model=%s)\n' "$ROLES" "$MODEL"
    return 0
  fi
  mkdir -p "$(dirname "$ROLES")"
  printf '%s\n' \
    "OLLAMA_MODEL=$MODEL" \
    "OLLAMA_CONTEXT_LENGTH=$CONTEXT" \
    >"$ROLES"
}

app_checks() {
  if vendor_installed; then
    check_fail "ollama" "the vendor install script's system-wide install is still present" \
      "./modules/packages/install.sh ollama"
  fi

  if ! resolve_target; then
    check_warn "ollama" "no usable GPU: $(app_blocked | head -1)"
    return 0
  fi

  # module_checks already reports a missing app; only the details it cannot
  # know belong here.
  local version
  if ! version="$(installed_version)"; then
    return 0
  elif [[ "$version" == "$VERSION" ]]; then
    check_ok "ollama" "$version at $PREFIX"
  else
    check_warn "ollama" "$version installed, $VERSION expected" \
      "./modules/packages/install.sh ollama"
  fi

  if [[ "$(systemctl --user is-active ollama.service 2>/dev/null)" == active ]]; then
    check_ok "ollama.service" "active"
  else
    check_fail "ollama.service" "not active" "systemctl --user enable --now ollama.service"
  fi

  if grep -qx "Environment=CUDA_VISIBLE_DEVICES=$GPU_UUID" "$UNIT" 2>/dev/null; then
    check_ok "gpu pin" "${GPU_VRAM}MiB on $GPU_UUID"
  else
    check_fail "gpu pin" "$UNIT does not pin $GPU_UUID" \
      "./modules/packages/install.sh ollama"
  fi

  # Without this the pin still reads as correct while inference runs on the
  # other card, because the Vulkan backend enumerates GPUs of its own.
  if grep -q "OLLAMA_VULKAN=0" "$UNIT" 2>/dev/null; then
    check_ok "vulkan backend" "disabled, so the pin is the only device source"
  else
    check_fail "vulkan backend" "$UNIT does not set OLLAMA_VULKAN=0" \
      "./modules/packages/install.sh ollama"
  fi

  # Without this the model still loads, but with layers on the CPU at half the
  # speed, and nothing but `ollama ps` says so.
  if placement_current; then
    case "$PLACEMENT" in
      fit:*)   check_ok "placement" "--fit, ${PLACEMENT#fit:}MiB left free" ;;
      split:*) check_ok "placement" "tensor split ${PLACEMENT#split:} MiB" ;;
    esac
  else
    check_fail "placement" "$UNIT does not place layers as $PLACEMENT" \
      "./modules/packages/install.sh ollama"
  fi

  if grep -q "OLLAMA_CONTEXT_LENGTH=$CONTEXT" "$UNIT" 2>/dev/null; then
    check_ok "context" "$CONTEXT tokens, q8_0 KV cache"
  else
    check_fail "context" "$UNIT does not set OLLAMA_CONTEXT_LENGTH=$CONTEXT" \
      "./modules/packages/install.sh ollama"
  fi

  if model_pulled; then
    check_ok "$MODEL" "pulled"
  else
    check_warn "$MODEL" "not pulled" "ollama pull $MODEL"
  fi

  # open-webui and gptel both read this rather than each rediscovering the
  # choice, so a stale one points them at the wrong model silently.
  if grep -q "OLLAMA_MODEL=$MODEL" "$ROLES" 2>/dev/null; then
    check_ok "model roles" "$ROLES"
  else
    check_fail "model roles" "$ROLES missing or stale" \
      "./modules/packages/install.sh ollama"
  fi
}