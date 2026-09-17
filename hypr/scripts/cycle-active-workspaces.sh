#!/usr/bin/env bash
# Usage: cycle-active-workspaces.sh <next|prev>
DIRECTION=$1

# Get current workspace ID
CURRENT=$(hyprctl activeworkspace -j | jq '.id')

# Get sorted array of workspaces that actually have windows in them (regular workspaces only, excluding special/negative-id workspaces)
ACTIVE_WS=($(hyprctl workspaces -j | jq '.[] | select(.windows > 0 and .id > 0) | .id' | sort -n))

if [[ ${#ACTIVE_WS[@]} -eq 0 ]]; then
    exit 0
fi

# Find current index
INDEX=-1
for i in "${!ACTIVE_WS[@]}"; do
    if [[ "${ACTIVE_WS[$i]}" == "$CURRENT" ]]; then
        INDEX=$i
        break
    fi
done

# Calculate target
if [[ "$DIRECTION" == "next" ]]; then
    if [[ $INDEX -eq -1 || $INDEX -eq $((${#ACTIVE_WS[@]} - 1)) ]]; then
        TARGET=${ACTIVE_WS[0]} # Wrap to first
    else
        TARGET=${ACTIVE_WS[$((INDEX + 1))]}
    fi
else
    if [[ $INDEX -eq -1 || $INDEX -eq 0 ]]; then
        TARGET=${ACTIVE_WS[$((${#ACTIVE_WS[@]} - 1))]} # Wrap to last
    else
        TARGET=${ACTIVE_WS[$((INDEX - 1))]}
    fi
fi

hyprctl dispatch "hl.dsp.focus({ workspace = $TARGET })"
