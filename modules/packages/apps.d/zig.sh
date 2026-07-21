# shellcheck shell=bash
APP_NAME=zig

app_check() { have zig && have zls; }

app_install() {
  # Zig's release cadence is fast and breaking; if a project needs a version
  # other than the packaged one, install that one to ~/.local and let it shadow.
  install_cli zig

  # zls is built against one zig release and rejects any other with a version
  # mismatch, so it is not a separate app: installing it apart from zig is how
  # the two drift into a pair that refuses to work together.
  install_cli zls
}

app_checks() {
  have zls || return 0

  # zls versions itself with the zig release it targets, so equality is the
  # whole test -- and it catches the drift the ~/.local escape hatch invites.
  local zig_ver zls_ver
  zig_ver="$(zig version 2>/dev/null)"
  zls_ver="$(zls --version 2>/dev/null)"
  if [[ -z "$zig_ver" || -z "$zls_ver" ]]; then
    check_warn "zls" "cannot read a version from zig or zls"
  elif [[ "$zls_ver" == "$zig_ver" ]]; then
    check_ok "zls" "$zls_ver"
  else
    check_warn "zls" "targets zig $zls_ver, but zig is $zig_ver" \
      "brew upgrade zig zls"
  fi
}
