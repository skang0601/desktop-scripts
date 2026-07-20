# State checks for the packages module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

# app_path/app_names/with_app resolve the two apps.d layouts and belong with the
# module's install strategies, not with doctor.sh's generic check helpers.
# shellcheck source=lib.sh
source "$MODULE/lib.sh"

module_checks() {
  # app_check is the module's existing contract for "is this already here", so
  # reuse it rather than inventing a second, divergent notion of installed.
  # Anything finer-grained belongs to the app, which owns the paths involved.
  # Every app runs with stdin closed: an app's checks may shell out to podman
  # or distrobox, which read stdin and would otherwise swallow the rest of
  # app_names, silently ending the loop partway down the list.
  local name reason
  while read -r name; do
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
  done < <(app_names)
}
