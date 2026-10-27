pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Turns other playback down while an alert sound plays (an app's
// notification sound, a reminder chime, the adhan) and back up once it's
// done. WirePlumber does it (wireplumber.conf.d/50-ducking.conf): media
// plays through a Multimedia loopback sink and Notification streams through
// another, and while one of those plays it turns the Multimedia one down.
// The switch on the Settings page is that duck level, saved by WirePlumber;
// 1.0 is off (it takes a float, and refuses "1").
Singleton {
    id: root

    // Ducked media plays at this fraction of its level, on wpctl's scale;
    // WirePlumber's duck level is linear, its cube.
    readonly property real level: 0.6
    property bool enabled: true

    function setEnabled(on) {
        enabled = on;
        Quickshell.execDetached(["wpctl", "settings", "--save", "linking.role-based.duck-level", on ? Math.pow(level, 3).toFixed(3) : "1.0"]);
    }

    Process {
        running: true
        command: ["wpctl", "settings", "linking.role-based.duck-level"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text.replace(/^Value:/, ""));
                if (!isNaN(v))
                    root.enabled = v < 1;
            }
        }
    }
}
