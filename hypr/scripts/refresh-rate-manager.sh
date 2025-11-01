#!/usr/bin/env bash
set -euo pipefail

# prevent multiple instances
LOCKFILE="/tmp/hypr-refresh-rate-manager.lock"
if [ -f "$LOCKFILE" ]; then
    oldpid=$(cat "$LOCKFILE")
    if [ -d "/proc/$oldpid" ]; then
        echo "Instance already running (PID $oldpid), exiting."
        exit 0
    fi
fi
echo "$$" > "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

# Hyprland Refresh Rate Manager
# - Dynamically adapts refresh rate based on AC/battery state
# - Works instantly via inotify (if available)
# - Fully compatible with all refresh rates (60–500 Hz+)
# - Safe and event-driven
# For Laptops

### Config
BASE_REFRESH=${BASE_REFRESH:-60}    # battery refresh
CHECK_INTERVAL=${CHECK_INTERVAL:-2} # fallback polling interval (seconds)
LOG_FILE="${LOG_FILE:-$HOME/.cache/hyprland-refresh-manager.log}"
MONITORS_CONF="${MONITORS_CONF:-$HOME/.config/hypr/monitors.conf}"
DISPLAY_ID="${DISPLAY_ID:-eDP-1}"
SHOW_NOTIFICATIONS=${SHOW_NOTIFICATIONS:-0}  # 0 = quiet, 1 = show notify-send
USE_INOTIFY=${USE_INOTIFY:-1}                # 1 = use inotifywait if available

# helpers
log_message(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }

# get ac/battery status (robust)
get_ac_status() {
  for ps in /sys/class/power_supply/*; do
    [ -f "$ps/type" ] || continue
    t=$(cat "$ps/type")
    if [ "$t" = "Mains" ] || [ "$t" = "AC" ] || [[ "$t" == USB* ]]; then
      if [ "$(cat "$ps/online" 2>/dev/null || echo 0)" -eq 1 ]; then
        echo 1; return
      fi
    fi
  done
  # fallback to acpi if present
  if command_exists acpi; then
    if acpi -a 2>/dev/null | grep -q "on-line"; then echo 1; return; fi
  fi
  echo 0
}

# parse monitors.conf's base monitor config (no @rate)
get_base_monitor_config() {
  if [[ -f "$MONITORS_CONF" ]]; then
    local monitor_line
    monitor_line=$(grep "^monitor.*$DISPLAY_ID" "$MONITORS_CONF" | head -1 || true)
    if [[ -n "$monitor_line" ]]; then
      echo "$monitor_line" | sed 's/^monitor=[^,]*,\([^@]*\)@[^,]*\(.*\)/\1\2/'
    fi
  fi
}

# get current refresh as hyprctl reports (numeric)
get_current_refresh() {
  hyprctl monitors -j | jq -r ".[] | select(.name==\"$DISPLAY_ID\") | .refreshRate" 2>/dev/null || echo "unknown"
}

# set refresh rate (instant)
set_refresh_rate() {
  local rate=$1 base_config test_config new_rate
  base_config=$(get_base_monitor_config || true)

  if [[ -z "$base_config" ]]; then
    hyprctl keyword monitor "$DISPLAY_ID,preferred,auto,$rate" >/dev/null 2>&1 || true
  else
    test_config=$(echo "$base_config" | sed -E "s/^([0-9]+x[0-9]+)/\\1@${rate}/")
    hyprctl keyword monitor "$DISPLAY_ID,$test_config" >/dev/null 2>&1 || true
  fi

  sleep 0.08
  new_rate=$(get_current_refresh)
  if [[ "${new_rate%.*}" == "$rate" || "$new_rate" == "$rate"* ]]; then
    log_message "Refresh: set to ${rate}Hz for $DISPLAY_ID"
    if [[ "$SHOW_NOTIFICATIONS" -eq 1 && "$(command -v notify-send || true)" ]]; then
      notify-send -t 1200 -u low "Refresh Rate" "${rate}Hz" 2>/dev/null || true
    fi
    return 0
  else
    log_message "Refresh: failed to set ${rate}Hz (current ${new_rate})"
    return 1
  fi
}

# write monitors.conf update atomically (background)
update_monitors_conf_async() {
  local new_rate=$1
  if [[ -f "$MONITORS_CONF" ]]; then
    (
      cp "$MONITORS_CONF" "$MONITORS_CONF.backup" 2>/dev/null || true
      sed -E -i.bak "s/(^monitor[^,]*$DISPLAY_ID[^@]*@)[0-9]+(.*)/\\1${new_rate}\\2/" "$MONITORS_CONF" 2>/dev/null || true
      log_message "monitors.conf updated to ${new_rate}Hz (background)"
    ) &
  fi
}

# detect max refresh for display (improved, safe)
detect_max_refresh_rate() {
  local max_rate="$BASE_REFRESH"
  local conf_rate hypr_modes highest_hypr

  # 1) prefer explicit rate from monitors.conf if present
  if [[ -f "$MONITORS_CONF" ]]; then
    conf_rate=$(grep "^monitor.*$DISPLAY_ID" "$MONITORS_CONF" | sed -n 's/.*@\([0-9]*\).*/\1/p' | head -1 || true)
    if [[ -n "$conf_rate" && "$conf_rate" -gt "$max_rate" ]]; then
      max_rate="$conf_rate"
    fi
  fi

  # 2) use hyprctl availableModes (handles all refresh rates)
  hypr_modes=$(hyprctl monitors -j 2>/dev/null | jq -r ".[] | select(.name==\"$DISPLAY_ID\") | (.availableModes[]?.refreshRate // empty)" 2>/dev/null || true)
  if [[ -n "$hypr_modes" ]]; then
    highest_hypr=$(printf "%s\n" $hypr_modes | awk -F'.' '{print $1}' | sort -n | tail -1 || true)
    if [[ -n "$highest_hypr" && "$highest_hypr" -gt "$max_rate" ]]; then
      max_rate="$highest_hypr"
    fi
  fi

  # 3) fallback to common high rates if still base
  if [[ "$max_rate" -le "$BASE_REFRESH" ]]; then
    for r in 165 144 120 90 75; do
      if [[ "$r" -gt "$max_rate" ]]; then
        local base_cfg
        base_cfg=$(get_base_monitor_config || true)
        if [[ -n "$base_cfg" ]]; then
          local test_cfg
          test_cfg=$(echo "$base_cfg" | sed -E "s/^([0-9]+x[0-9]+)/\\1@${r}/")
          if hyprctl keyword monitor "$DISPLAY_ID,$test_cfg" >/dev/null 2>&1; then
            sleep 0.12
            local actual=$(get_current_refresh)
            if [[ "${actual%.*}" == "$r" || "$actual" == "$r"* ]]; then
              max_rate="$r"
              break
            fi
          fi
        fi
      fi
    done
  fi

  echo "$max_rate"
}

