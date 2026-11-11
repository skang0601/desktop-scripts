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

# A part is one file setting up one thing, for a module with several: it defines
# APP_NAME, app_check and app_install, and optionally app_checks (doctor rows)
# and app_blocked (prints why it cannot be set up here, and succeeds if so).
# Each is sourced in its own subshell with APP_DIR set to its directory, so
# parts cannot see each other's definitions.
#
# A failing part is recorded in PARTS_FAILED and the next one still runs; the
# module ends with `parts_ok`. errexit is turned back on inside the subshell
# rather than tested with `||`, which would disable it for the whole part.
PARTS_FAILED=()
install_part() {
  local f="$1" rc
  set +e
  (
    set -e
    APP_DIR="$(dirname "$f")"
    # shellcheck source=/dev/null
    source "$f"
    if app_check; then
      skip "$APP_NAME"
      exit 0
    fi
    say "setting up $APP_NAME"
    app_install
  )
  rc=$?
  set -e
  if (( rc != 0 )); then
    warn "$(basename "$f" .sh) failed (exit $rc)"
    PARTS_FAILED+=("$(basename "$f" .sh)")
  fi
  return 0
}

parts_ok() {
  (( ${#PARTS_FAILED[@]} == 0 )) && return 0
  warn "failed: ${PARTS_FAILED[*]}; re-run this module's install.sh to retry"
  return 1
}

# Called by a part that cannot be set up on this machine for a known reason
# re-running will not change. Not a failure: doctor.sh reports it as blocked.
blocked() { warn "${*//$'\n'/$'\n'    }"; exit 0; }

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
