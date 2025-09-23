#!/usr/bin/bash
if pidof wlsunset; then
   killall -9 wlsunset
else
   wlsunset -l 52.48 -L 13.43
fi
