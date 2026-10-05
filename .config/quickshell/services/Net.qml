pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import qs

Singleton {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wired: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)
    readonly property var active: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled

    readonly property var networks: (wifiDevice?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    readonly property real signal: active ? strength(active) : 0

    readonly property string icon: wired && !active ? Icons.ethernet
                                 : !wifiEnabled ? Icons.wifiOff
                                 : active ? Icons.level(Icons.wifiLevels, signal)
                                 : Icons.wifiNone

    readonly property string label: active ? active.name
                                  : wired ? "Wired"
                                  : wifiEnabled ? "Not connected" : "Off"

    // NetworkManager reports 0–100; normalise in case it's already 0–1.
    function strength(network) {
        const s = network?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }

    function setScanning(on) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
