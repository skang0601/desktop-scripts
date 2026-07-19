# Shared helpers. Sourced by module installers and bootstrap.sh.
# shellcheck shell=bash

DRY_RUN="${DRY_RUN:-0}"

is_atomic() { [[ -f /run/ostree-booted ]]; }
have()      { command -v "$1" >/dev/null 2>&1; }
dry()       { [[ "$DRY_RUN" == 1 ]]; }

say()  { printf '==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }
skip() { printf '    %-14s %s\n' "$1" "${2:-already present}"; }

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

# Write to a root-owned path via a heredoc/stdin, dry-run aware.
run_write_root() {
  local dest="$1" mode="${2:-644}"
  if dry; then
    printf '    [dry-run] install -Dm%s /dev/stdin %s\n' "$mode" "$dest"
    cat >/dev/null
  else
    sudo install -Dm"$mode" /dev/stdin "$dest"
  fi
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
