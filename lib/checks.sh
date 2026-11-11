# Check primitives for doctor.sh and the modules' checks.sh files.
# shellcheck shell=bash

# Read-only: nothing here goes through `run`.

# Each module's checks run in a subshell, so rows accumulate in $CHECK_RESULTS
# rather than a variable. Fields are split on Unit Separator, not tab: `read`
# collapses a run of tabs, which shifts every field after an empty one.
FS=$'\x1f'
# tr has no \x escape; \037 is the same byte in octal.
_clean() { printf '%s' "$1" | tr '\t\n\037' '   '; }

# $CHECK_GROUP nests a row: "local llm/ollama" puts it under ollama, under
# local llm, under the module. Empty means the module itself.
_record() {
  printf '%s%s%s%s%s%s%s%s%s%s%s\n' \
    "$1" "$FS" "$CHECK_MODULE" "$FS" "$(_clean "${CHECK_GROUP:-}")" "$FS" \
    "$(_clean "$2")" "$FS" "$(_clean "${3:-}")" "$FS" "$(_clean "${4:-}")" \
    >>"$CHECK_RESULTS"
}

# fail: broken now. warn: works, but will surprise you. blocked: cannot be in
# the wanted state here for a known reason that re-running will not change, so
# it does not count towards the exit status.
check_ok()      { _record ok      "$@"; }
check_warn()    { _record warn    "$@"; }
check_fail()    { _record fail    "$@"; }
check_blocked() { _record blocked "$@"; }

# A difference means the installed copy was edited in place, which the next
# install.sh run would silently revert.
check_installed_matches() {
  local label="$1" repo="$2" installed="$3" fix="${4:-}"

  if [[ ! -e "$installed" ]]; then
    check_fail "$label" "not installed at $installed" "$fix"
  elif cmp -s "$repo" "$installed"; then
    check_ok "$label" "matches the repo copy"
  else
    check_fail "$label" "$installed has drifted from the repo copy" "$fix"
  fi
}

check_symlink() {
  local label="$1" dest="$2" src="$3" fix="${4:-}"

  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    check_fail "$label" "$dest is missing" "$fix"
  elif [[ ! -L "$dest" ]]; then
    check_warn "$label" "$dest is a real file; repo edits will not reach it" "$fix"
  elif [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    check_ok "$label" "linked to the repo"
  else
    check_warn "$label" "$dest points at $(readlink -f "$dest")" "$fix"
  fi
}

check_service_active() {
  local label="$1" unit="$2" fix="${3:-}" state
  state="$(systemctl is-active "$unit" 2>/dev/null || true)"

  if [[ "$state" == active ]]; then
    check_ok "$label" "active"
  else
    check_fail "$label" "$unit is ${state:-unknown}" "$fix"
  fi
}

check_in_group() {
  local label="$1" group="$2" fix="${3:-}"

  if ! getent group "$group" >/dev/null 2>&1; then
    check_fail "$label" "no $group group on this system" "$fix"
  elif id -nG | grep -qw "$group"; then
    # No username argument: that reports this process's actual credentials,
    # where `id -nG "$USER"` would re-read NSS and claim a membership the
    # running session has not picked up yet.
    check_ok "$label" "$USER is in $group"
  elif getent group "$group" | grep -qw "$USER"; then
    # The membership is recorded but this login predates it, so every process in
    # the session still runs without the group.
    check_warn "$label" "$USER was added to $group but this session predates it" \
      "log out and back in"
  else
    check_fail "$label" "$USER is not in $group" "$fix"
  fi
}

# `gsettings get` cannot tell a schema default from a local override, so a key
# that must carry no override has to be read through dconf, where an empty
# result means exactly that.
check_dconf_unset() {
  local label="$1" path="$2" got
  got="$(dconf read "$path" 2>/dev/null || true)"

  if [[ -z "$got" ]]; then
    check_ok "$label" "no local override"
  else
    check_fail "$label" "overridden to $got" "dconf reset $path"
  fi
}

check_dconf() {
  local label="$1" schema="$2" key="$3" want="$4" fix="${5:-}" got
  got="$(gsettings get "$schema" "$key" 2>/dev/null || true)"

  if [[ -z "$got" ]]; then
    check_warn "$label" "$schema $key is unreadable (schema not installed?)"
  elif [[ "$got" == "$want" ]]; then
    check_ok "$label" "$got"
  else
    check_fail "$label" "is $got, expected $want" "$fix"
  fi
}

# doctor rows for one part (see install_part in common.sh): installed or not,
# blocked when app_blocked says so, then the part's own app_checks, nested under
# its APP_NAME. stdin is closed because a check that shells out to podman or
# distrobox would otherwise read the caller's input.
check_part() {
  local f="$1" rc
  set +e
  (
    set -e
    APP_DIR="$(dirname "$f")"
    # shellcheck source=/dev/null
    source "$f"
    CHECK_GROUP="$APP_NAME"
    local reason
    if app_check >/dev/null 2>&1; then
      check_ok "$APP_NAME" "installed"
    elif declare -F app_blocked >/dev/null && reason="$(app_blocked)"; then
      # The second line, when there is one, is where to watch for the block lifting.
      check_blocked "$APP_NAME" "${reason%%$'\n'*}" \
        "$([[ "$reason" == *$'\n'* ]] && printf '%s' "${reason#*$'\n'}")"
      exit 0
    else
      check_warn "$APP_NAME" "not set up" "./modules/$CHECK_MODULE/install.sh"
    fi
    if declare -F app_checks >/dev/null; then app_checks; fi
  ) </dev/null
  rc=$?
  set -e
  (( rc == 0 )) || check_warn "$(basename "$f" .sh) checks" "exited early ($rc)"
  return 0
}
