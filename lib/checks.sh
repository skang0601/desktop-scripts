# Check primitives for doctor.sh and the modules' checks.sh files.
# shellcheck shell=bash

# Nothing here changes anything, so no helper goes through `run` and there is no
# --dry-run to honour: reporting is the whole job.

# Each module's checks run in their own subshell, so a variable cannot carry
# results back. Rows accumulate in $CHECK_RESULTS as TSV instead, the same way
# the packages module collects per-app outcomes.
# Unit Separator, not tab. Tab is IFS whitespace, so `read` collapses a run of
# them into one delimiter and every field after an empty one shifts left --
# which silently corrupts every row whose group is empty. US is not whitespace,
# so empty fields survive the round trip.
FS=$'\x1f'
# \037 is octal: tr has no \x escape, so '\x1f' there is the literal set
# {\, x, 1, f}, and every backslash, x, 1 and f in a field becomes a space.
_clean() { printf '%s' "$1" | tr '\t\n\037' '   '; }

# $CHECK_GROUP is a "/"-separated path naming what a row belongs to, so a
# module can nest its rows without every renderer growing a column per level:
# "local llm/ollama" puts the row under ollama, under local llm, under the
# module. Empty means the row belongs to the module itself.
_record() {
  printf '%s%s%s%s%s%s%s%s%s%s%s\n' \
    "$1" "$FS" "$CHECK_MODULE" "$FS" "$(_clean "${CHECK_GROUP:-}")" "$FS" \
    "$(_clean "$2")" "$FS" "$(_clean "${3:-}")" "$FS" "$(_clean "${4:-}")" \
    >>"$CHECK_RESULTS"
}

# fail is "this is broken now"; warn is "this works but will surprise you";
# blocked is "cannot be in the wanted state here, the reason is known, and
# re-running changes nothing" -- the same distinction the packages module draws,
# and the reason blocked does not count towards the exit status. A warning
# nobody can action is noise, and noise is what makes a real one get ignored.
check_ok()      { _record ok      "$@"; }
check_warn()    { _record warn    "$@"; }
check_fail()    { _record fail    "$@"; }
check_blocked() { _record blocked "$@"; }

# The repo is the source of truth for anything installed to a system path, so a
# difference means the installed copy was edited in place -- which the module
# convention forbids precisely because the next install.sh run silently reverts
# it.
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

# A service that crashes and gets restarted reports "active" afterwards, so
# liveness alone says nothing about whether it has been healthy.
check_no_recent_crash() {
  local label="$1" comm="$2" since="${3:--24h}" n
  n="$(coredumpctl list --no-pager --no-legend --since="$since" "$comm" 2>/dev/null | wc -l)"

  if (( n == 0 )); then
    check_ok "$label" "no core dumps since $since"
  else
    check_warn "$label" "$n core dump(s) since $since" "coredumpctl info $comm"
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
  local label="$1" schema="$2" key="$3" want="$4" got
  got="$(gsettings get "$schema" "$key" 2>/dev/null || true)"

  if [[ -z "$got" ]]; then
    check_warn "$label" "$schema $key is unreadable (schema not installed?)"
  elif [[ "$got" == "$want" ]]; then
    check_ok "$label" "$got"
  else
    check_fail "$label" "is $got, expected $want" "./modules/keybindings/gsettings.sh"
  fi
}
