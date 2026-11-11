# State checks for the packages module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

# shellcheck source=lib.sh
source "$MODULE/lib.sh"

module_checks() {
  brewfile_checks
  check_part "$MODULE/rust.sh"
  check_part "$MODULE/claude-code.sh"
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
