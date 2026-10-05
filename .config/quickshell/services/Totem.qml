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
    readonly property Half left: Half { path: root.base + "6" }
    readonly property Half right: Half { path: root.base + "5" }

    component Half: QtObject {
        id: half

        required property string path
        property int capacity: -1
        property string status: ""
        readonly property bool present: capacity >= 0

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
