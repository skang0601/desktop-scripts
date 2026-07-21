# shellcheck shell=bash
# Sourced after 10-path.sh, which sets HOMEBREW_PREFIX.
#
# brew writes completions to $HOMEBREW_PREFIX/etc/bash_completion.d, which
# bash-completion never reads: it loads from XDG data dirs and one compat dir
# hardcoded to /etc. So every formula's completion sits inert until sourced.
if [[ -n ${HOMEBREW_PREFIX:-} && -d "$HOMEBREW_PREFIX/etc/bash_completion.d" ]]; then
  for _completion in "$HOMEBREW_PREFIX"/etc/bash_completion.d/*; do
    # shellcheck source=/dev/null
    [[ -r "$_completion" ]] && source "$_completion"
  done
  unset _completion
fi

# The alias is a separate name to bash, so `k` completes on filenames until
# pointed at kubectl's function -- which exists only once the loop above ran.
if declare -F __start_kubectl >/dev/null; then
  complete -o default -F __start_kubectl k
fi
