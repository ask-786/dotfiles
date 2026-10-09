pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
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
        Quickshell.execDetached(["paplay", "--property=media.role=event", `/usr/share/sounds/freedesktop/stereo/${w.sound}.oga`]);
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

    // Pair, then connect. Pairing leaves the bare link up for a moment, and
    // Quickshell's connect() refuses while it is ("already connected"), so
    // the device dropped to "Paired". BlueZ's own Connect() brings the
    // profiles (HID, audio) up over that link instead.
    property var _pairing: null
    readonly property string connectingPath: connector.running ? connector.path : ""

    function pair(device) {
        device.trusted = true;
        _pairing = device;
        device.pair();
    }

    Connections {
        target: root._pairing

        function onPairingChanged() {
            const dev = root._pairing;
            if (dev.pairing)
                return;
            root._pairing = null;
            if (dev.paired) {
                connector.path = dev.dbusPath;
                connector.running = true;
            }
        }
    }

    Process {
        id: connector

        property string path
        command: ["busctl", "--system", "call", "org.bluez", path, "org.bluez.Device1", "Connect"]
    }

    // Pairing agent. Quickshell.Bluetooth registers none, so pairing a
    // keyboard or phone (passkey or confirmation) used to fail without a
    // word. scripts/bt-agent.py answers BlueZ and asks here; the question
    // shows inline on the Bluetooth page, or as a popup when that's closed.
    property var request: null // see bt-agent.py for the fields
    property string pageScreen: "" // screen showing the Bluetooth page

    function answer(accept, value) {
        if (!request)
            return;
        if (request.kind === "display") {
            // Nothing to reply to; stop pairing instead when refused.
            if (!accept)
                _device(request.device)?.cancelPair();
        } else {
            agent.write(JSON.stringify({ id: request.id, accept, value: value ?? "" }) + "\n");
        }
        request = null;
    }

    function _device(path) {
        return (adapter?.devices.values ?? []).find(d => d.dbusPath === path) ?? null;
    }

    function _onAgent(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg.kind === "clear") {
            if (request?.id === msg.id)
                request = null;
        } else {
            request = msg;
        }
    }

    // A display question gets no reply, so drop it when our Pair() returns.
    Connections {
        target: root.request?.kind === "display" ? root._device(root.request.device) : null

        function onPairingChanged() {
            if (!target.pairing)
                root.request = null;
        }
    }

    Process {
        id: agent

        running: true
        command: ["python3", Quickshell.shellPath("scripts/bt-agent.py")]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root._onAgent(line)
        }
        onExited: code => {
            root.request = null;
            // 3: python-gobject is missing, retrying won't help.
            if (code !== 3)
                restart.start();
        }
    }

    Timer {
        id: restart
        interval: 10000
        onTriggered: agent.running = true
    }
}
