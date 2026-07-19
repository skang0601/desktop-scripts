APP_NAME=zig

app_check() { have zig; }

app_install() {
  # Zig's release cadence is fast and breaking; if a project needs a version
  # other than the packaged one, install that one to ~/.local and let it shadow.
  install_cli zig
}
