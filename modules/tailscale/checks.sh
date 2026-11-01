# State checks for the tailscale module. Sourced by ../../doctor.sh.
# shellcheck shell=bash

module_checks() {
  # shellcheck source=lib.sh
  source "$MODULE/lib.sh"

  if ! have tailscale; then
    check_fail "tailscale" "not installed" "https://tailscale.com/download/linux"
    return 0
  fi

  if systemctl is-active --quiet tailscaled; then
    check_ok "tailscaled" "active"
  else
    check_fail "tailscaled" "not active" "./modules/tailscale/install.sh"
    return 0
  fi

  local state
  state="$(backend_state)"
  if [[ "$state" == Running ]]; then
    check_ok "tailnet" "$(magic_dns_name)"
  else
    check_fail "tailnet" "not connected (${state:-unknown})" "sudo tailscale up"
  fi

  if serving_opencode; then
    check_ok "opencode on tailnet" "https://$(magic_dns_name)/"
  else
    check_fail "opencode on tailnet" "not served" "./modules/tailscale/install.sh"
  fi
}
