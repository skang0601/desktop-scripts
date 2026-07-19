#!/usr/bin/env bash
# Shell environment: PATH and editor defaults for bash.
#
#   ./install.sh --dry-run
set -euo pipefail

MODULE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$MODULE/../../lib/common.sh"

for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    *) warn "unknown option: $a"; exit 2 ;;
  esac
done

dry && say "dry run -- nothing will be changed"

MARKER='# desktop-scripts: source ~/.bashrc.d'

# Fedora's stock ~/.bashrc already sources ~/.bashrc.d/*, but that is a distro
# convention rather than a bash one, so don't assume an image ships it.
ensure_bashrc_d_sourced() {
  local rc="$HOME/.bashrc"

  if [[ -f "$rc" ]] && grep -q 'bashrc\.d' "$rc"; then
    skip "~/.bashrc" "already sources ~/.bashrc.d"
    return 0
  fi

  say "adding a ~/.bashrc.d loader to ~/.bashrc"
  if dry; then
    printf '    [dry-run] append a ~/.bashrc.d loader to %s\n' "$rc"
    return 0
  fi

  cat >>"$rc" <<EOF

$MARKER
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    [ -f "\$rc" ] && . "\$rc"
  done
  unset rc
fi
EOF
}

ensure_bashrc_d_sourced

say "linking bashrc.d fragments"
for f in "$MODULE"/bashrc.d/*.sh; do
  link_config "$f" "$HOME/.bashrc.d/$(basename "$f")"
done

cat <<'EOF'

done. Open a new shell, or: source ~/.bashrc

  note  this affects shells, not GUI apps launched from the GNOME overview.
        Those read ~/.config/environment.d/, not ~/.bashrc.
EOF
