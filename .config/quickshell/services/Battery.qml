pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    readonly property var dev: UPower.displayDevice

    readonly property bool available: dev?.isLaptopBattery ?? false
    readonly property real fraction: dev && dev.energyCapacity > 0 ? dev.energy / dev.energyCapacity : 0
    readonly property int percent: Math.round(fraction * 100)
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
    readonly property bool full: dev?.state === UPowerDeviceState.FullyCharged
    readonly property bool plugged: !UPower.onBattery
    readonly property bool low: percent <= 15 && !plugged

    readonly property int seconds: charging ? dev?.timeToFull ?? 0 : dev?.timeToEmpty ?? 0
    readonly property int _h: Math.floor(seconds / 3600)
    readonly property int _m: Math.floor(seconds % 3600 / 60)
    readonly property string timeText: seconds <= 0 ? "" : _h > 0 ? `${_h}h ${_m}m` : `${_m}m`

    readonly property string status: {
        if (charging)
            return timeText ? `${timeText} to full` : "Charging";
        if (plugged)
            return full ? "Fully charged" : "Plugged in";
        return timeText ? `${timeText} left` : "On battery";
    }

    readonly property string icon: charging ? Icons.batteryCharging
                                 : plugged ? Icons.plug
                                 : low ? Icons.batteryAlert
                                 : Icons.level(Icons.batteryLevels, fraction)

    // Low-battery notifications, which (unlike the bar and its blink) show
    // over fullscreen windows. Each threshold fires once per discharge;
    // plugging in resets it and closes the popup.
    readonly property var _warnings: [
        { at: 5, urgency: "critical", title: "Battery critical", hint: "plug in now", sound: "dialog-error" },
        { at: 15, urgency: "normal", title: "Battery low", hint: "", sound: "dialog-warning" }
    ]
    readonly property bool _live: available && (dev?.ready ?? false) && dev.energyCapacity > 0
    property int _warned: 101
    property string _notifId: ""
    property bool _initialized: false

    onPercentChanged: _checkLow()
    onPluggedChanged: {
        _checkLow();
        _onPluggedChanged();
    }
    on_LiveChanged: {
        _checkLow();
        if (_live && !_initialized)
            _initialized = true;
    }
    onFullChanged: _onFullChanged()

    function _checkLow() {
        if (!_live)
            return;
        if (plugged) {
            _warned = 101;
            if (_notifId)
                Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                    "--object-path", "/org/freedesktop/Notifications",
                    "--method", "org.freedesktop.Notifications.CloseNotification", _notifId]);
            _notifId = "";
            return;
        }
        const w = _warnings.find(w => percent <= w.at);
        if (!w || w.at >= _warned)
            return;
        _warned = w.at;
        const body = [`${percent}%`, timeText ? `${timeText} left` : "", w.hint].filter(s => s).join(" · ");
        notify.command = ["notify-send", "-p", "-a", "Battery", "-u", w.urgency,
            "-i", w.urgency === "critical" ? "battery-caution" : "battery-low",
            "-h", "string:x-dunst-stack-tag:battery", w.title, body];
        notify.running = true;
        Quickshell.execDetached(["paplay", "--property=media.role=event", `/usr/share/sounds/freedesktop/stereo/${w.sound}.oga`]);
    }

    function _onPluggedChanged() {
        if (!_live || !_initialized)
            return;
        const snd = plugged ? "power-plug" : "power-unplug";
        Quickshell.execDetached(["paplay", "--property=media.role=event",
            `/usr/share/sounds/freedesktop/stereo/${snd}.oga`]);
    }

    function _onFullChanged() {
        if (!_live || !_initialized || !full)
            return;
        Quickshell.execDetached(["paplay", "--property=media.role=event",
            "/usr/share/sounds/freedesktop/stereo/complete.oga"]);
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", "low",
            "-i", "battery-full-charged", "Battery fully charged", `${percent}%`]);
    }

    Process {
        id: notify
        stdout: StdioCollector {
            onStreamFinished: root._notifId = text.trim()
        }
    }
}
