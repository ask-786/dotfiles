pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false

    // Skip nameless devices that only advertise their address.
    readonly property var devices: (adapter?.devices.values ?? [])
        .filter(d => d.name && d.name.replace(/-/g, ":") !== d.address)
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    readonly property var connected: devices.filter(d => d.connected)

    readonly property string icon: !enabled ? Icons.bluetoothOff
                                 : connected.length ? Icons.bluetoothConnected
                                 : Icons.bluetooth

    readonly property string label: !enabled ? "Off"
                                  : connected.length === 1 ? connected[0].name
                                  : connected.length > 1 ? `${connected.length} devices`
                                  : "On"

    function battery(device) {
        if (!device?.batteryAvailable)
            return -1;
        const b = device.battery;
        return Math.round(b > 1 ? b : b * 100);
    }

    readonly property int lowAt: 20

    function isLow(device) {
        const b = battery(device);
        return b >= 0 && b <= lowAt;
    }

    // Low-battery notifications per connected device, like Battery.qml's.
    // Each threshold fires once per device; the level has to climb back
    // above lowAt + 10 to re-arm it, so a reading flapping around the
    // threshold or a reconnect doesn't repeat the alert.
    readonly property var _warnings: [
        { at: 10, urgency: "critical", title: "battery critical", icon: "battery-caution", sound: "dialog-error" },
        { at: lowAt, urgency: "normal", title: "battery low", icon: "battery-low", sound: "dialog-warning" }
    ]
    property var _warned: ({}) // address -> threshold already alerted

    function _checkLow(device, level) {
        if (level < 0)
            return;
        const addr = device.address;
        if (level > lowAt + 10) {
            delete _warned[addr];
            return;
        }
        const w = _warnings.find(w => level <= w.at);
        if (!w || w.at >= (_warned[addr] ?? 101))
            return;
        _warned[addr] = w.at;
        Quickshell.execDetached(["notify-send", "-a", "Bluetooth", "-u", w.urgency, "-i", w.icon,
            "-h", `string:x-dunst-stack-tag:bt-battery-${addr}`, `${device.name} ${w.title}`, `${level}%`]);
        Quickshell.execDetached(["paplay", `/usr/share/sounds/freedesktop/stereo/${w.sound}.oga`]);
    }

    Instantiator {
        model: ScriptModel {
            values: root.connected
        }

        QtObject {
            required property var modelData
            readonly property int level: root.battery(modelData)

            onLevelChanged: root._checkLow(modelData, level)
            Component.onCompleted: root._checkLow(modelData, level)
        }
    }

    function toggle() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
