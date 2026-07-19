APP_NAME=1password

app_check() { have 1password; }

app_install() {
  # NOT the Flathub build, despite it being vendor-verified. 1Password's docs
  # state the SSH agent does not work under Flatpak, and the manifest bears
  # that out: no --filesystem=home, and $HOME is redirected into the sandbox,
  # so ~/.1password/agent.sock can never appear on the host. The ssh module
  # depends on that socket, so the Flatpak would break git over ssh.
  add_1password_repo
  if is_atomic; then
    warn "layering 1password (needs a reboot before it is usable)"
    run sudo rpm-ostree install 1password
    : > "$LAYERED_MARKER"
  else
    run sudo dnf install -y 1password
  fi
}
