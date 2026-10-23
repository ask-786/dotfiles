#!/bin/sh
# hypridle's suspend timeout: suspend, unless media is playing. Music doesn't
# inhibit idle, and hypridle won't fire the timeout again while still idle,
# so wait for playback to stop and suspend once nothing has played for two
# checks in a row (a track change can briefly report Stopped). Activity runs
# `idle-suspend.sh cancel` from on-resume, which kills the wait.
pidfile="${XDG_RUNTIME_DIR:-/tmp}/idle-suspend.pid"

if [ "$1" = cancel ]; then
    [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null
    rm -f "$pidfile"
    exit 0
fi

playing() { playerctl -a status 2>/dev/null | grep -qx Playing; }

if playing; then
    echo $$ >"$pidfile"
    quiet=0
    while [ "$quiet" -lt 2 ]; do
        sleep 30
        if playing; then quiet=0; else quiet=$((quiet + 1)); fi
    done
    rm -f "$pidfile"
fi
exec systemctl suspend
