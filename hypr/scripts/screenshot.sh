#!/usr/bin/env bash
set -euo pipefail

# Configuration
TEMP_SCREENSHOT_DIR="/tmp/screenshots"
GIF_DIR="$HOME/Videos/GIFs"
PID_FILE="/tmp/wf-recorder.pid"
TEMP_VIDEO="/tmp/temp_recording.mkv"

# Create directories
mkdir -p "$TEMP_SCREENSHOT_DIR" "$GIF_DIR"

# Utility functions
timestamp() {
    date +'%Y%m%d_%H%M%S'
}

# Kill any running slurp processes to prevent duplicates
kill_existing_slurp() {
    # Kill any existing slurp processes silently
    if pgrep -x "slurp" >/dev/null 2>&1; then
        pkill -x "slurp" 2>/dev/null || true
        sleep 0.2  # Give it time to clean up
    fi
}

notify_screenshot_success() {
    local file="$1"
    
    # Simple and reliable SwayNC approach
    # Create a one-time action script
    local action_id="edit_$(date +%s)"
    local action_script="/tmp/${action_id}.sh"
    
    cat > "$action_script" << EOF
#!/bin/bash
swappy -f "$file"
rm -f "$action_script"
EOF
    chmod +x "$action_script"
    
    # Use the most compatible notify-send format for SwayNC
    notify-send "Screenshot Captured" \
                "Screenshot copied to clipboard" \
                --app-name="Screenshot" \
                --icon="$file" \
                --expire-time=10000 \
                --action="$action_id=Edit with Swappy" \
                --wait 2>/dev/null | {
        # This runs when an action is clicked
        while read -r clicked_action; do
            if [[ "$clicked_action" == "$action_id" ]]; then
                "$action_script" &
                break
            fi
        done
    } &
    
    # Store the last screenshot path
    echo "$file" > "/tmp/last_screenshot.txt"
    
    # Cleanup fallback
    {
        sleep 15
        [[ -f "$action_script" ]] && rm -f "$action_script" 2>/dev/null
        sleep 585  # Total 10 minutes
        [[ -f "$file" ]] && rm -f "$file" 2>/dev/null
    } &
}

notify_screenshot_failed() {
    local title="$1"
    local message="${2:-$1}"
    notify-send -a "Screenshot" \
                -i "dialog-error" \
                "$title" \
                "$message" \
                -t 3000 2>/dev/null || true
}

notify_recording() {
    local title="$1"
    local message="$2"
    local icon="${3:-media-record}"
    notify-send -a "Recording" -i "$icon" "$title" "$message" -t 3000 2>/dev/null || true
}

copy_to_clipboard() {
    local file="$1"
    # Use maximum quality PNG compression for clipboard
    wl-copy --type image/png < "$file" 2>/dev/null || true
}

get_active_window_geometry() {
    # Get active window info using hyprctl
    local window_info
    window_info=$(hyprctl activewindow -j 2>/dev/null) || return 1
    
    # Check if we got valid window info
    local address
    address=$(echo "$window_info" | jq -r '.address // empty' 2>/dev/null)
    [[ -n "$address" && "$address" != "null" && "$address" != "" ]] || return 1
    
    # Extract position and size
    local x y width height
    x=$(echo "$window_info" | jq -r '.at[0]' 2>/dev/null) || return 1
    y=$(echo "$window_info" | jq -r '.at[1]' 2>/dev/null) || return 1
    width=$(echo "$window_info" | jq -r '.size[0]' 2>/dev/null) || return 1
    height=$(echo "$window_info" | jq -r '.size[1]' 2>/dev/null) || return 1
    
    # Validate values
    [[ "$x" =~ ^-?[0-9]+$ ]] || return 1
    [[ "$y" =~ ^-?[0-9]+$ ]] || return 1
    [[ "$width" =~ ^[0-9]+$ ]] || return 1
    [[ "$height" =~ ^[0-9]+$ ]] || return 1
    
    # Return geometry in format expected by grim/wf-recorder
    echo "${x},${y} ${width}x${height}"
}

