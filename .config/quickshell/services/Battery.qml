pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

Singleton {
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
    readonly property string timeText: seconds <= 0 ? "" : _h > 0 ? `${_h} h ${_m} min` : `${_m} min`

    readonly property string status: {
        if (charging)
            return timeText ? `${timeText} until full` : "Charging";
        if (plugged)
            return full ? "Fully charged" : "Plugged in";
        return timeText ? `${timeText} left` : "On battery";
    }

    readonly property string icon: charging ? Icons.batteryCharging
                                 : plugged ? Icons.plug
                                 : low ? Icons.batteryAlert
                                 : Icons.level(Icons.batteryLevels, fraction)
}
