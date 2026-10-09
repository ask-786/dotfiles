#!/bin/sh
# hypridle's lock_cmd: Quickshell's lock screen, or hyprlock if Quickshell
# isn't running, its config is broken or its lock doesn't come up. The lock
# takes a moment (it screenshots first), so wait up to ~3s for the
# compositor to confirm it; logind only delays suspend for 5s.
if [ "$(qs ipc call lock lock 2>/dev/null)" = locking ]; then
    i=0
    while [ "$i" -lt 20 ]; do
        case "$(qs ipc call lock state 2>/dev/null)" in
            locked) exit 0 ;;
            locking) ;;
            *) break ;;
        esac
        sleep 0.1
        i=$((i + 1))
    done
fi
pidof hyprlock >/dev/null || exec hyprlock
