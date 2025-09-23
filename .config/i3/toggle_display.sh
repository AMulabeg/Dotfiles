#!/bin/bash
if xrandr | grep -q "DP-1-3 connected"; then
    xrandr --output eDP-1 --off --output DP-1-3 --auto --primary
elif xrandr | grep -q "DP3 connected"; then
    xrandr --output eDP1 --off --output DP3 --auto --primary

else
    xrandr --output eDP0 --auto --output DP-1-3 --off
fi

