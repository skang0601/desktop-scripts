# State checks for the git module. Sourced by ../../doctor.sh.
# shellcheck shell=bash
# shellcheck disable=SC2088  # tildes here are display labels and
# copy-pasteable hints, not paths this script resolves itself

module_checks() {
  check_symlink "~/.gitconfig" "$HOME/.gitconfig" "$MODULE/gitconfig" \
    "./modules/git/install.sh"

  # ~/.config/git/config wins over ~/.gitconfig, so one here silently overrides
  # the tracked file rather than merging with it.
  if [[ -e "$HOME/.config/git/config" ]]; then
    check_fail "config precedence" "~/.config/git/config overrides ~/.gitconfig" \
      "move or remove ~/.config/git/config"
  else
    check_ok "config precedence" "no ~/.config/git/config shadowing it"
  fi

  local name email
  name="$(git config --global user.name 2>/dev/null || true)"
  email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$name" ]];  then check_ok "user.name" "$name";   else check_warn "user.name" "unset";  fi
  if [[ -n "$email" ]]; then check_ok "user.email" "$email"; else check_warn "user.email" "unset"; fi
}
