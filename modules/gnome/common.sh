# Paths shared by install.sh and checks.sh.
# shellcheck shell=bash

# Studio Display brightness: the asd-brightness extension.
ASD_REMOTE=git@github.com:skang0601/asd-brightness.git
ASD_SRC="${ASD_SRC:-$HOME/Workspace/asd-brightness}"
ASD_UUID=studio-display-brightness@skang
ASD_EXT="$HOME/.local/share/gnome-shell/extensions/$ASD_UUID"
ASD_HELPER="$ASD_EXT/studio-display-helper"
# The project's install.sh copies over the extension directory without
# clearing it, so the stamp survives a rebuild until this module rewrites it.
ASD_STAMP="$ASD_EXT/.source-commit"

asd_head()  { git -C "$ASD_SRC" rev-parse HEAD 2>/dev/null || true; }
asd_built() { cat "$ASD_STAMP" 2>/dev/null || true; }

# Login screen display layout. mutter reads monitors.xml from the system config
# dirs as a fallback beneath each user's own, which gives the login screen,
# whatever user GDM runs it as, the same layout as this session.
GDM_SRC="$HOME/.config/monitors.xml"
GDM_DEST=/etc/xdg/monitors.xml

# Never suspend on idle. The phone reaches ollama and the OpenCode server on
# this machine over Tailscale, and a suspended desktop drops off the tailnet.
# Only automatic suspend is turned off; the screen still blanks, and suspend
# from the menu still works.
POWER_SCHEMA=org.gnome.settings-daemon.plugins.power
POWER_KEY=sleep-inactive-ac-type
GDM_POWER_SRC="$MODULE/gdm-power.dconf"
GDM_POWER_DEST=/etc/dconf/db/gdm.d/90-desktop-scripts-power
# What `dconf update` compiles gdm.d into, and what the login screen reads.
GDM_DCONF_DB=/etc/dconf/db/gdm
