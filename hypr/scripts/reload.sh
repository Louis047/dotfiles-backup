#!/usr/bin/env bash
set -e

hyprctl reload

pkill -x waybar || true
waybar &

swaync-client -R -rs || true
pkill -9 swayosd-server || true
swayosd-server &

# Reload and restart systemd user services
systemctl --user daemon-reload
systemctl --user restart elephant.service
systemctl --user restart walker.service
