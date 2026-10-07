pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Small toggles backed by external tools: night light (hyprsunset),
// do-not-disturb (Notifs), caffeine (systemd idle inhibitor), power profile.
Singleton {
    id: root

    property bool nightLight: false
    readonly property bool dnd: Notifs.dnd
    property bool caffeine: false

    readonly property int nightTemperature: 4500

    readonly property var profiles: PowerProfiles.hasPerformanceProfile
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]
    readonly property string profileName: ["Power saver", "Balanced", "Performance"][PowerProfiles.profile] ?? "Unknown"

    function cycleProfile() {
        const i = profiles.indexOf(PowerProfiles.profile);
        PowerProfiles.profile = profiles[(i + 1) % profiles.length];
    }

    // Note: hyprsunset's own schedule (hyprsunset.conf) wins at the next
    // profile boundary. `identity` alone keeps reporting the old temperature
    // (refresh would flip the tile back on), so set a neutral one first.
    function toggleNightLight() {
        run(nightLight ? ["sh", "-c", "hyprctl hyprsunset temperature 6500 && hyprctl hyprsunset identity"]
                       : ["hyprctl", "hyprsunset", "temperature", String(nightTemperature)]);
        nightLight = !nightLight;
    }

    function toggleDnd() {
        Notifs.dnd = !Notifs.dnd;
    }

    function run(cmd) {
        Quickshell.execDetached(cmd);
        refreshDelay.restart();
    }

    function refresh() {
        sunsetProc.running = true;
    }

    // Only the quick settings tile shows night light: check on open, then
    // keep in sync only while it stays open.
    readonly property bool watching: Panels.open === "quick"

    onWatchingChanged: if (watching) refresh()
    Component.onCompleted: refresh()

    Timer {
        interval: 10000
        running: root.watching
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshDelay
        interval: 500
        onTriggered: root.refresh()
    }

    Process {
        id: sunsetProc
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(text);
                if (!isNaN(t))
                    root.nightLight = t < 6000;
            }
        }
    }

    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Caffeine", "sleep", "infinity"]
    }
}
