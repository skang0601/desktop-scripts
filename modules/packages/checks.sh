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
  local name
  while read -r name; do
    if with_app "$name" app_check >/dev/null 2>&1; then
      check_ok "$name" "installed"
    else
      check_warn "$name" "not installed" "./modules/packages/install.sh $name"
    fi
    run_app_checks "$name" \
      || check_warn "$name checks" "app_checks in $name exited early"
  done < <(app_names)
}
