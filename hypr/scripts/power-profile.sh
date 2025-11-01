#!/usr/bin/env bash
# Auto Power Profile Manager (Persistent, correct AC/battery logic)
# - AC -> performance
# - Battery -> balanced
# - Battery <= THRESHOLD -> power-saver
# - Manual override persists across reboots until AC change
#
# Save as: ~/.local/bin/auto-power-profile.sh
# Make executable: chmod +x ~/.local/bin/auto-power-profile.sh

set -euo pipefail
IFS=$'\n\t'

# ---------------------- Config ----------------------
WATCH_INTERVAL=${WATCH_INTERVAL:-2}                     # seconds between checks
THRESHOLD=${THRESHOLD:-30}                             # battery percent threshold for power-saver
OVERRIDE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/powerprofile_override"
LAST_AC_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/powerprofile_last_ac"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/auto-power-profile.log"

PROFILE_PERFORMANCE="performance"
PROFILE_BALANCED="balanced"
PROFILE_POWERSAVER="power-saver"

mkdir -p "${OVERRIDE_FILE%/*}"
mkdir -p "${LOG_FILE%/*}"

log() {
  echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

# ---------------------- Helpers ----------------------

# Detect AC state: returns 1 for plugged in, 0 for on battery
is_ac_connected() {
  # Prefer canonical power_supply entries
  for ps in /sys/class/power_supply/*; do
    [[ -e "$ps/type" ]] || continue
    t=$(cat "$ps/type" 2>/dev/null || true)
    # Recognize mains/AC adapters
    case "$t" in
      Mains|AC|ACAD|Adapter|USB*)
        if [[ -f "$ps/online" ]]; then
          val=$(cat "$ps/online" 2>/dev/null || echo 0)
          [[ "$val" == "1" ]] && { printf '1'; return 0; }
        fi
        ;;
    esac
  done
  # fallback to 0 if none found
  printf '0'
}

# Get average battery percentage (0-100). If no battery found, returns 100.
get_battery_pct() {
  local total=0 count=0
  for bat in /sys/class/power_supply/*; do
    [[ -f "$bat/type" ]] || continue
    t=$(cat "$bat/type" 2>/dev/null || true)
    [[ "$t" == "Battery" ]] || continue

    if [[ -f "$bat/capacity" ]]; then
      v=$(cat "$bat/capacity" 2>/dev/null || echo 0)
      total=$((total + v))
      count=$((count + 1))
    elif [[ -f "$bat/energy_now" && -f "$bat/energy_full" ]]; then
      now=$(cat "$bat/energy_now" 2>/dev/null || echo 0)
      full=$(cat "$bat/energy_full" 2>/dev/null || echo 1)
      pct=$(( (now * 100) / full ))
      total=$((total + pct))
      count=$((count + 1))
    elif [[ -f "$bat/charge_now" && -f "$bat/charge_full" ]]; then
      now=$(cat "$bat/charge_now" 2>/dev/null || echo 0)
      full=$(cat "$bat/charge_full" 2>/dev/null || echo 1)
      pct=$(( (now * 100) / full ))
      total=$((total + pct))
      count=$((count + 1))
    fi
  done

  if (( count == 0 )); then
    # No battery -> assume desktop / AC-like (100%)
    printf '%s' 100
  else
    printf '%s' $(( total / count ))
  fi
}

# Apply profile idempotently
apply_profile() {
  local profile="$1"
  if command -v powerprofilesctl >/dev/null 2>&1; then
    current=$(powerprofilesctl get 2>/dev/null || echo "")
    if [[ "$current" == "$profile" ]]; then
      log "profile '$profile' already active"
      return 0
    fi
    if powerprofilesctl set "$profile" >/dev/null 2>&1; then
      log "applied profile: $profile"
      # record choice in last-state log (not the same as override)
      return 0
    else
      log "failed to set profile via powerprofilesctl: $profile"
      return 1
    fi
  else
    log "powerprofilesctl not found; cannot apply profile: $profile"
    return 2
  fi
}

# Check persistent override file and apply if valid
check_and_apply_override() {
  if [[ -f "$OVERRIDE_FILE" ]]; then
    manual_profile=$(<"$OVERRIDE_FILE")
    manual_profile=$(echo "$manual_profile" | tr -d '\r\n' | xargs)
    if [[ "$manual_profile" =~ ^(performance|balanced|power-saver)$ ]]; then
      log "found persistent override: $manual_profile (re-applying)"
      apply_profile "$manual_profile" || true
      return 0
    else
      # invalid content -> remove
      rm -f "$OVERRIDE_FILE" 2>/dev/null || true
    fi
  fi
  return 1
}

# Decide profile by AC state and battery percentage
decide_profile() {
  local plugged="$1" bat_pct="$2"
  if [[ "$plugged" -eq 1 ]]; then
    printf '%s' "$PROFILE_PERFORMANCE"
  else
    if (( bat_pct <= THRESHOLD )); then
      printf '%s' "$PROFILE_POWERSAVER"
    else
      printf '%s' "$PROFILE_BALANCED"
    fi
  fi
}

# ---------------------- Main ----------------------

log "starting auto-power-profile (persistent mode)"
# Load last AC state if exists
last_ac_state="unknown"
if [[ -f "$LAST_AC_FILE" ]]; then
  last_ac_state=$(<"$LAST_AC_FILE")
fi

# Initial startup behavior:
# 1) If persistent override exists -> reapply it
# 2) Else, evaluate current AC/battery state and apply appropriate profile
if check_and_apply_override; then
  log "override applied on startup"
else
  cur_ac=$(is_ac_connected)
  bat_pct=$(get_battery_pct)
  desired=$(decide_profile "$cur_ac" "$bat_pct")
  apply_profile "$desired" || true
  # persist last_ac_state
  echo "$cur_ac" > "$LAST_AC_FILE"
  last_ac_state="$cur_ac"
fi

# Watch loop
while true; do
  sleep "$WATCH_INTERVAL"

  cur_ac=$(is_ac_connected)

  # Detect AC state change
  if [[ "$cur_ac" != "$last_ac_state" ]]; then
    log "AC state changed: $last_ac_state -> $cur_ac"
    # Clear persistent override on AC change (user preference no longer sticky)
    if [[ -f "$OVERRIDE_FILE" ]]; then
      rm -f "$OVERRIDE_FILE" 2>/dev/null || true
      log "cleared persistent override due to AC change"
    fi

    # Apply new auto decision
    bat_pct=$(get_battery_pct)
    desired=$(decide_profile "$cur_ac" "$bat_pct")
    apply_profile "$desired" || true

    # update last_ac_state persistent file
    echo "$cur_ac" > "$LAST_AC_FILE"
    last_ac_state="$cur_ac"
    continue
  fi

  # No AC change -> if override exists, keep enforcing it (so manual choice persists)
  if check_and_apply_override; then
    # override applied; continue loop
    continue
  fi

  # No override and no AC change: ensure auto logic still holds (e.g., battery drained below threshold)
  if [[ "$cur_ac" == "0" ]]; then
    bat_pct=$(get_battery_pct)
    desired=$(decide_profile "$cur_ac" "$bat_pct")
    apply_profile "$desired" || true
  fi
done
