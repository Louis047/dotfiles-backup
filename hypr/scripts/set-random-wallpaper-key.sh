#!/bin/bash

# Directory containing your wallpapers
WALLPAPER_DIR="$HOME/Pictures/Wallpapers/"

# Ensure swww is running
pgrep -x swww > /dev/null || swww init

# Pick a random wallpaper
wallpaper=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n 1)

# Set wallpaper with transition
swww img "$wallpaper" \
  --transition-type wipe \
  --transition-fps 144 \
  --transition-duration 0.4 \
  --transition-angle 0 \
  --resize crop
