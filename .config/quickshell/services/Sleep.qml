pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tracks system suspend through logind's PrepareForSleep. Qt timers run on
// the monotonic clock, which stops while suspended, so a SystemClock (or any
// Timer) armed before sleep fires late by however long it had left: the
// clocks showed the pre-suspend time for up to a minute after waking. Bind
// `enabled: !Sleep.sleeping` on a SystemClock to make it re-read the time on
// wake; services with their own timers re-check on `woke`.
Singleton {
    id: root

    property bool sleeping: false

    signal woke

    Process {
        id: monitor

        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/\.PrepareForSleep \((true|false),\)/);
                if (!m)
                    return;
                root.sleeping = m[1] === "true";
                if (!root.sleeping)
                    root.woke();
            }
        }
        onExited: {
            root.sleeping = false;
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: monitor.running = true
    }
}
