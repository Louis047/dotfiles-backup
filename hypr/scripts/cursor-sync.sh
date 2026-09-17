#!/usr/bin/env bash
set -euo pipefail

# Ensure single instance runs
exec 200>/tmp/cursor-sync.lock
if ! flock -n 200; then
	exit 0
fi

SETTINGS="$HOME/.config/gtk-3.0/settings.ini"
UWSM_ENV="$HOME/.config/uwsm/env"

[[ -f "$SETTINGS" ]] || exit 1
command -v inotifywait >/dev/null 2>&1 || exit 1

apply_cursor() {
	local theme size
	theme=$(grep -oP 'gtk-cursor-theme-name=\K.*' "$SETTINGS" 2>/dev/null || true)
	size=$(grep -oP 'gtk-cursor-theme-size=\K.*' "$SETTINGS" 2>/dev/null || true)

	# Defaults if not set (defaulting to Adwaita/24)
	[[ -z "$theme" ]] && theme="Adwaita"
	[[ -z "$size" ]] && size=24

	# 1. Apply instantly to active desktop elements via hyprctl
	hyprctl setcursor "$theme" "$size" >/dev/null 2>&1 || true

	# 2. Sync GSettings for GTK/GNOME apps
	gsettings set org.gnome.desktop.interface cursor-theme "$theme" 2>/dev/null || true
	gsettings set org.gnome.desktop.interface cursor-size "$size" 2>/dev/null || true

	# 3. Export variables for running session (systemd & dbus-activation)
	export XCURSOR_THEME="$theme"
	export XCURSOR_SIZE="$size"
	export HYPRCURSOR_THEME="$theme"
	export HYPRCURSOR_SIZE="$size"
	systemctl --user import-environment XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE >/dev/null 2>&1 || true
	dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE >/dev/null 2>&1 || true

	# 4. Save persistently to UWSM env config for subsequent logins
	mkdir -p "$(dirname "$UWSM_ENV")"
	touch "$UWSM_ENV"
	
	local temp_env
	temp_env=$(mktemp)
	# Strip any existing cursor exports to prevent duplicates
	grep -v -E "^export (XCURSOR_THEME|XCURSOR_SIZE|HYPRCURSOR_THEME|HYPRCURSOR_SIZE)=" "$UWSM_ENV" > "$temp_env" || true
	
	# Append the new ones
	cat <<EOF >> "$temp_env"
export XCURSOR_THEME="$theme"
export XCURSOR_SIZE="$size"
export HYPRCURSOR_THEME="$theme"
export HYPRCURSOR_SIZE="$size"
EOF
	mv "$temp_env" "$UWSM_ENV"
}

# Initial apply at startup
apply_cursor

# Watch for GTK setting changes from tools like nwg-look
inotifywait -m -e close_write "$SETTINGS" 2>/dev/null | while read -r _dir _event _file; do
	sleep 0.2
	apply_cursor
done
