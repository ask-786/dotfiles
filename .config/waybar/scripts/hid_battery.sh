#!/usr/bin/env bash

get_icon() {
    local percent="$1" status="$2"

    # While charging, show a plain bolt instead of a battery — the percentage
    # is already spelled out next to it.
    if [[ "$status" == "Charging" ]]; then
        printf '\uf0e7\n'   # nf-fa-bolt
    elif (( percent >= 90 )); then echo "󰁹"
    elif (( percent >= 70 )); then echo "󰂁"
    elif (( percent >= 40 )); then echo "󰁾"
    elif (( percent >= 10 )); then echo "󰁼"
    else echo "󰁺"
    fi
}

# battery-6 is the left half, battery-5 the right (confirmed by charging one
# side and watching which node reports "Charging").
LEFT="/sys/class/power_supply/hid-9486EAD61E2C43D6-battery-6"
RIGHT="/sys/class/power_supply/hid-9486EAD61E2C43D6-battery-5"

TEXT="| TOTEM"
TOOLTIP=""
CLASS="discharging"

add_half() {
    local path="$1" label="$2" name="$3"
    local percent status icon

    [[ -f "$path/capacity" ]] || return

    percent=$(<"$path/capacity")
    status=$(cat "$path/status" 2>/dev/null)

    icon=$(get_icon "$percent" "$status")
    TEXT+=" ${label}:${percent}% ${icon}"

    [[ -n "$TOOLTIP" ]] && TOOLTIP+=" | "
    TOOLTIP+="${name}: ${percent}%"
    if [[ "$status" == "Charging" ]]; then
        TOOLTIP+=" (charging)"
        CLASS="charging"
    elif [[ "$status" == "Full" ]]; then
        TOOLTIP+=" (full)"
    fi
}

add_half "$LEFT"  "L" "Left"
add_half "$RIGHT" "R" "Right"

# Hide module if neither half is connected
if [[ "$TEXT" == "| TOTEM" ]]; then
    echo ""
    exit 0
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$TEXT" "$TOOLTIP" "$CLASS"
