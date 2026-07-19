APP_NAME=1password

app_check() { have 1password; }

app_install() {
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
  # The `op` CLI has no such scriptlet and still layers, so the ssh module's
  # agent socket is the only thing actually lost here.
  if is_atomic; then
    blocked "1password: upstream %post is broken on ostree systems; re-run once 1Password ships the fix"
  fi

  add_1password_repo
  install_rpm 1password
}
