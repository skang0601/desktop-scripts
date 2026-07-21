# shellcheck shell=bash
# Interactive aliases. Sourced from ~/.bashrc via ~/.bashrc.d/.
#
# Nothing here shadows an existing command, so a line copied from a script
# behaves the same when pasted here. Git shorthands live in the git module's
# gitconfig (`git s`, `git lg`, ...), where they also work over ssh.

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

# kubectx/kubens as shell functions -- kubectl config has done both natively
# since 1.10. Bare prints the current value; an argument switches it.
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
