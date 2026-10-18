pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Volume of alert sounds: app notification sounds, our reminder, battery
// and device chimes, the adhan. They all play with media.role Notification
// (paplay's "event" maps onto it), and WirePlumber applies one saved level
// to every such stream. It only saves a level set on a playing stream, so
// setting one plays a preview chime and turns that to the new level, which
// is also how you hear it. The level is read back from WirePlumber's state
// file, so changes made elsewhere (pavucontrol) show too.
Singleton {
    id: root

    // 0..1 on the wpctl scale; 1 until WirePlumber has saved anything.
    property real volume: 1
    property bool muted: false
    // Level the preview chime is being turned to, or -1.
    property real target: -1

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/wireplumber/stream-properties`
    readonly property string sound: "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"

    readonly property var streams: (Pipewire.nodes?.values ?? []).filter(n => n.type === PwNodeType.AudioOutStream)
    readonly property var preview: streams.find(n => n.properties?.["quickshell.preview"] === "alert-volume") ?? null

    function setVolume(v) {
        target = Math.max(0, Math.min(1, v));
        volume = target;
        muted = false;
        settle.restart();
    }

    // Replays the chime at the current level.
    function test() {
        setVolume(volume);
    }

    function _apply() {
        if (!preview)
            return;
        Quickshell.execDetached(["wpctl", "set-volume", `${preview.id}`, target.toFixed(3)]);
        if (preview.audio?.muted)
            Quickshell.execDetached(["wpctl", "set-mute", `${preview.id}`, "0"]);
    }

    // The file stores linear channel volumes; wpctl shows their cube root.
    function _parse(text) {
        const line = text.match(/^Output\/Audio:media\.role:Notification=(.*)$/m);
        if (!line) {
            volume = 1;
            muted = false;
            return;
        }
        try {
            const s = JSON.parse(line[1]);
            const ch = s.channelVolumes?.length ? s.channelVolumes : [1];
            volume = Math.cbrt((s.volume ?? 1) * ch.reduce((a, b) => a + b, 0) / ch.length);
            muted = s.mute === true;
        } catch (e) {
            console.warn(`AlertVolume: can't parse ${root.path}: ${e}`);
        }
    }

    // WirePlumber restores the old level on the new stream, maybe after we
    // set ours; set it again whenever it differs.
    onPreviewChanged: if (preview && target >= 0) _apply()

    Connections {
        target: root.preview?.audio ?? null

        function onVolumeChanged() {
            if (root.target >= 0 && Math.abs(root.preview.audio.volume - root.target) > 0.005)
                root._apply();
        }
    }

    // Properties and volume are only live while something tracks the node;
    // the preview can't be told apart until then.
    PwObjectTracker {
        objects: root.streams
    }

    // Slider drags and scrolls settle before the chime plays; a change while
    // it plays goes straight to it.
    Timer {
        id: settle
        interval: 250
        onTriggered: {
            if (root.preview)
                root._apply();
            else if (chime.running)
                restart();
            else
                chime.running = true;
        }
    }

    Process {
        id: chime
        command: ["paplay", "--property=media.role=event", "--property=quickshell.preview=alert-volume", root.sound]
        onExited: {
            root.target = -1;
            file.reload();
        }
    }

    // Only watched while quick settings is open; WirePlumber rewrites the
    // file on every stream volume change, ducking included.
    FileView {
        id: file

        path: root.path
        printErrors: false
        watchChanges: Panels.open === "quick"
        onFileChanged: reload()
        onLoaded: if (root.target < 0) root._parse(text())
    }

    Connections {
        target: Panels

        function onOpenChanged() {
            if (Panels.open === "quick")
                file.reload();
        }
    }
}
