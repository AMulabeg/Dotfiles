#!/bin/bash

INTERNAL="eDP-1"

# get the name of any connected monitor that isn't the internal display
EXTERNAL=$(hyprctl monitors | awk '/Monitor/ {print $2}' | grep -v "$INTERNAL")

if [ "$1" = "close" ]; then
    if [ -n "$EXTERNAL" ]; then
        hyprctl keyword monitor "$INTERNAL,disable"
        hyprctl keyword monitor "$EXTERNAL,preferred,auto,2"
    fi
elif [ "$1" = "open" ]; then
    hyprctl keyword monitor "$INTERNAL,preferred,auto,1"

    if [ -n "$EXTERNAL" ]; then
        hyprctl keyword monitor "$EXTERNAL,preferred,auto,2"
    fi
fi
