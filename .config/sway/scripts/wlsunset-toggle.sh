#!/usr/bin/bash
if pidof wlsunset; then
   killall -9 wlsunset
else
   wlsunset #location here
fi
