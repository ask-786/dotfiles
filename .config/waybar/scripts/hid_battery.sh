#!/usr/bin/env bash

get_icon() {
    local percent="$1"

    if   (( percent >= 90 )); then echo "󰁹"
    elif (( percent >= 70 )); then echo "󰂁"
    elif (( percent >= 40 )); then echo "󰁾"
    elif (( percent >= 10 )); then echo "󰁼"
    else echo "󰁺"
    fi
}

LEFT="/sys/class/power_supply/hid-9486EAD61E2C43D6-battery-5"
RIGHT="/sys/class/power_supply/hid-9486EAD61E2C43D6-battery-6"

TEXT="| TOTEM"
TOOLTIP="TOTEM Keyboard Battery"

if [[ -f "$LEFT/capacity" ]]; then
    LPERCENT=$(<"$LEFT/capacity")
    LICON=$(get_icon "$LPERCENT")
    TEXT+=" L:${LPERCENT}% ${LICON}"
    TOOLTIP+="\nLeft : ${LPERCENT}%"
fi

if [[ -f "$RIGHT/capacity" ]]; then
    RPERCENT=$(<"$RIGHT/capacity")
    RICON=$(get_icon "$RPERCENT")
    TEXT+=" R:${RPERCENT}% ${RICON}"
    TOOLTIP+="\nRight: ${RPERCENT}%"
fi

# Hide module if neither half is connected
if [[ "$TEXT" == "| TOTEM" ]]; then
    echo ""
    exit 0
fi

TOOLTIP="Left: ${LPERCENT}% | Right: ${RPERCENT}%"
printf '{"text":"%s","tooltip":"%s"}\n' "$TEXT" "$TOOLTIP"
