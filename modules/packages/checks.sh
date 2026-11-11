# State checks for the packages module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

# app_path/app_names/with_app resolve the two apps.d layouts and belong with the
# module's install strategies, not with doctor.sh's generic check helpers.
# shellcheck source=lib.sh
source "$MODULE/lib.sh"

module_checks() {
  brewfile_checks

  # app_check is the module's existing contract for "is this already here", so
  # reuse it rather than inventing a second, divergent notion of installed.
  # Anything finer-grained belongs to the app, which owns the paths involved.
  # Every app runs with stdin closed: an app's checks may shell out to podman
  # or distrobox, which read stdin and would otherwise swallow the rest of
  # app_names, silently ending the loop partway down the list.
  local name reason
  while read -r name; do
    # The app's own summary row belongs to the app, so it heads the app's block
    # rather than floating above it.
    CHECK_GROUP="$(app_group_path "$name")"
    if with_app "$name" app_check </dev/null >/dev/null 2>&1; then
      check_ok "$name" "installed"
    elif reason="$(app_blocked_reason "$name")"; then
      # Second line, when there is one, is where to watch for the block lifting.
      check_blocked "$name" "${reason%%$'\n'*}" \
        "$([[ "$reason" == *$'\n'* ]] && printf '%s' "${reason#*$'\n'}")"
    else
      check_warn "$name" "not installed" "./modules/packages/install.sh $name"
    fi
    run_app_checks "$name" </dev/null \
      || check_warn "$name checks" "app_checks in $name exited early"
  done < <(app_names_grouped)
}

brewfile_checks() {
  if ! have brew; then
    check_fail "Homebrew" "not installed; the Brewfile cannot be applied" "https://brew.sh"
    return 0
  fi

  local missing
  if brew_bundle check --no-upgrade >/dev/null 2>&1; then
    check_ok "Brewfile" "every entry installed"
  else
    # "→ Formula hello needs to be installed." per missing entry.
    missing="$(brew_bundle check --no-upgrade --verbose 2>&1 \
      | sed -n 's/^→ [A-Za-z]* \(.*\) needs to be installed.*/\1/p' | paste -sd' ')"
    check_warn "Brewfile" "missing: ${missing:-see brew bundle check --verbose}" \
      "./modules/packages/install.sh"
  fi

  # zls versions itself with the zig release it targets, so equality is the
  # whole test.
  if have zig && have zls; then
    local zig_ver zls_ver
    zig_ver="$(zig version 2>/dev/null)"
    zls_ver="$(zls --version 2>/dev/null)"
    if [[ "$zls_ver" == "$zig_ver" ]]; then
      check_ok "zls" "$zls_ver"
    else
      check_warn "zls" "targets zig $zls_ver, but zig is $zig_ver" "brew upgrade zig zls"
    fi
  fi
}
