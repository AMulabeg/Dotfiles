#!/bin/bash

if pidof waybar; then
  killall -9 waybar
else
  waybar
fi
