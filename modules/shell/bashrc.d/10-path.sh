# PATH additions. Sourced from ~/.bashrc via ~/.bashrc.d/.

# Add to PATH only if present and not already there, so nested shells and
# re-sourcing don't accumulate duplicates.
_prepend_path() { [[ -d $1 && ":$PATH:" != *":$1:"* ]] && PATH="$1:$PATH"; }

# Doom Emacs. ~/.emacs.d is the legacy location and still shadows
# ~/.config/emacs when both exist, so whichever is present wins here too.
_prepend_path "$HOME/.config/emacs/bin"
_prepend_path "$HOME/.emacs.d/bin"

_prepend_path "$HOME/go/bin"
_prepend_path "$HOME/.cargo/bin"
_prepend_path "$HOME/.local/bin"

# JetBrains Toolbox is deliberately absent: it writes its own PATH line into
# ~/.bash_profile and ~/.profile on first run, so it is already handled. Those
# lines append unguarded, which duplicates the entry in nested login shells.

# Homebrew is how CLI tooling is installed on atomic systems (ADR 0005).
for _dir in /home/linuxbrew/.linuxbrew /opt/homebrew "$HOME/.linuxbrew"; do
  if [[ -x "$_dir/bin/brew" ]]; then
    eval "$("$_dir/bin/brew" shellenv)"
    break
  fi
done

# rustup is keg-only because it provides the same binaries as the rust formula,
# so it only wins from ahead of brew's own bin, which shellenv above prepends.
# $HOMEBREW_PREFIX/opt is `brew --prefix rustup` without a brew run per shell.
if [[ -n ${HOMEBREW_PREFIX:-} ]]; then
  _prepend_path "$HOMEBREW_PREFIX/opt/rustup/bin"
fi

unset _dir
unset -f _prepend_path
export PATH

if command -v emacsclient >/dev/null; then
  export EDITOR='emacsclient -nw -a vi'
  export VISUAL="$EDITOR"
fi
