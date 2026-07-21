# shellcheck shell=bash
APP_NAME=go

# Released on their own cadences rather than with the toolchain, so they are
# part of this app rather than apps of their own. gopls is the language server
# :lang go +lsp drives; the other two back the struct-tag and test-generation
# commands Doom binds keys to.
GO_TOOLS=(
  "gopls        golang.org/x/tools/gopls"
  "gomodifytags github.com/fatih/gomodifytags"
  "gotests      github.com/cweill/gotests/gotests"
)

app_check() {
  have go || return 1
  local tool
  for tool in "${GO_TOOLS[@]}"; do
    have "${tool%% *}" || return 1
  done
}

app_install() {
  # Fedora calls it golang, brew calls it go.
  install_cli golang go

  local tool name path
  for tool in "${GO_TOOLS[@]}"; do
    name="${tool%% *}"
    path="${tool##* }"
    have "$name" && continue
    if have brew; then
      run brew install "$name"
    else
      # Not dnf: `go install` is upstream's route, it needs only the toolchain
      # installed above, and it lands in ~/go/bin, which modules/shell already
      # puts on PATH.
      run go install "$path@latest"
    fi
  done
}
