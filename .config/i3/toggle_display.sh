#!/bin/bash
if xrandr | grep -q "DP-1-3 connected"; then
    xrandr --output eDP-1 --off --output DP-1-3 --auto --primary
else
    xrandr --output eDP-1 --auto --output DP-1-3 --off
fi

