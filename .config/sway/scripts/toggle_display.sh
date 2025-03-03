#!/bin/bash

if swaymsg -t get_outputs | jq -e '.[] | select(.name == "DP-3" and .active)' >/dev/null && \
   swaymsg -t get_outputs | jq -e '.[] | select(.name == "DP-4" and .active)' >/dev/null; then
    # If DP-3 is connected, disable eDP-1 and enable DP-3 and DP-4
    swaymsg output eDP-1 disable

    # Configure DP-4 (left monitor)
    swaymsg output DP-4 position 0 0
    swaymsg output DP-4 mode 1920x1080@119.880Hz enable
    swaymsg workspace 1 output DP-4
    swaymsg workspace 2 output DP-4
    swaymsg workspace 3 output DP-4

    swaymsg output DP-3 position 1920 0
    swaymsg output DP-3 mode 1920x1080@59.940Hz enable
    swaymsg workspace 4 output DP-3
    swaymsg workspace 5 output DP-3
    swaymsg workspace 6 output DP-3

elif swaymsg -t get_outputs | jq -e '.[] | select(.name == "DP-5" and .active)' >/dev/null && \
   swaymsg -t get_outputs | jq -e '.[] | select(.name == "DP-6" and .active)' >/dev/null; then
    swaymsg output eDP-1 disable

    # Configure DP-4 (left monitor)
    swaymsg output DP-6 position 0 0
    swaymsg output DP-6 mode 1920x1080@119.880Hz enable
    swaymsg workspace 1 output DP-6
    swaymsg workspace 2 output DP-6
    swaymsg workspace 3 output DP-6

    # Configure DP-3 (right monitor)
    swaymsg output DP-5 position 1920 0
    swaymsg output DP-5 mode 1920x1080@59.940Hz enable
    swaymsg workspace 4 output DP-5
    swaymsg workspace 5 output DP-5
    swaymsg workspace 6 output DP-5

   
elif swaymsg -t get_outputs | jq -e '.[] | select(.name == "DP-2" and .active)' >/dev/null; then
    swaymsg workspace 4 output eDP-1
    swaymsg workspace 5 output eDP-1
    swaymsg workspace 6 output eDP-1
    swaymsg workspace 1 output DP-2
    swaymsg workspace 2 output DP-2
    swaymsg workspace 3 output DP-2

    swaymsg output eDP-1 disable

elif swaymsg -t get_outputs | jq -e '.[] | select(.name == "DP-4" and .active)' >/dev/null; then
    # If DP-3 is connected, disable eDP-1 and enable DP-3
    swaymsg output eDP-1 disable
    swaymsg output DP-4 mode 1920x1080@119.993Hz enable

else
    # If DP-3 is not connected, enable eDP-1 and disable DP-3
    swaymsg output eDP-1 enable
fi

