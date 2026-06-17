#!/bin/bash

# Helper: get the port name for a connected monitor by model name
get_output() {
    swaymsg -t get_outputs | jq -r --arg model "$1" \
        '.[] | select(.model == $model and .active) | .name' | head -1
}

DELL_4K=$(get_output "DELL U2718Q")
IIYAMA=$(get_output "PL2492H")
LAPTOP=$(get_output "0x573D")

echo "Detected: Dell4K=$DELL_4K, Iiyama=$IIYAMA, Laptop=$LAPTOP"

if [ -n "$DELL_4K" ] && [ -n "$IIYAMA" ]; then
    # Dell 4K + Iiyama dual-monitor setup
    [ -n "$LAPTOP" ] && swaymsg output "$LAPTOP" disable

    # Iiyama on the left, rotated 90 degrees — in portrait it becomes 1080 wide x 1920 tall
    swaymsg output "$IIYAMA" transform 270
    swaymsg output "$IIYAMA" mode 1920x1080@60.000Hz enable
    swaymsg output "$IIYAMA" position 0 0
    swaymsg workspace 4 output "$IIYAMA"
    swaymsg workspace 5 output "$IIYAMA"
    swaymsg workspace 6 output "$IIYAMA"

    # Dell 4K to the right of Iiyama — starts at x=1080 (Iiyama's width after rotation)
    swaymsg output "$DELL_4K" transform normal
    swaymsg output "$DELL_4K" mode 3840x2160@59.996Hz enable
    swaymsg output "$DELL_4K" scale 1.5
    swaymsg output "$DELL_4K" position 1080 0
    swaymsg workspace 1 output "$DELL_4K"
    swaymsg workspace 2 output "$DELL_4K"
    swaymsg workspace 3 output "$DELL_4K"


else
    # Laptop only fallback
    [ -n "$LAPTOP" ] && swaymsg output "$LAPTOP" enable
fi
