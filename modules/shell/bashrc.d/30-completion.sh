# shellcheck shell=bash
# Bash completions for brew-installed tooling. Sourced from ~/.bashrc via
# ~/.bashrc.d/, after 10-path.sh has set HOMEBREW_PREFIX.
#
# Nothing reads brew's completion directory on its own. bash-completion loads
# from XDG data dirs and from one compat dir it hardcodes to /etc, and brew
# writes to $HOMEBREW_PREFIX/etc/bash_completion.d, which is neither -- so every
# brew formula's completion is installed and inert until something sources it.
#
# Sourced eagerly rather than loaded on demand because there is no hook to hang
# the lazy path off: bash-completion's dynamic loader only searches directories
# it already knows. The eager cost is small next to the loader machinery that
# would avoid it.
if [[ -n ${HOMEBREW_PREFIX:-} && -d "$HOMEBREW_PREFIX/etc/bash_completion.d" ]]; then
  for _completion in "$HOMEBREW_PREFIX"/etc/bash_completion.d/*; do
    # shellcheck source=/dev/null
    [[ -r "$_completion" ]] && source "$_completion"
  done
  unset _completion
fi

# The alias is a separate name as far as bash is concerned, so it completes on
# filenames until it is pointed at kubectl's completion function by hand. Guarded
# because that function only exists once the loop above has found kubectl.
if declare -F __start_kubectl >/dev/null; then
  complete -o default -F __start_kubectl k
fi
