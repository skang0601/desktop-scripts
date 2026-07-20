# shellcheck shell=bash
APP_NAME=rust

app_check() { have rustup; }

app_install() {
  # rustup rather than brew's rust formula: rust is one toolchain for the whole
  # machine, and a project pinned to another version has nowhere to go. They
  # provide the same binaries, so leaving both installed decides the toolchain
  # by PATH order.
  if have brew && brew list --formula rust >/dev/null 2>&1; then
    say "removing the rust formula, superseded by rustup"
    run brew uninstall --formula --ignore-dependencies rust
  fi

  # rustup's post_install adds a file to share/pwsh, which fd already owns.
  brew_split_shared_dir share/pwsh
  local pwsh_owner="$BREW_SPLIT_OWNER"

  install_cli rustup

  if [[ -n "$pwsh_owner" ]]; then
    brew_relink "$pwsh_owner"
  fi

  # brew ships the installer alone; the toolchain it manages is a second step.
  # By path because a keg-only formula reaches PATH through the entry in
  # modules/shell, which a new shell reads, not this one.
  local rustup=rustup
  have brew && rustup="$(brew --prefix rustup)/bin/rustup"
  run "$rustup" default stable
}

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