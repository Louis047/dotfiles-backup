#!/usr/bin/env bash

# 1. Reload Hyprland
hyprctl reload

# 2. Check noctalia status
if pgrep -x noctalia >/dev/null; then
    # Active: kill it and wait for exit, then start it
    pkill -x noctalia
    while pgrep -x noctalia >/dev/null; do
        sleep 0.1
    done
    nohup noctalia >/dev/null 2>&1 &
else
    # Inactive: run noctalia normally
    nohup noctalia >/dev/null 2>&1 &
fi
