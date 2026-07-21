# shellcheck shell=bash
APP_NAME=opentofu

# The language server is not a separate app: it is only ever useful against a
# tofu on the same machine, and installing one without the other gives an editor
# that lints Terraform it cannot run.
app_check() { have tofu && have tofu-ls; }

# Neither is in Fedora's repositories, so the brew-less path has nowhere to go.
# OpenTofu publish their own rpm repo, but adding it for a machine this repo has
# never run on would be guessing at that machine.
app_blocked() {
  have brew && return 1
  echo "not in Fedora's repositories, and there is no brew here to install it from"
  echo "add the repo at packages.opentofu.org by hand, or install Homebrew"
  return 0
}

app_install() {
  app_blocked >/dev/null && blocked "$(app_blocked)"

  run brew install opentofu
  run brew install tofu-ls
}
