pragma Singleton

import QtQuick
import Quickshell
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

    // TEMP: debugging mic level jumping back to 100%. Remove once found.
    property string _lastCaller: ""

    Connections {
        target: root.source?.audio ?? null

        function onVolumesChanged() {
            console.info(`[audio-debug] mic -> ${root.micVolume.toFixed(2)} (last qs call: ${root._lastCaller || "none"}; sink ${root.volume.toFixed(2)}, profile ${root.sink?.properties?.["api.bluez5.profile"] ?? "?"})`);
            root._lastCaller = "";
        }
    }

    Connections {
        target: Pipewire

        function onDefaultAudioSourceChanged() {
            console.info(`[audio-debug] default source changed -> ${root.source?.name} id=${root.source?.id}`);
        }
        function onDefaultAudioSinkChanged() {
            console.info(`[audio-debug] default sink changed -> ${root.sink?.name} id=${root.sink?.id}`);
        }
    }

    function setVolume(v) {
        _lastCaller = `setVolume(${v.toFixed(2)})`;
        if (!sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(v) {
        _lastCaller = `setMicVolume(${v.toFixed(2)})`;
        if (!source?.audio)
            return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMic() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    function nodeName(node) {
        return node?.description || node?.nickname || node?.name || "Unknown";
    }

    // Volume and mute are only live while something tracks the node.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }
}
