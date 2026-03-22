#!/bin/bash

if pidof quickshell; then
  killall -9 quickshell
else
  quickshell
fi
