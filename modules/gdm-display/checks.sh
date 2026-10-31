# State checks for the gdm-display module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

module_checks() {
  # shellcheck source=./common.sh
  source "$MODULE/common.sh"
  local fix="./modules/gdm-display/install.sh"

  if [[ ! -f "$GDM_SRC" ]]; then
    check_warn "session layout" "$GDM_SRC missing; no saved display layout to copy"
    return 0
  fi

  if [[ ! -e "$GDM_DEST" ]]; then
    check_fail "login screen layout" "$GDM_DEST missing; login screen guesses its own scale" "$fix"
    return 0
  elif [[ ! -r "$GDM_DEST" ]]; then
    check_warn "login screen layout" "cannot read $GDM_DEST to compare"
    return 0
  elif cmp -s "$GDM_SRC" "$GDM_DEST"; then
    check_ok "login screen layout" "matches $GDM_SRC"
  else
    # Settings > Displays rewrites the user's copy on every change.
    check_warn "login screen layout" "differs from $GDM_SRC; display settings changed since the last copy" "$fix"
  fi

  local owner
  owner="$(stat -c %U "$GDM_DEST")"
  if [[ "$owner" == gdm ]]; then
    check_ok "owner" "gdm"
  else
    check_fail "owner" "$GDM_DEST is owned by $owner, not gdm" "$fix"
  fi

  if have selinuxenabled && selinuxenabled; then
    local ctx
    ctx="$(stat -c %C "$GDM_DEST")"
    if [[ "$ctx" == *:xdm_var_lib_t:* ]]; then
      check_ok "SELinux label" "xdm_var_lib_t"
    else
      check_fail "SELinux label" "$ctx; GDM ignores the file" "sudo restorecon -R $(dirname "$GDM_DEST")"
    fi
  fi
}
