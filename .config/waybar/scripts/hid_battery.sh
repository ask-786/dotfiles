#!/bin/bash

# Try to detect any HID battery device (like your ZMK keyboard)
DEVICE=$(upower -e | grep 'hid_9486EAD61E2C43D6' | head -n 1)

# If no device found, exit with empty output (Waybar hides module)
if [ -z "$DEVICE" ]; then
  echo ""   # or `echo '{}'` if you prefer
  exit 0
fi

# Fetch battery percentage
PERCENT=$(upower -i "$DEVICE" | awk '/percentage:/ {print $2}' | tr -d '%')

# If percentage is empty (device disconnected mid-check)
if [ -z "$PERCENT" ]; then
  echo ""
  exit 0
fi

# Select icon based on percentage
if   [ "$PERCENT" -ge 90 ]; then ICON="󰁹"
elif [ "$PERCENT" -ge 70 ]; then ICON="󰂁"
elif [ "$PERCENT" -ge 40 ]; then ICON="󰁾"
elif [ "$PERCENT" -ge 10 ]; then ICON="󰁼"
else ICON="󰁺"; fi

# Output JSON for Waybar
echo "{\"text\": \"| TOTEM ${PERCENT}% $ICON\", \"tooltip\": \"TOTEM Keyboard Battery: ${PERCENT}%\"}"
