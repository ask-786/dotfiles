pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Battery of both halves of the Totem split keyboard, straight from sysfs.
Singleton {
    id: root

    // battery-6 is the left half, battery-5 the right (confirmed by charging
    // one side and watching which node reports "Charging").
    readonly property string base: "/sys/class/power_supply/hid-9486EAD61E2C43D6-battery-"

    readonly property bool present: left.present || right.present
    readonly property Half left: Half { name: "Left"; path: root.base + "6" }
    readonly property Half right: Half { name: "Right"; path: root.base + "5" }

    // Notifications per half: low at 20% and critical at 10% (never while
    // charging; plugging in re-arms them, as does climbing back above 30%),
    // plus "charging" when a cable goes in and "fully charged" when it's
    // done. A half's notifications share a stack tag, so each replaces the last.
    readonly property var _warnings: [
        { at: 10, urgency: "critical", title: "battery critical", icon: "battery-caution", sound: "dialog-error" },
        { at: 20, urgency: "normal", title: "battery low", icon: "battery-low", sound: "dialog-warning" }
    ]

    function _notify(half, urgency, icon, title, sound) {
        Quickshell.execDetached(["notify-send", "-a", "Totem", "-u", urgency, "-i", icon,
            "-h", `string:x-dunst-stack-tag:totem-${half.name}`,
            `Totem ${half.name.toLowerCase()} half ${title}`, `${half.capacity}%`]);
        Quickshell.execDetached(["paplay", `/usr/share/sounds/freedesktop/stereo/${sound}.oga`]);
    }

    function _checkLow(half) {
        // Wait for the status too, or a charging half reads as discharging.
        if (!half.present || half.status === "" || half.status === "Charging" || half.status === "Full")
            return;
        if (half.capacity > 30) {
            half.warned = 101;
            return;
        }
        const w = _warnings.find(w => half.capacity <= w.at);
        if (!w || w.at >= half.warned)
            return;
        half.warned = w.at;
        _notify(half, w.urgency, w.icon, w.title, w.sound);
    }

    // Only real transitions: the first read after a (re)start or reconnect
    // comes from "", so it stays quiet.
    function _statusChanged(half, prev) {
        if (half.status === "Charging") {
            half.warned = 101;
            if (prev === "Discharging" || prev === "Not charging")
                _notify(half, "low", "battery-good-charging", "charging", "power-plug");
        } else if (half.status === "Full" && prev === "Charging") {
            _notify(half, "low", "battery-full-charged", "fully charged", "complete");
        }
        _checkLow(half);
    }

    component Half: QtObject {
        id: half

        required property string name
        required property string path
        property int capacity: -1
        property string status: ""
        readonly property bool present: capacity >= 0
        property int warned: 101 // lowest threshold already alerted
        property string _prevStatus: ""

        onCapacityChanged: root._checkLow(half)
        onStatusChanged: {
            root._statusChanged(half, _prevStatus);
            _prevStatus = status;
        }

        function reload() {
            capFile.reload();
            statusFile.reload();
        }

        property FileView capFile: FileView {
            path: half.path + "/capacity"
            printErrors: false
            onLoaded: half.capacity = Number(text())
            onLoadFailed: half.capacity = -1
        }

        property FileView statusFile: FileView {
            path: half.path + "/status"
            printErrors: false
            onLoaded: half.status = text().trim()
            onLoadFailed: half.status = ""
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            root.left.reload();
            root.right.reload();
        }
    }
}
