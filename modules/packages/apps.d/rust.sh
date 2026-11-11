# shellcheck shell=bash
APP_NAME=rust

# rustup is in the Brewfile; it ships the installer alone, and the toolchain it
# manages is a second step. rustup rather than brew's rust formula, so a project
# pinned to another toolchain has somewhere to go.
app_check() { have_rustup && [[ -n "$("$(rustup_bin)" show active-toolchain 2>/dev/null)" ]]; }

app_install() {
  have_rustup || { warn "no rustup; it comes from the Brewfile, which install.sh applies first"; return 1; }
  run "$(rustup_bin)" default stable
}

# By path because the keg-only formula reaches PATH through the entry in
# modules/shell, which a new shell reads, not this one.
rustup_bin() { printf '%s/bin/rustup\n' "$(brew --prefix rustup)"; }
have_rustup() { have brew && [[ -x "$(rustup_bin)" ]]; }

app_checks() {
  have rustup || return 0

  # rustup on PATH but no default toolchain is the state brew leaves behind, and
  # it fails every cargo invocation with a message about the toolchain, not the
  # missing default.
  local toolchain
  if toolchain="$(rustup show active-toolchain 2>/dev/null)" && [[ -n "$toolchain" ]]; then
    check_ok "rust toolchain" "${toolchain%% *}"
  else
    check_warn "rust toolchain" "rustup has no default toolchain" "rustup default stable"
  fi

  # A cargo resolving outside rustup means the PATH order is wrong and rustup's
  # shims are being shadowed, so the toolchain reported above is not the one
  # that builds anything.
  local cargo
  cargo="$(command -v cargo || true)"
  if [[ -z "$cargo" ]]; then
    check_warn "cargo" "not on PATH" "source ~/.bashrc"
  elif [[ "$cargo" == "$(dirname "$(command -v rustup)")"/* ]]; then
    check_ok "cargo" "rustup shim"
  else
    check_warn "cargo" "$cargo shadows rustup's shim" "open a new shell"
  fi
}