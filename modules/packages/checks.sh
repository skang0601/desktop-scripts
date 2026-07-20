# State checks for the packages module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

# app_path/app_names/with_app resolve the two apps.d layouts and belong with the
# module's install strategies, not with doctor.sh's generic check helpers.
# shellcheck source=lib.sh
source "$MODULE/lib.sh"

module_checks() {
  # app_check is the module's existing contract for "is this already here", so
  # reuse it rather than inventing a second, divergent notion of installed.
  local name
  while read -r name; do
    if with_app "$name" app_check >/dev/null 2>&1; then
      check_ok "$name" "installed"
    else
      check_warn "$name" "not installed" "./modules/packages/install.sh $name"
    fi
  done < <(app_names)

  # Doom is detected rather than forced, so the pair that is actually live
  # matters more than whether any single path exists.
  local doom config
  for doom in "$HOME/.emacs.d" "$HOME/.config/emacs"; do
    [[ -d "$doom" ]] && break
  done
  for config in "$HOME/.doom.d" "$HOME/.config/doom"; do
    [[ -d "$config" || -L "$config" ]] && break
  done

  if [[ -d "$doom" ]]; then
    check_ok "doom" "$doom"
    check_symlink "doom config" "$config" "$MODULE/apps.d/emacs/doom" "./modules/packages/install.sh emacs"
  else
    check_warn "doom" "not installed" "./modules/packages/install.sh emacs"
  fi
}
