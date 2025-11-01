#!/bin/bash

echo "=== Power Management Diagnostics ==="
echo ""

# Check if scripts are running
echo "1. Running Processes:"
pgrep -a refresh-rate-manager || echo "  ❌ refresh-rate-manager NOT running"
pgrep -a hypridle-manager || echo "  ❌ hypridle-manager NOT running"
pgrep -a Hyprland || echo "  ❌ Hyprland NOT running"
echo ""

# Check systemd timer
echo "2. Systemd Timer Status:"
systemctl --user is-active auto-power-profile.timer
systemctl --user status auto-power-profile.timer --no-pager -l | tail -5
echo ""

# Check current power state
echo "3. Current Power State:"
echo "  AC Status:"
for ps in /sys/class/power_supply/A{C,DP}*; do
    if [[ -f "$ps/online" ]]; then
        echo "    $(basename $ps): $(cat $ps/online 2>/dev/null)"
    fi
done
echo "  Battery:"
for bat in /sys/class/power_supply/BAT*; do
    if [[ -f "$bat/capacity" ]]; then
        echo "    $(basename $bat): $(cat $bat/capacity)%"
    fi
done
echo "  Power Profile: $(powerprofilesctl get 2>/dev/null || echo 'ERROR')"
echo ""

# Check display info
echo "4. Display Info:"
echo "  Current refresh rate:"
hyprctl monitors -j | jq -r '.[] | "    \(.name): \(.refreshRate)Hz"' 2>/dev/null || echo "  ERROR: Can't read monitors"
echo ""

# Check log files
echo "5. Recent Log Entries:"
echo "  Refresh Rate Manager (last 5 lines):"
if [[ -f ~/.cache/hyprland-refresh-manager.log ]]; then
    tail -5 ~/.cache/hyprland-refresh-manager.log | sed 's/^/    /'
else
    echo "    ❌ Log file not found"
fi
echo ""
echo "  Hypridle Manager (last 5 lines):"
if [[ -f ~/.cache/hypridle-manager.log ]]; then
    tail -5 ~/.cache/hypridle-manager.log | sed 's/^/    /'
else
    echo "    ❌ Log file not found"
fi
echo ""
echo "  Auto Power Profile (last 5 lines):"
journalctl --user -u auto-power-profile.service -n 5 --no-pager 2>/dev/null | sed 's/^/    /' || echo "    ❌ No journal entries"
echo ""

# Check state files
echo "6. State Files:"
[[ -f ~/.cache/power-profile-state ]] && echo "  power-profile-state: $(cat ~/.cache/power-profile-state | tr '\n' ' ')" || echo "  ❌ power-profile-state missing"
[[ -f ~/.cache/power-profile-manual ]] && echo "  manual override: ACTIVE (timestamp: $(cat ~/.cache/power-profile-manual))" || echo "  manual override: inactive"
echo ""

# Check script permissions
echo "7. Script Permissions:"
ls -lh ~/.config/hypr/scripts/refresh-rate-manager.sh 2>/dev/null || echo "  ❌ refresh-rate-manager.sh not found"
ls -lh ~/.config/hypr/scripts/hypridle-manager.sh 2>/dev/null || echo "  ❌ hypridle-manager.sh not found"
ls -lh ~/.local/bin/auto-power-profile.sh 2>/dev/null || echo "  ❌ auto-power-profile.sh not found"
echo ""

echo "=== Diagnostic Complete ==="
echo ""
echo "Quick Actions:"
echo "  View refresh-rate log: tail -f ~/.cache/hyprland-refresh-manager.log"
echo "  View hypridle log: tail -f ~/.cache/hypridle-manager.log"
echo "  View power profile log: journalctl --user -u auto-power-profile.service -f"
echo "  Manually run power profile: ~/.local/bin/auto-power-profile.sh"
