#!/usr/bin/env bash

HYPR_MONITORS_LUA="$HOME/.config/hypr/monitors.lua"
HYPR_MONITORS_CONF="$HOME/.config/hypr/monitors.conf"

is_laptop() {
    [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]
}

get_ac_state() {
    # Robust: any power_supply with online==1 means AC is plugged.
    # Handles ACAD, ADP*, AC*, and USB-C ucsi-source-psy-* on this machine.
    for online_file in /sys/class/power_supply/*/online; do
        [ -e "$online_file" ] || continue
        if [ "$(cat "$online_file" 2>/dev/null)" = "1" ]; then
            echo 1
            return
        fi
    done
    echo 0
}

apply_to_conf() {
    local file="$1" target_output="$2" newmode="$3"
    [ -f "$file" ] || return 1
    # monitors.conf format: monitor=eDP-1,1920x1080@144.0,0x0,1.0
    # Preserve existing file; only update matching output's mode.
    local tmp
    tmp=$(mktemp)
    awk -v target="$target_output" -v newmode="$newmode" '
    {
        if (index($0, target) > 0 && $0 ~ /^monitor=/) {
            # replace the resolution@refresh part (second field)
            n = split($0, parts, ",")
            if (n >= 2) {
                parts[2] = newmode
                out = parts[1]
                for (i=2; i<=n; i++) out = out "," parts[i]
                print out
                next
            }
        }
        print $0
    }
    ' "$file" > "$tmp"
    if cmp -s "$file" "$tmp"; then
        rm -f "$tmp"
        return 1
    else
        mv "$tmp" "$file"
        return 0
    fi
}

apply_to_lua() {
    local file="$1" target_output="$2" newmode="$3"
    [ -f "$file" ] || return 1

    awk -v target="$target_output" -v newmode="$newmode" '
    BEGIN { inblock=0; matched=0; buf="" }
    /hl\.monitor\(\{/ {
        inblock=1
        matched=0
        buf=""
    }
    {
        if (inblock) {
            if ($0 ~ /output[ \t]*=/ && index($0, target) > 0) {
                matched=1
            }
            buf = buf $0 "\n"
            if ($0 ~ /^\}\)/) {
                inblock=0
                if (matched) {
                    sub(/mode[ \t]*=[ \t]*"[^"]*"/, "mode = \"" newmode "\"", buf)
                }
                printf "%s", buf
                buf=""
            }
        } else {
            print $0
        }
    }
    ' "$file" > "${file}.tmp"

    if cmp -s "$file" "${file}.tmp"; then
        rm -f "${file}.tmp"
        return 1
    else
        mv "${file}.tmp" "$file"
        return 0
    fi
}

update_refresh_rate() {
    local state="$1"
    local info target_output="eDP-1" width height res target_full target_rr newmode

    [ -f "$HYPR_MONITORS_LUA" ] || return

    info=$(hyprctl monitors -j | jq -c --arg name "$target_output" '
        first(.[] | select(.name == $name or (.name | test("^eDP"))))
    ')
    [ -z "$info" ] || [ "$info" = "null" ] && return

    target_output=$(jq -r '.name' <<< "$info")
    width=$(jq -r '.width' <<< "$info")
    height=$(jq -r '.height' <<< "$info")
    res="${width}x${height}"

    if [ "$state" = "AC" ]; then
        target_full=$(jq -r --arg res "$res" '
            [.availableModes[] | select(startswith($res + "@"))]
            | sort_by(sub("^.*@"; "") | rtrimstr("Hz") | tonumber)
            | last // empty
        ' <<< "$info")
    else
        target_full=$(jq -r --arg res "$res" '
            [.availableModes[] | select(startswith($res + "@")) | select((sub("^.*@"; "") | rtrimstr("Hz") | tonumber | round) == 60)]
            | sort_by(sub("^.*@"; "") | rtrimstr("Hz") | tonumber)
            | last // empty
        ' <<< "$info")
    fi

    [ -z "$target_full" ] || [ "$target_full" = "null" ] && return

    target_rr="${target_full#${res}@}"
    target_rr="${target_rr%Hz}"
    newmode="${res}@${target_rr}"

    local lua_changed=0 conf_changed=0
    if apply_to_lua "$HYPR_MONITORS_LUA" "$target_output" "$newmode"; then
        lua_changed=1
    fi
    if apply_to_conf "$HYPR_MONITORS_CONF" "$target_output" "$newmode"; then
        conf_changed=1
    fi
    if [ "$lua_changed" = "1" ] || [ "$conf_changed" = "1" ]; then
        hyprctl reload
    fi
}

set_power_profile() {
    local target current
    [ "$1" = "AC" ] && target="performance" || target="balanced"
    current=$(powerprofilesctl get)
    [ "$current" = "$target" ] && return
    powerprofilesctl set "$target"
}

main() {
    is_laptop || exit 0
    sleep 0.5

    [ "$(get_ac_state)" = "1" ] && state="AC" || state="BAT"

    update_refresh_rate "$state"
    set_power_profile "$state"
}

main
