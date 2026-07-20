APP_NAME=claude-desktop

# Anthropic ship the desktop app for Debian and Ubuntu only; the docs state
# Fedora and RHEL are not supported yet. Rather than reach for a third-party
# repackage, run the official .deb in an Ubuntu distrobox and export the
# launcher onto the host: the app is first-party, and nothing is layered.
BOX=ubuntu
BOX_IMAGE=quay.io/toolbx/ubuntu-toolbox:24.04

# Published at https://code.claude.com/docs/en/desktop-linux. The repo is only
# added after the downloaded key matches this, so a substituted key fails the
# install rather than silently signing whatever it likes.
CLAUDE_KEY_FPR='31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE'

# distrobox-export names the host entry "<container>-<desktop id>.desktop", and
# the app's id is com.anthropic.Claude rather than its binary name. Matching the
# binary name instead finds nothing and reinstalls on every run.
EXPORTED="$HOME/.local/share/applications/$BOX-com.anthropic.Claude.desktop"

app_check() { [[ -f "$EXPORTED" ]]; }

app_install() {
  have distrobox || { warn "distrobox not available; it ships with Bazzite"; return 1; }

  if ! distrobox_exists "$BOX"; then
    say "creating the $BOX distrobox"
    run distrobox create --name "$BOX" --image "$BOX_IMAGE" --yes
  fi

  say "installing claude-desktop from Anthropic's apt repository inside $BOX"
  if dry; then
    printf '    [dry-run] distrobox enter %s -- <add apt repo, verify key, apt install claude-desktop>\n' "$BOX"
  else
    # A single non-interactive script: distrobox enter spawns a shell per call,
    # so the steps have to share one invocation to share state.
    distrobox enter --name "$BOX" -- bash -euo pipefail -c "
      export DEBIAN_FRONTEND=noninteractive
      sudo apt-get update -qq
      sudo apt-get install -y -qq curl gnupg ca-certificates

      sudo curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
        https://downloads.claude.ai/claude-desktop/key.asc

      # Fail before trusting the repo if the key is not the published one.
      got=\$(gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc \
              | awk -F: '/^fpr:/ {print \$10; exit}')
      if [ \"\$got\" != '$CLAUDE_KEY_FPR' ]; then
        echo \"key fingerprint mismatch: got \$got, expected $CLAUDE_KEY_FPR\" >&2
        sudo rm -f /usr/share/keyrings/claude-desktop-archive-keyring.asc
        exit 1
      fi

      echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main\" \
        | sudo tee /etc/apt/sources.list.d/claude-desktop.list >/dev/null

      sudo apt-get update -qq
      sudo apt-get install -y claude-desktop
    " || return 1
  fi

  say "exporting the launcher to the host"
  run distrobox enter --name "$BOX" -- distrobox-export --app claude-desktop

  # Quick Entry's global hotkey needs the GlobalShortcuts portal on native
  # Wayland, and Computer Use and dictation are absent from the Linux beta.
  say "beta: no Computer Use or dictation; updates come from 'apt upgrade' inside $BOX"
}
