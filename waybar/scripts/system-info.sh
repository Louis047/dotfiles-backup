#!/bin/bash

# System Info Script for Waybar
# This script outputs system information in JSON format for Waybar

get_disk_usage() {
    # Get disk usage in GB for root partition
    local disk_used=$(df -h / | awk 'NR==2 {print $3}' | sed 's/G//')
    local disk_total=$(df -h / | awk 'NR==2 {print $2}' | sed 's/G//')
    echo "${disk_used}G/${disk_total}G"
}

get_cpu_usage() {
    # Get CPU usage percentage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    # Alternative method if the above doesn't work
    if [ -z "$cpu_usage" ]; then
        cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}')
    fi
    echo "${cpu_usage}%"
}

get_ram_usage() {
    # Get RAM usage percentage
    local ram_info=$(free | grep Mem)
    local total=$(echo $ram_info | awk '{print $2}')
    local used=$(echo $ram_info | awk '{print $3}')
    local percentage=$(awk "BEGIN {printf \"%.0f\", ($used/$total)*100}")
    echo "${percentage}%"
}

# Get system information
DISK=$(get_disk_usage)
CPU=$(get_cpu_usage)
RAM=$(get_ram_usage)

# Output in JSON format for Waybar
cat << EOF
{
    "text": "󰍛",
    "alt": "system-info",
    "tooltip": "Disk: $DISK\\nCPU: $CPU\\nRAM: $RAM",
    "class": "system-info"
}
EOF
