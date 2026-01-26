#!/usr/bin/env bash

DIR="$HOME/Pictures/Wallpaper"

PIC=$(find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n1)

hyprctl hyprpaper wallpaper "eDP-1,$PIC"
