#!/usr/bin/env bash
#
# Usage:
#   hid_battery.sh            print one JSON line and exit (handy for testing)
#   hid_battery.sh --watch    stay resident: print on every power_supply udev
#                             event (charging, unplug, re-pair) and at least
#                             once per POLL_INTERVAL as a fallback.

POLL_INTERVAL=60   # seconds; upper bound between refreshes
READ_TIMEOUT=5     # how often the event wait unblocks, so signals land fast
SETTLE=0.5         # give sysfs a moment to catch up after a uevent

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

emit() {
    TEXT="| TOTEM"
    TOOLTIP=""
    CLASS="discharging"

    add_half "$LEFT"  "L" "Left"
    add_half "$RIGHT" "R" "Right"

    # Hide module if neither half is connected
    if [[ "$TEXT" == "| TOTEM" ]]; then
        echo ""
        return
    fi

    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$TEXT" "$TOOLTIP" "$CLASS"
}

if [[ "$1" != "--watch" ]]; then
    emit
    exit 0
fi

# --- watch mode -------------------------------------------------------------

# Line-buffer udevadm so events reach us as they happen, not one pipe block at
# a time.
if command -v stdbuf >/dev/null 2>&1; then
    monitor=(stdbuf -oL udevadm monitor --udev --subsystem-match=power_supply)
else
    monitor=(udevadm monitor --udev --subsystem-match=power_supply)
fi

exec 3< <("${monitor[@]}" 2>/dev/null)
monitor_pid=$!
trap 'kill "$monitor_pid" 2>/dev/null; exit 0' EXIT TERM INT

emit
last=$SECONDS

# `read` swallows signals until it returns, so wait in short hops: the trap
# above then runs within READ_TIMEOUT instead of leaving udevadm behind.
while :; do
    read -r -t "$READ_TIMEOUT" -u 3 line
    status=$?

    if (( status == 0 )); then
        # Skip udevadm's banner lines and anything not about a battery node.
        [[ "$line" == *"(power_supply)"* ]] || continue
        sleep "$SETTLE"
        emit
        last=$SECONDS
        # A state change usually arrives as a burst of uevents; swallow the
        # rest so we redraw once instead of five times.
        while read -r -t 0.2 -u 3 _; do :; done
    elif (( status > 128 )); then
        if (( SECONDS - last >= POLL_INTERVAL )); then
            emit      # nothing happened for a while: fallback refresh
            last=$SECONDS
        fi
    else
        exit 0        # monitor died — let waybar restart us
    fi
done
