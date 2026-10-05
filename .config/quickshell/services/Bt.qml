pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs

Singleton {
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

    function toggle() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
