pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Volume of alert sounds: app notification sounds, our reminder, battery
// and device chimes, the adhan. They all play with media.role Notification
// (paplay's "event" maps onto it), and WirePlumber applies one saved level
// to every such stream. It saves the level a new stream asks for, so
// setting one plays a preview chime at that level, which is also how you
// hear it. The level is read back from WirePlumber's state file, so changes
// made elsewhere (pavucontrol) show too.
Singleton {
    id: root

    // 0..1 on the wpctl scale; 1 until WirePlumber has saved anything.
    property real volume: 1
    property bool muted: false
    // Level the preview chime plays at, or -1.
    property real target: -1
    property bool _replay: false

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/wireplumber/stream-properties`
    readonly property string sound: "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"

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

    // Slider drags and scrolls settle before the chime plays; a change while
    // it plays restarts it at the new level.
    Timer {
        id: settle
        interval: 250
        onTriggered: {
            if (chime.running) {
                root._replay = true;
                chime.running = false;
            } else {
                chime.running = true;
            }
        }
    }

    // WirePlumber leaves a stream that sets its own volume alone (no jump
    // from the old level) and saves that volume for the role. paplay's
    // volume is on the same scale as wpctl's, 65536 = 100%. The tag keeps
    // Ducking from lowering media for it.
    Process {
        id: chime
        command: ["paplay", "--property=media.role=event", "--property=quickshell.preview=alert-volume", `--volume=${Math.round(Math.max(root.target, 0) * 65536)}`, root.sound]
        onExited: {
            if (root._replay) {
                root._replay = false;
                running = true;
                return;
            }
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
