# State checks for the shell module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

module_checks() {
  if [[ -f "$HOME/.bashrc" ]] && grep -q 'bashrc\.d' "$HOME/.bashrc"; then
    check_ok "~/.bashrc" "sources ~/.bashrc.d"
  else
    check_fail "~/.bashrc" "does not source ~/.bashrc.d" "./modules/shell/install.sh"
  fi

  local f
  for f in "$MODULE"/bashrc.d/*.sh; do
    [[ -e "$f" ]] || continue
    check_symlink "$(basename "$f")" "$HOME/.bashrc.d/$(basename "$f")" "$f" \
      "./modules/shell/install.sh"
  done
}
