#!/usr/bin/env bash

# Sets a random wallpaper on the running hyprpaper. With --boot, starts
# hyprpaper with it instead (autostart). Either way the pick is written to
# $CONF, which the Quickshell lock screen reads to show the same wallpaper.

DIR="$HOME/Pictures/Wallpaper"
CONF="${XDG_CACHE_HOME:-$HOME/.cache}/hypr/hyprpaper.conf"

PIC=$(find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | shuf -n1)

mkdir -p "${CONF%/*}"
if [[ -n $PIC ]]; then
	# Written in place, not replaced: replacing the file would end the lock
	# screen's watch on it.
	cat >"$CONF" <<EOF
splash = false

wallpaper {
    monitor =
    path = $PIC
    fit_mode = cover
}
EOF
elif [[ $1 == --boot ]]; then
	# No wallpapers: fall back to the static one.
	cat "$HOME/.config/hypr/hyprpaper.conf" >"$CONF"
else
	exit 1
fi

if [[ $1 == --boot ]]; then
	exec hyprpaper -c "$CONF"
fi
hyprctl hyprpaper wallpaper ",$PIC"
