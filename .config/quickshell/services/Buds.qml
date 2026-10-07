pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Galaxy Buds left/right/case battery via GalaxyBudsClient's D-Bus service.
// Plain Bluetooth only reports one level for the pair; the per-bud and case
// levels come over Samsung's own channel, which the client holds (only one
// app can), so we read its properties instead of talking to the buds.
Singleton {
    id: root

    readonly property string service: "me.timschneeberger.GalaxyBudsClient"
    readonly property string objectPath: "/me/timschneeberger/galaxybudsclient/device"

    property string name: ""
    property string address: ""
    property int left: -1
    property int right: -1
    property int caseLevel: -1 // last valid reading; the buds send 101 with the lid closed
    property string wearLeft: ""
    property string wearRight: ""

    // Only while the client is running and the buds are actually connected,
    // so a stale reading never shows after they drop.
    property bool _reported: false
    readonly property bool present: _reported && Bt.connected.some(d => d.address === address)
    // The case only reports while a bud sits in it with the lid open.
    readonly property bool caseFresh: wearLeft === "Case" || wearRight === "Case"

    function refresh() {
        proc.running = true;
    }

    // A second instance hands off to the running one (bringing its window
    // to the front) and exits, so this both starts and raises the app.
    function openApp() {
        Quickshell.execDetached(["galaxybudsclient"]);
    }

    // Find my earbuds: they beep until stopped. The client doesn't publish
    // whether it's searching, so this tracks the state from our side only.
    property bool finding: false

    function toggleFind() {
        finding = !finding;
        Quickshell.execDetached(["busctl", "--user", "call", service, "/me/timschneeberger/galaxybudsclient",
            service + ".Application", "ExecuteAction", "s", finding ? "StartFind" : "StopFind"]);
    }

    onPresentChanged: if (!present) finding = false

    // Only the devices panel shows the buds: check on open, then keep in
    // sync only while it stays open.
    readonly property bool watching: Panels.devices

    onWatchingChanged: if (watching) refresh()
    Component.onCompleted: refresh()

    Timer {
        interval: 3000
        running: root.watching
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        command: ["busctl", "--user", "--json=short", "call", root.service, root.objectPath,
            "org.freedesktop.DBus.Properties", "GetAll", "s", root.service + ".Device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p;
                try {
                    p = JSON.parse(text).data[0];
                } catch (e) {
                    root._reported = false; // client not running or buds not connected
                    return;
                }
                const v = k => p[k]?.data;
                root.name = v("Name") ?? "";
                root.address = v("Address") ?? "";
                root.left = v("BatteryLeft") ?? -1;
                root.right = v("BatteryRight") ?? -1;
                const c = v("BatteryCase") ?? -1;
                if (c > 0 && c <= 100)
                    root.caseLevel = c;
                root.wearLeft = v("WearStateLeft") ?? "";
                root.wearRight = v("WearStateRight") ?? "";
                root._reported = root.left >= 0 || root.right >= 0;
            }
        }
    }
}
