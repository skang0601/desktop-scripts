# shellcheck shell=bash
APP_NAME=jetbrains-toolbox

# Toolbox self-installs into ~/.local/share/JetBrains/Toolbox on first run and
# manages itself from then on; neither the cask nor the tarball does more than
# bootstrap it. Detect the self-installed state as well as the bootstrap binary,
# which it may remove.
TOOLBOX_DATA="$HOME/.local/share/JetBrains/Toolbox"

CASK="$UBLUE_TAP/jetbrains-toolbox-linux"

app_check() {
  [[ -d "$TOOLBOX_DATA/apps" || -f "$TOOLBOX_DATA/state.json" ]] || have jetbrains-toolbox
}

app_install() {
  if have brew; then
    # The cask unpacks JetBrains' own tarball -- the same bytes the fallback
    # below fetches -- and additionally installs the .desktop entry, which the
    # tarball leaves to Toolbox's first run.
    say "trusting $UBLUE_TAP; its casks repackage vendors' own Linux builds"
    brew_tap_trusted "$UBLUE_TAP"
    run brew install --cask "$CASK"
    return 0
  fi

  # No package, Flatpak or vendor repo is published, so without brew the tarball
  # is the only supported route.
  local api='https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release'
  local url
  url=$(curl -fsSL "$api" | python3 -c \
    'import sys,json;print(json.load(sys.stdin)["TBA"][0]["downloads"]["linux"]["link"])') || {
      warn "could not resolve the JetBrains Toolbox download URL"; return 1; }

  if dry; then
    printf '    [dry-run] curl -fsSL %s\n' "$url"
    printf '    [dry-run]   | tar xz -> %s/.local/bin/jetbrains-toolbox\n' "$HOME"
    return 0
  fi

  local tmp; tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL "$url" | tar xz -C "$tmp" --strip-components=1
  mkdir -p "$HOME/.local/bin"
  install -m755 "$tmp/jetbrains-toolbox" "$HOME/.local/bin/jetbrains-toolbox"
  say "run 'jetbrains-toolbox' once; it self-installs and then updates itself"
}