# Validate selection size (minimum 10x10 pixels)
validate_selection_size() {
    local selection="$1"
    
    # Parse selection format: "x,y widthxheight"
    local width height
    if [[ "$selection" =~ ([0-9]+)x([0-9]+)$ ]]; then
        width="${BASH_REMATCH[1]}"
        height="${BASH_REMATCH[2]}"
        
        # Check minimum size (10x10 pixels)
        if [[ $width -lt 10 ]] || [[ $height -lt 10 ]]; then
            return 1
        fi
        return 0
    fi
    
    # If we can't parse, assume it's valid (fallback)
    return 0
}

is_recording() {
    # Check if PID file exists
    if [[ ! -f "$PID_FILE" ]]; then
        return 1  # Not recording
    fi
    
    # Read the PID
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    
    # Check if PID is valid and process is running
    if [[ -z "$pid" ]]; then
        rm -f "$PID_FILE"
        return 1  # Not recording
    fi
    
    # Check if the process is actually running
    if ps -p "$pid" >/dev/null 2>&1; then
        return 0  # Recording is active
    else
        # Stale PID file, remove it
        rm -f "$PID_FILE"
        return 1  # Not recording
    fi
}

# Screenshot functions
screenshot_region() {
    # Kill any existing slurp processes first
    kill_existing_slurp
    
    local file="$TEMP_SCREENSHOT_DIR/screenshot_region_$(timestamp).png"
    local selection
    
    # Get region selection with timeout to detect cancellation
    if ! selection=$(slurp 2>/dev/null); then
        # User cancelled (ESC key) - exit silently
        exit 0
    fi
    
    # Validate selection size
    if ! validate_selection_size "$selection"; then
        notify_screenshot_failed "Selection Too Small" "Minimum size: 10×10 pixels"
        exit 1
    fi
    
    # Take screenshot with maximum quality settings
    if grim -t png -l 9 -g "$selection" "$file" 2>/dev/null; then
        copy_to_clipboard "$file"
        notify_screenshot_success "$file"
    else
        notify_screenshot_failed "Capture Failed" "Failed to capture region"
        exit 1
    fi
}

screenshot_window() {
    # Kill any existing slurp processes first
    kill_existing_slurp
    
    local file="$TEMP_SCREENSHOT_DIR/screenshot_window_$(timestamp).png"
    local geometry
    
    # Get active window geometry
    if ! geometry=$(get_active_window_geometry); then
        notify_screenshot_failed "No Active Window" "No window found"
        exit 1
    fi
    
    # Add small delay to ensure window is ready
    sleep 0.1
    
    # Take screenshot using maximum quality settings
    if grim -t png -l 9 -g "$geometry" "$file" 2>/dev/null; then
        copy_to_clipboard "$file"
        notify_screenshot_success "$file"
    else
        [[ -f "$file" ]] && rm -f "$file"  # Clean up empty file
        notify_screenshot_failed "Capture Failed" "Failed to capture window"
        exit 1
    fi
}

screenshot_fullscreen() {
    # Kill any existing slurp processes first (cleanup)
    kill_existing_slurp
    
    local file="$TEMP_SCREENSHOT_DIR/screenshot_full_$(timestamp).png"
    
    # Take screenshot with maximum quality settings
    if grim -t png -l 9 "$file" 2>/dev/null; then
        copy_to_clipboard "$file"
        notify_screenshot_success "$file"
    else
        notify_screenshot_failed "Capture Failed" "Failed to capture screen"
        exit 1
    fi
}

