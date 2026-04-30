#!/bin/bash

# Detect HID battery device
BATTERY_PATH=$(find /sys/class/power_supply -maxdepth 1 -name 'hid-*-battery' | head -n 1)

# If no device found
if [ -z "$BATTERY_PATH" ]; then
  echo ""
  exit 0
fi

# Read battery percentage
PERCENT=$(cat "$BATTERY_PATH/capacity" 2>/dev/null)

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
