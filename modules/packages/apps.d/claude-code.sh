APP_NAME=claude-code

app_check() { have claude; }

app_install() {
  # Vendor installer; lands in ~/.local/bin, so it needs no root and no layering.
  if dry; then
    printf '    [dry-run] curl -fsSL https://claude.ai/install.sh | bash\n'
  else
    curl -fsSL https://claude.ai/install.sh | bash
  fi
}