# Recording functions
start_recording() {
    local geometry="$1"
    local type="$2"
    
    # Clean up any leftover temp files
    [[ -f "$TEMP_VIDEO" ]] && rm -f "$TEMP_VIDEO"
    
    # Check if wf-recorder is installed
    if ! command -v wf-recorder >/dev/null 2>&1; then
        notify_recording "Recording Failed" "wf-recorder is not installed" "dialog-error"
        return 1
    fi
    
    # Start new recording using the exact same approach as your original script
    # Use default codec without custom parameters for maximum compatibility
    if [[ -n "$geometry" ]]; then
        wf-recorder -g "$geometry" -f "$TEMP_VIDEO" &
    else
        wf-recorder -f "$TEMP_VIDEO" &
    fi
    
    local pid=$!
    
    # Give wf-recorder more time to initialize
    sleep 1
    
    # Verify wf-recorder is still running
    if ! kill -0 "$pid" 2>/dev/null; then
        # Try to get more info about why it failed
        if [[ -f "$TEMP_VIDEO" ]] && [[ ! -s "$TEMP_VIDEO" ]]; then
            rm -f "$TEMP_VIDEO"
        fi
        notify_recording "Recording Failed" "wf-recorder could not start" "dialog-error"
        return 1
    fi
    
    echo "$pid" > "$PID_FILE"
    echo "$type" > "/tmp/recording_type"
    
    notify_recording "Recording Started" "Press keybind again to stop" "media-record"
}