# detect display automatic
detect_display_id() {
  if hyprctl monitors -j | jq -e ".[] | select(.name==\"$DISPLAY_ID\")" >/dev/null 2>&1; then
    echo "$DISPLAY_ID"; return
  fi
  mapfile -t displays < <(hyprctl monitors -j | jq -r '.[].name' 2>/dev/null || true)
  for p in eDP-1 eDP-2 LVDS-1 LVDS-2 DSI-1; do
    for d in "${displays[@]}"; do
      if [[ "$d" == "$p" ]]; then echo "$d"; return; fi
    done
  done
  if [[ ${#displays[@]} -gt 0 ]]; then echo "${displays[0]}"; else echo ""; fi
}

# cleanup
cleanup() { log_message "Refresh rate manager stopped"; exit 0; }
trap cleanup SIGTERM SIGINT

# Start
log_message "Starting Refresh Rate Manager (final)"
DISPLAY_ID_ORIG="$DISPLAY_ID"
DISPLAY_ID=$(detect_display_id || true)
if [[ -z "$DISPLAY_ID" ]]; then log_message "No display detected"; exit 1; fi
if [[ "$DISPLAY_ID" != "$DISPLAY_ID_ORIG" ]]; then log_message "Display auto-detected: $DISPLAY_ID (was $DISPLAY_ID_ORIG)"; fi

MAX_REFRESH=$(detect_max_refresh_rate || echo "$BASE_REFRESH")
log_message "Detected max refresh ${MAX_REFRESH}Hz; base ${BASE_REFRESH}Hz"
if [[ "$MAX_REFRESH" -le "$BASE_REFRESH" ]]; then
  log_message "Max <= base, will not increase on AC"
fi

# initial set
current_ac=$(get_ac_status)
LAST_AC_STATUS="$current_ac"
if [[ "$current_ac" == "1" && "$MAX_REFRESH" -gt "$BASE_REFRESH" ]]; then
  set_refresh_rate "$MAX_REFRESH" && update_monitors_conf_async "$MAX_REFRESH"
  log_message "Initial: AC -> ${MAX_REFRESH}Hz"
else
  set_refresh_rate "$BASE_REFRESH" && update_monitors_conf_async "$BASE_REFRESH"
  log_message "Initial: Battery -> ${BASE_REFRESH}Hz"
fi

# inotify for instant reaction
if [[ "$USE_INOTIFY" -eq 1 && "$(command -v inotifywait || true)" ]]; then
  log_message "Using inotifywait to watch $MONITORS_CONF and /sys/class/power_supply"
  ( inotifywait -m -e modify "$MONITORS_CONF" /sys/class/power_supply 2>/dev/null | while read -r path ev file; do
      MAX_REFRESH=$(detect_max_refresh_rate || echo "$BASE_REFRESH")
      if [[ "$(get_ac_status)" == "1" && "$MAX_REFRESH" -gt "$BASE_REFRESH" ]]; then
        set_refresh_rate "$MAX_REFRESH" && update_monitors_conf_async "$MAX_REFRESH"
        log_message "inotify: AC -> ${MAX_REFRESH}Hz"
      else
        set_refresh_rate "$BASE_REFRESH" && update_monitors_conf_async "$BASE_REFRESH"
        log_message "inotify: Battery -> ${BASE_REFRESH}Hz"
      fi
    done ) &
fi

# main loop fallback (keeps monitoring AC state)
while true; do
  sleep "$CHECK_INTERVAL"
  if ! pgrep -x "Hyprland" >/dev/null 2>&1; then log_message "Hyprland not running, exiting"; exit 0; fi
  current_status=$(get_ac_status)
  if [[ "$current_status" != "$LAST_AC_STATUS" ]]; then
    if [[ "$current_status" == "1" ]]; then
      if [[ "$MAX_REFRESH" -gt "$BASE_REFRESH" ]]; then
        set_refresh_rate "$MAX_REFRESH" && update_monitors_conf_async "$MAX_REFRESH"
        log_message "AC plugged in -> ${MAX_REFRESH}Hz"
      fi
    else
      set_refresh_rate "$BASE_REFRESH" && update_monitors_conf_async "$BASE_REFRESH"
      log_message "On battery -> ${BASE_REFRESH}Hz"
    fi
    LAST_AC_STATUS="$current_status"
  fi
done
