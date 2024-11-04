#!/bin/bash

# Check if DP-3 is connected
if swaymsg -t get_outputs | jq -e '.[] | select(.name == "DP-3" and .active)' >/dev/null; then
    # If DP-3 is connected, disable eDP-1 and enable DP-3
    swaymsg output eDP-1 disable
    swaymsg output DP-3 mode 1920x1080@119.993Hz enable
else
    # If DP-3 is not connected, enable eDP-1 and disable DP-3
    swaymsg output eDP-1 enable
fi