stop_recording() {
    if ! is_recording; then
        return
    fi
    
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    
    # Stop recording gracefully
    kill -INT "$pid" 2>/dev/null || true
    sleep 2  # Wait for file to be written
    
    # Clean up PID file
    rm -f "$PID_FILE"
    
    # Get recording type
    local rec_type="unknown"
    [[ -f "/tmp/recording_type" ]] && rec_type=$(cat "/tmp/recording_type")
    rm -f "/tmp/recording_type"
    
    # Check if temp video exists and has content
    if [[ ! -f "$TEMP_VIDEO" ]] || [[ ! -s "$TEMP_VIDEO" ]]; then
        notify_recording "Recording Failed" "No video file created" "dialog-error"
        return
    fi
    
    # Convert to GIF
    local gif_file="$GIF_DIR/recording_${rec_type}_$(timestamp).gif"
    
    notify_recording "Processing" "Converting to GIF..." "emblem-synchronizing"
    
    # Get video dimensions and framerate for optimal quality scaling
    local video_info
    video_info=$(ffprobe -v quiet -print_format json -show_streams "$TEMP_VIDEO" 2>/dev/null)
    local width height fps
    width=$(echo "$video_info" | jq -r '.streams[0].width // 1920' 2>/dev/null || echo "1920")
    height=$(echo "$video_info" | jq -r '.streams[0].height // 1080' 2>/dev/null || echo "1080")
    fps=$(echo "$video_info" | jq -r '.streams[0].r_frame_rate // "30/1"' 2>/dev/null || echo "30/1")
    
    # Calculate fps as decimal
    fps_decimal=$(echo "$fps" | awk -F/ '{if($2) print $1/$2; else print $1}' 2>/dev/null || echo "30")
    
    # Use adaptive framerate: limit to 25fps for smooth GIFs but preserve lower framerates
    target_fps=$(echo "$fps_decimal" | awk '{if($1 > 25) print 25; else print int($1)}')
    
    # Calculate optimal scale (max 1920 width for quality, but maintain aspect ratio)
    local scale_filter="scale=min(1920\\,iw):-1:flags=lanczos"
    if [[ $width -le 1920 ]]; then
        scale_filter="scale=${width}:${height}:flags=lanczos"
    fi
    
    # Enhanced GIF conversion with maximum quality settings
    # Generate optimized palette with full color range
    ffmpeg -i "$TEMP_VIDEO" \
           -vf "fps=${target_fps},${scale_filter},palettegen=max_colors=256:reserve_transparent=0:stats_mode=diff" \
           -y "/tmp/palette.png" 2>/dev/null && \
    
    # Convert to GIF with highest quality settings
    ffmpeg -i "$TEMP_VIDEO" -i "/tmp/palette.png" \
           -filter_complex "fps=${target_fps},${scale_filter}[x];[x][1:v]paletteuse=dither=sierra2_4a:bayer_scale=0:diff_mode=rectangle:new=1" \
           -loop 0 \
           -y "$gif_file" 2>/dev/null && {
        
        # Clean up temp files including the original video
        rm -f "$TEMP_VIDEO" "/tmp/palette.png"
        
        # Copy GIF to clipboard as file path
        echo -n "$gif_file" | wl-copy
        
        # Get GIF file size for notification
        local gif_size
        gif_size=$(stat -c%s "$gif_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
        
        notify_recording "GIF Created" "Saved as $(basename "$gif_file") (${gif_size})" "video-x-generic"
    } || {
        notify_recording "Conversion Failed" "Failed to create GIF" "dialog-error"
        rm -f "$TEMP_VIDEO" "/tmp/palette.png"
        exit 1
    }
}

record_fullscreen() {
    # Debug: Check recording status
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid
        existing_pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$existing_pid" ]] && ps -p "$existing_pid" >/dev/null 2>&1; then
            # Recording is active, stop it
            stop_recording
            return
        else
            # Stale PID, clean it up
            rm -f "$PID_FILE"
        fi
    fi
    
    # Kill any existing slurp processes first (cleanup)
    kill_existing_slurp
    
    start_recording "" "fullscreen"
}

record_region() {
    # Debug: Check recording status
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid
        existing_pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$existing_pid" ]] && ps -p "$existing_pid" >/dev/null 2>&1; then
            # Recording is active, stop it
            stop_recording
            return
        else
            # Stale PID, clean it up
            rm -f "$PID_FILE"
        fi
    fi
    
    # Kill any existing slurp processes first
    kill_existing_slurp
    
    local selection
    if ! selection=$(slurp 2>/dev/null); then
        # User cancelled - silent exit
        exit 0
    fi
    
    # Validate selection size for recording
    if ! validate_selection_size "$selection"; then
        notify_recording "Selection Too Small" "Minimum size: 10×10 pixels" "dialog-error"
        exit 1
    fi
    
    start_recording "$selection" "region"
}

record_window() {
    # Debug: Check recording status
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid
        existing_pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$existing_pid" ]] && ps -p "$existing_pid" >/dev/null 2>&1; then
            # Recording is active, stop it
            stop_recording
            return
        else
            # Stale PID, clean it up
            rm -f "$PID_FILE"
        fi
    fi
    
    # Kill any existing slurp processes first
    kill_existing_slurp
    
    local geometry
    if ! geometry=$(get_active_window_geometry); then
        notify_recording "No Active Window" "No window found" "dialog-error"
        exit 1
    fi
    
    start_recording "$geometry" "window"
}

# Main switch
case "${1:-}" in
    "screenshot-region")    screenshot_region ;;
    "screenshot-window")    screenshot_window ;;
    "screenshot-fullscreen") screenshot_fullscreen ;;
    "record-region")        record_region ;;
    "record-window")        record_window ;;
    "record-fullscreen")    record_fullscreen ;;
    "edit-last")            
        # Quick edit the last screenshot
        if [[ -f "/tmp/last_screenshot.txt" ]]; then
            last_file=$(cat "/tmp/last_screenshot.txt")
            if [[ -f "$last_file" ]]; then
                swappy -f "$last_file" &
            else
                notify_screenshot_failed "No Screenshot Found" "No recent screenshot available"
            fi
        else
            notify_screenshot_failed "No Screenshot Found" "No recent screenshot available"
        fi
        ;;
    *)
        echo "Usage: $0 {screenshot-region|screenshot-window|screenshot-fullscreen|record-region|record-window|record-fullscreen|edit-last}"
        echo ""
        echo "Features:"
        echo "  • Single instance protection"
        echo "  • Maximum quality screenshots (PNG level 9)"
        echo "  • High-quality GIF recordings"
        echo "  • Minimum selection size: 10×10 pixels"
        echo ""
        echo "Keybindings:"
        echo "  Super + S         : Screenshot region"
        echo "  Super + Shift + S : Screenshot window"  
        echo "  Print             : Screenshot fullscreen"
        echo "  Super + R         : Record/GIF region (toggle)"
        echo "  Super + Shift + R : Record/GIF window (toggle)"
        echo "  Super + F         : Record/GIF fullscreen (toggle)"
        echo "  Super + E         : Edit last screenshot"
        exit 1
        ;;
esac