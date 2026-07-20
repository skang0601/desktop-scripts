# State checks for the packages module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

module_checks() {
  # app_check is the module's existing contract for "is this already here", so
  # reuse it rather than inventing a second, divergent notion of installed.
  local f name
  for f in "$MODULE"/apps.d/*.sh; do
    name="$(basename "$f" .sh)"
    if ( set +e; source "$f"; app_check ) >/dev/null 2>&1; then
      check_ok "$name" "installed"
    else
      check_warn "$name" "not installed" "./modules/packages/install.sh $name"
    fi
  done

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
    check_symlink "doom config" "$config" "$MODULE/doom" "./modules/packages/install.sh emacs"
  else
    check_warn "doom" "not installed" "./modules/packages/install.sh emacs"
  fi
}
