# Shared helpers. Sourced by module installers and bootstrap.sh.
# shellcheck shell=bash

DRY_RUN="${DRY_RUN:-0}"

is_atomic() { [[ -f /run/ostree-booted ]]; }
have()      { command -v "$1" >/dev/null 2>&1; }
dry()       { [[ "$DRY_RUN" == 1 ]]; }

say()  { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }
skip() { printf '    %-14s %s\n' "$1" "${2:-already present}"; }

# The options every module installer takes. Positional arguments are an error
# unless the caller passes --with-args first, and are then left in ARGS.
parse_module_args() {
  local with_args=0 a
  if [[ "${1:-}" == --with-args ]]; then with_args=1; shift; fi
  ARGS=()
  for a in "$@"; do
    case "$a" in
      --dry-run) DRY_RUN=1 ;;
      -*) warn "unknown option: $a"; exit 2 ;;
      *)
        (( with_args )) || { warn "unexpected argument: $a"; exit 2; }
        ARGS+=("$a")
        ;;
    esac
  done
  dry && say "dry run -- nothing will be changed"
  return 0
}

# Run a command, or print it under --dry-run. Only handles simple commands:
# anything with a pipe, redirect or shell construct needs an explicit
# `if dry; then ... else ... fi` so the dry-run output stays honest.
run() {
  if dry; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Copy a repo file into place only when it differs, so a re-run is a no-op.
#   install_file [--root] <src> <dest> [mode]
# Sets FILE_CHANGED to 1 when it installed and 0 when dest already matched, for a
# caller that restarts something only on a change. Returns 0 either way, so a
# bare call is safe under errexit.
install_file() {
  local sudo=()
  if [[ "$1" == --root ]]; then sudo=(sudo); shift; fi
  local src="$1" dest="$2" mode="${3:-644}"

  FILE_CHANGED=0
  if cmp -s "$src" "$dest"; then
    skip "$(basename "$dest")" "$dest matches the repo"
    return 0
  fi
  say "installing $dest"
  run "${sudo[@]}" install -Dm"$mode" "$src" "$dest"
  FILE_CHANGED=1
}

# Symlink a repo file into place, preserving anything real already there.
link_config() {
  local src="$1" dest="$2"

  if [[ -L "$dest" ]]; then
    if [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
      skip "$(basename "$dest")" "already linked"
      return 0
    fi
    warn "$dest is a symlink elsewhere; replacing"
    run rm "$dest"
  elif [[ -e "$dest" ]]; then
    warn "$dest exists; backing it up to $dest.bak"
    run mv "$dest" "$dest.bak"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
}
