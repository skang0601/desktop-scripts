APP_NAME=1password

# 1Password's own RPM repo. Both the desktop app and the `op` CLI come from it;
# neither is in Fedora's repos, and the Flathub build cannot serve the SSH agent.
#
# gpgkey is written unquoted, unlike 1Password's own snippet: rpm-ostree has
# been reported to fail with "Signing key not found" on the quoted form
# (fedora-silverblue/issue-tracker#658).
add_1password_repo() {
  [[ -f /etc/yum.repos.d/1password.repo ]] && return 0

  run sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
  if dry; then
    printf '    [dry-run] write /etc/yum.repos.d/1password.repo\n'
  else
    printf '%s\n' \
      '[1password]' \
      'name="1Password Stable Channel"' \
      'baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch' \
      'enabled=1' \
      'gpgcheck=1' \
      'gpgkey=https://downloads.1password.com/linux/keys/1password.asc' |
      sudo install -Dm644 /dev/stdin /etc/yum.repos.d/1password.repo
  fi
}

app_check() { have 1password && have op; }

app_install() {
  add_1password_repo

  # The CLI is installed before the desktop app because the desktop app calls
  # `blocked` on ostree, and that exits the whole app subshell. `op` carries no
  # broken scriptlet and layers fine, so the reverse order would strand the ssh
  # module without it on exactly the systems that already cannot get the agent
  # socket.
  have op || install_rpm 1password-cli

  if have 1password; then
    return 0
  fi

  # NOT the Flathub build, despite it being vendor-verified. 1Password's docs
  # state the SSH agent does not work under Flatpak, and the manifest bears
  # that out: no --filesystem=home, and $HOME is redirected into the sandbox,
  # so ~/.1password/agent.sock can never appear on the host. The ssh module
  # depends on that socket, so the Flatpak would break git over ssh.
  # The desktop RPM cannot be layered as of 1Password 8.11 (2026-07): its %post
  # runs `mkdir -p /usr/local/bin`, and on an ostree system /usr/local is a
  # symlink into /var, which rpm-ostree's bwrap sandbox leaves unpopulated. The
  # mkdir gets EEXIST on the dangling symlink and the scriptlet aborts, which
  # rpm-ostree treats as fatal where dnf would only warn. 1Password have
  # acknowledged it and are working on a fix with no timeline:
  # https://www.1password.community/1password-at-home-31/update-to-fedora-silverblue-fails-25075
  #
  # `op` is already in by this point, so the agent socket is the only thing
  # actually lost here.
  if is_atomic; then
    blocked "1password: upstream %post is broken on ostree systems; re-run once 1Password ships the fix"
  fi

  install_rpm 1password
}
