#!/usr/bin/env bash
set -euo pipefail

# Waybar Power Profile Script
# - Displays current power profile (performance/balanced/power-saver)
# - Cycles on click (Left click)
# - Integrates cleanly with auto-power-profile.service

PROFILES=("performance" "balanced" "power-saver")

# Nerd Font icons
get_icon() {
  case "$1" in
    performance) echo "" ;;   # bolt icon
    balanced)    echo "" ;;   # balance icon
    power-saver) echo "" ;;   # leaf icon
    *)           echo "" ;;   # question icon
  esac
}

get_current_profile() {
  powerprofilesctl get 2>/dev/null || echo "balanced"
}

set_profile() {
  local profile="$1"
  # explicitly call powerprofilesctl with the user bus
  powerprofilesctl set "$profile" >/dev/null 2>&1 || true
  notify-send -u low -t 1000 "Power Profile: ${profile^}"
}

cycle_profile() {
  local current next
  current=$(get_current_profile)
  for i in "${!PROFILES[@]}"; do
    if [[ "${PROFILES[$i]}" == "$current" ]]; then
      next_index=$(( (i + 1) % ${#PROFILES[@]} ))
      next="${PROFILES[$next_index]}"
      break
    fi
  done
  set_profile "$next"
}

output_json() {
  local profile icon
  profile=$(get_current_profile)
  icon=$(get_icon "$profile")
  echo "{\"text\":\"$icon\",\"tooltip\":\"Power Profile: $profile\",\"class\":\"$profile\"}"
}

# ──────────────────────────────
# Waybar click handler
# ──────────────────────────────
if [[ "${1:-}" == "click" ]]; then
  # Delay ensures Waybar doesn't re-poll before set completes
  cycle_profile
  sleep 0.3
  output_json
  exit 0
fi

# Default (for Waybar polling)
output_json
