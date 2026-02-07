
#!/bin/bash

INTERNAL="eDP-1"

# find any monitor that is NOT eDP-1 and is connected
EXTERNAL=$(hyprctl monitors | grep "Monitor" | grep -v "$INTERNAL")

if [ "$1" = "close" ]; then
    if [ -n "$EXTERNAL" ]; then
        hyprctl keyword monitor "$INTERNAL,disable"
        hyprctl keyword monitor "DP-7,preferred,auto,2"
    fi
elif [ "$1" = "open" ]; then
    hyprctl keyword monitor "$INTERNAL,preferred,auto,1"
    hyprctl keyword monitor "DP-7,preferred,auto,2"
fi
