# shellcheck shell=bash
# Interactive aliases. Sourced from ~/.bashrc via ~/.bashrc.d/.
#
# Nothing here is allowed to change what a *command* does -- no `alias
# grep=...` that a copied line then behaves differently under. These are new
# names for longer commands, so anything written against the real name still
# means what it says.
#
# Git shorthands are deliberately absent: they live in the git module's
# gitconfig as `git s`, `git lg`, `git last`, `git unstage`, which work over ssh
# and inside editors that never read this file.

alias ls='ls --color=auto'
alias ll='ls -lh --color=auto'
alias la='ls -lAh --color=auto'

# -I, not -i: one prompt for a whole recursive delete or more than three files,
# rather than a prompt per file that becomes a reflex to answer y.
alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'

alias k=kubectl
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs -f'
alias kx='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'

# Functions, not aliases: both answer "which one am I on?" when called bare and
# switch when given an argument, and both are what `kubectx`/`kubens` are
# usually installed for -- kubectl has done it natively since 1.10.
kctx() {
  if (($# == 0)); then
    kubectl config get-contexts
  else
    kubectl config use-context "$1"
  fi
}

kns() {
  if (($# == 0)); then
    kubectl config view --minify -o 'jsonpath={..namespace}{"\n"}'
  else
    kubectl config set-context --current --namespace "$1"
  fi
}
