pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Notifications for USB devices plugged in or pulled out, from udev's own
// events (after its rules ran, so names and ID_INTEGRATION are filled in).
// Only external ports count: the webcam, fingerprint reader and Bluetooth
// chip are internal, and the Bluetooth chip re-enumerates on every resume
// from hibernate. Hubs are skipped; the devices behind them report
// themselves. Events are collected for a moment so a dock or hub plugged in
// gives one notification, and a device that drops and comes back within
// that time (a USB reset on resume) gives none. The connect and disconnect
// sounds stay quiet under do not disturb.
Singleton {
    id: root

    readonly property bool watching: monitor.running

    // Recently woken: devices can take a second or more to come back.
    property bool _waking: false
    property var _pending: []
    // DEVPATH -> { name, kind, icon } for the external devices seen arrive,
    // so their removal can be named even if udev's remove event isn't.
    property var _known: ({})

    readonly property var _kinds: [
        { cls: "08", kind: "Storage", icon: "drive-removable-media" },
        { cls: "06", kind: "Phone or camera", icon: "phone" },
        { cls: "0e", kind: "Webcam", icon: "camera-web" },
        { cls: "01", kind: "Audio device", icon: "audio-headset" },
        { cls: "07", kind: "Printer", icon: "printer" },
        { cls: "030101", kind: "Keyboard", icon: "input-keyboard" },
        { cls: "030102", kind: "Mouse", icon: "input-mouse" },
        { cls: "03", kind: "Input device", icon: "input-keyboard" }
    ]

    function _decode(s) {
        return (s ?? "").replace(/\\x([0-9a-f]{2})/gi, (_, h) => String.fromCharCode(parseInt(h, 16))).replace(/_/g, " ").trim();
    }

    function _name(p) {
        let model = _decode(p.ID_MODEL_ENC);
        if (!model || model.toLowerCase() === (p.ID_MODEL_ID ?? "").toLowerCase())
            model = p.ID_MODEL_FROM_DATABASE ?? "";
        // "SanDisk Corp." -> "SanDisk"; the string the device reports is
        // often a serial number, so the database comes first here.
        let vendor = p.ID_VENDOR_FROM_DATABASE || _decode(p.ID_VENDOR_ENC);
        let prev;
        do {
            prev = vendor;
            vendor = vendor.replace(/,?\s+(Inc|Corp|Corporation|Co|Ltd|LLC|GmbH|AG|S\.A|Limited|Technology|Technologies)\.?$/i, "").trim();
        } while (vendor !== prev);
        if (!model)
            return vendor || "USB device";
        if (!vendor || model.toLowerCase().startsWith(vendor.split(" ")[0].toLowerCase()))
            return model;
        return `${vendor} ${model}`;
    }

    function _kind(p) {
        const ifaces = (p.ID_USB_INTERFACES ?? "").split(":").filter(s => s);
        // A device with several interfaces gets the first kind listed.
        return _kinds.find(k => ifaces.some(i => i.startsWith(k.cls))) ?? { kind: "USB device", icon: "media-removable" };
    }

    function _event(p) {
        if (p.DEVTYPE !== "usb_device" || (p.ACTION !== "add" && p.ACTION !== "remove"))
            return;
        if (/(^|:)09/.test(p.ID_USB_INTERFACES ?? "") || (p.TYPE ?? "").startsWith("9/"))
            return;
        let dev;
        if (p.ACTION === "add") {
            if (p.ID_INTEGRATION === "internal")
                return;
            const k = _kind(p);
            dev = { name: _name(p), kind: k.kind, icon: k.icon };
            const known = Object.assign({}, _known);
            known[p.DEVPATH] = dev;
            _known = known;
        } else {
            // Without its add seen or udev saying so, it may be internal.
            dev = _known[p.DEVPATH];
            if (!dev && p.ID_INTEGRATION !== "external")
                return;
            if (!dev) {
                const k = _kind(p);
                dev = { name: _name(p), kind: k.kind, icon: k.icon };
            }
        }
        _pending = _pending.concat([Object.assign({ action: p.ACTION, key: p.DEVPATH }, dev)]);
        flush.interval = _waking || Sleep.sleeping ? 3000 : 300;
        flush.restart();
    }

    function _flush() {
        // A remove and an add of the same device cancel out.
        const events = _pending.filter(e => !_pending.some(o => o.key === e.key && o.action !== e.action));
        _pending = [];
        for (const action of ["remove", "add"]) {
            const list = events.filter(e => e.action === action);
            if (action === "remove") {
                const known = Object.assign({}, _known);
                list.forEach(e => delete known[e.key]);
                _known = known;
            }
            if (list.length > 0)
                _notify(action, list);
        }
    }

    function _notify(action, list) {
        const verb = action === "add" ? "connected" : "disconnected";
        const one = list.length === 1;
        const title = one ? `${list[0].name} ${verb}` : `${list.length} USB devices ${verb}`;
        const body = one ? list[0].kind : list.map(e => e.name).join(", ");
        // Notification bodies are markup and device names are the device's own.
        const escaped = body.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        Quickshell.execDetached(["notify-send", "-a", "USB", "-u", "low", "-t", "4000", "-i", one ? list[0].icon : "media-removable",
            "-h", `string:x-dunst-stack-tag:usb-${one ? list[0].key : "many"}`, title, escaped]);
        if (!Notifs.dnd)
            Quickshell.execDetached(["paplay", "--property=media.role=event", `/usr/share/sounds/freedesktop/stereo/device-${action === "add" ? "added" : "removed"}.oga`]);
    }

    Connections {
        target: Sleep

        function onSleepingChanged() {
            if (Sleep.sleeping)
                root._waking = true;
        }

        function onWoke() {
            root._waking = true;
            waking.restart();
        }
    }

    Timer {
        id: waking
        interval: 10000
        onTriggered: root._waking = false
    }

    Timer {
        id: flush
        onTriggered: root._flush()
    }

    Process {
        id: monitor

        running: true
        command: ["udevadm", "monitor", "--udev", "--property", "--subsystem-match=usb/usb_device"]
        stdout: SplitParser {
            // An event is a "UDEV [time] action devpath (usb)" line, then
            // KEY=VALUE lines, then a blank line.
            splitMarker: "\n\n"
            onRead: block => {
                const p = {};
                for (const line of block.split("\n")) {
                    const eq = line.indexOf("=");
                    if (eq > 0)
                        p[line.slice(0, eq)] = line.slice(eq + 1);
                }
                root._event(p);
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: monitor.running = true
    }
}
