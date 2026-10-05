pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property bool bluetooth: sink?.properties?.["device.api"] === "bluez5"

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && n.audio && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && n.audio && !n.isStream)

    // The form factor lives on the pipewire device, which nodes don't expose;
    // bluetooth sinks are nearly always headsets.
    readonly property string icon: muted ? Icons.volumeOff
                                 : bluetooth ? Icons.headset
                                 : Icons.level(Icons.volumeLevels, volume)

    // Volume and mute go through wpctl, like the volume keys, instead of
    // Quickshell's node setters: WirePlumber then saves the level on the
    // device route. Set directly, Bluetooth headsets (Galaxy Buds) snap back
    // to the saved route level on the next volume change.
    function setVolume(v) {
        sinkCtl.set(v);
    }

    function stepVolume(steps) {
        sinkCtl.step(steps * 5);
    }

    function toggleMute() {
        sinkCtl.toggleMute();
    }

    function setMicVolume(v) {
        sourceCtl.set(v);
    }

    function toggleMic() {
        sourceCtl.toggleMute();
    }

    function nodeName(node) {
        return node?.description || node?.nickname || node?.name || "Unknown";
    }

    // Volume and mute are only live while something tracks the node.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }

    VolumeCtl {
        id: sinkCtl
        node: root.sink
    }

    VolumeCtl {
        id: sourceCtl
        node: root.source
    }

    // One wpctl at a time per node; slider drags and fast scrolls collapse
    // into the latest absolute level or the summed relative step.
    component VolumeCtl: Process {
        property var node: null
        property real target: -1 // absolute 0..1, or -1
        property int delta: 0 // relative %, used when no target

        function set(v) {
            if (!node?.audio)
                return;
            target = Math.max(0, Math.min(1, v));
            delta = 0;
            unmute();
            next();
        }

        function step(percent) {
            if (!node?.audio)
                return;
            if (target >= 0)
                target = Math.max(0, Math.min(1, target + percent / 100));
            else
                delta += percent;
            unmute();
            next();
        }

        function toggleMute() {
            if (node?.audio)
                Quickshell.execDetached(["wpctl", "set-mute", `${node.id}`, "toggle"]);
        }

        function unmute() {
            if (node.audio.muted)
                Quickshell.execDetached(["wpctl", "set-mute", `${node.id}`, "0"]);
        }

        function next() {
            if (running || !node)
                return;
            if (target >= 0)
                command = ["wpctl", "set-volume", `${node.id}`, target.toFixed(3)];
            else if (delta !== 0)
                command = ["wpctl", "set-volume", "-l", "1", `${node.id}`, `${Math.abs(delta)}%${delta > 0 ? "+" : "-"}`];
            else
                return;
            target = -1;
            delta = 0;
            running = true;
        }

        onExited: next()
    }
}
