#!/bin/bash

GTK3="$HOME/.config/gtk-3.0/settings.ini"
GTK4="$HOME/.config/gtk-4.0/settings.ini"
ENV_FILE="$HOME/.config/hypr/env-vars.conf"

apply_theme() {
    # Extract theme name & size from GTK3 file
    THEME=$(grep -m 1 "gtk-cursor-theme-name" "$GTK3" | cut -d= -f2)
    SIZE=$(grep -m 1 "gtk-cursor-theme-size" "$GTK3" | cut -d= -f2)

    # Fallback defaults
    THEME=${THEME:-Adwaita}
    SIZE=${SIZE:-24}

    # Apply immediately to running Hyprland session
    hyprctl setenv XCURSOR_THEME "$THEME"
    hyprctl setenv XCURSOR_SIZE "$SIZE"q
    hyprctl setenv HYPRCURSOR_THEME "$THEME"
    hyprctl setenv HYPRCURSOR_SIZE "$SIZE"

    # Export to systemd user env
    systemctl --user import-environment XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE

    # Update persistent env-vars.conf
    sed -i "s/^env = XCURSOR_THEME.*/env = XCURSOR_THEME,$THEME/" "$ENV_FILE"
    sed -i "s/^env = XCURSOR_SIZE.*/env = XCURSOR_SIZE,$SIZE/" "$ENV_FILE"
    sed -i "s/^env = HYPRCURSOR_THEME.*/env = HYPRCURSOR_THEME,$THEME/" "$ENV_FILE"
    sed -i "s/^env = HYPRCURSOR_SIZE.*/env = HYPRCURSOR_SIZE,$SIZE/" "$ENV_FILE"

    echo "Cursor theme synced to: $THEME ($SIZE) and saved to $ENV_FILE"
    
    # Apply the changes instantly
    CURSOR=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
    SIZE=$(gsettings get org.gnome.desktop.interface cursor-size)

    hyprctl setcursor "$CURSOR" "$SIZE"
}

# Initial apply on script start
apply_theme

# Watch for changes
inotifywait -m -e close_write "$GTK3" "$GTK4" | while read -r; do
    apply_theme
done

