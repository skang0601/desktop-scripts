# State checks for the ssh module. Sourced by ../../doctor.sh.
# shellcheck shell=bash
# shellcheck disable=SC2088  # tildes here are display labels and
# copy-pasteable hints, not paths this script resolves itself

module_checks() {
  # ssh refuses a config directory or key that others can write to, and says so
  # only at connection time.
  local mode
  if [[ -d "$HOME/.ssh" ]]; then
    mode="$(stat -c %a "$HOME/.ssh")"
    if [[ "$mode" == 700 ]]; then
      check_ok "~/.ssh mode" "700"
    else
      check_fail "~/.ssh mode" "is $mode, ssh wants 700" "chmod 700 ~/.ssh"
    fi
  else
    check_fail "~/.ssh" "missing" "./modules/ssh/install.sh"
  fi

  check_symlink "~/.ssh/config" "$HOME/.ssh/config" "$MODULE/config" \
    "./modules/ssh/install.sh"

  # ssh follows the symlink and judges the repo file's own mode. A umask of 002
  # checks it out 664, which ssh rejects outright.
  if [[ -e "$HOME/.ssh/config" ]]; then
    mode="$(stat -Lc %a "$HOME/.ssh/config")"
    if [[ "$mode" == 644 || "$mode" == 600 ]]; then
      check_ok "ssh config mode" "$mode"
    else
      check_fail "ssh config mode" "is $mode; ssh rejects group-writable" \
        "chmod 644 $MODULE/config"
    fi
  fi

  local sock="$HOME/.1password/agent.sock" key="$HOME/.ssh/id_rsa"
  if [[ -S "$sock" ]]; then
    # ssh-add exits 2 when it cannot reach the agent, which under doctor.sh's
    # pipefail is the status of the whole pipeline and would abort this module
    # before it reported anything -- exactly when its output is most wanted.
    local keys
    keys="$(SSH_AUTH_SOCK="$sock" ssh-add -l 2>/dev/null | wc -l)" || keys=0
    if (( keys > 0 )); then
      check_ok "1Password agent" "$keys key(s) offered"
    else
      # The socket file outlives the app that served it, so this covers a dead
      # agent as well as a live one holding nothing.
      check_warn "1Password agent" "$sock is not answering with any keys" \
        "start and unlock 1Password, or enable its SSH agent"
    fi
  elif [[ -f "$key" ]]; then
    mode="$(stat -c %a "$key")"
    if [[ "$mode" == 600 ]]; then
      check_warn "ssh keys" "no agent; falling back to $key"
    else
      check_fail "ssh keys" "$key is $mode, ssh wants 600" "chmod 600 $key"
    fi
  else
    check_fail "ssh keys" "no agent socket and no $key" \
      "start 1Password and enable its SSH agent"
  fi
}
