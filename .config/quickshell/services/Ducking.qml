pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Turns other playback down while an alert sound plays (an app's
// notification sound, a reminder chime, the adhan) and back up once it's
// done. Alerts are streams with an alert media role: libcanberra and
// notify sounds carry it, and our own players set it (pw-play --media-role
// Notification, paplay --property=media.role=event). Silent notifications
// play nothing, so they don't duck. The switch is on the Settings page, kept
// in ~/.local/state.
Singleton {
    id: root

    property bool enabled: true

    // Ducked streams play at this fraction of their level.
    readonly property real level: 0.6
    readonly property var alertRoles: ["notification", "event", "alarm"]

    readonly property var streams: (Pipewire.nodes?.values ?? []).filter(n => n.type === PwNodeType.AudioOutStream)
    // The alert volume slider's preview chime is left out, so media doesn't
    // dip on every drag.
    readonly property bool alerting: streams.some(n => isAlert(n) && n.properties["quickshell.preview"] === undefined)
    readonly property bool ducked: Object.keys(saved).length > 0

    // Node id → { volume, ducked } for each stream turned down.
    property var saved: ({})
    // Node id → { volume, at } for streams just turned back up. wpctl takes
    // a moment, and an alert starting meanwhile would otherwise read the
    // ducked level as the stream's own and restore to that.
    property var restored: ({})

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/ducking.json`
    property bool _loaded: false

    function isAlert(n) {
        return alertRoles.includes(String(n.properties["media.role"] ?? "").toLowerCase());
    }

    function setEnabled(on) {
        enabled = on;
        restoreTimer.stop();
        if (!on)
            _restore();
        else if (alerting)
            _duck();
        file.setText(JSON.stringify({ enabled }) + "\n");
    }

    onAlertingChanged: {
        if (!enabled)
            return;
        if (alerting) {
            restoreTimer.stop();
            _duck();
        } else {
            // Back-to-back chimes stay ducked instead of pumping the music.
            restoreTimer.restart();
        }
    }

    // Only streams playing when the alert starts; one that starts meanwhile
    // has no settled level to restore yet. A node shows up unbound (no role,
    // volume 0) and drops back to that as it goes, so an unready one could be
    // another alert, and setting it would save its level as the role's.
    function _duck() {
        const next = Object.assign({}, saved);
        for (const n of streams) {
            if (!n.ready || isAlert(n) || !n.audio || next[n.id])
                continue;
            const back = restored[n.id];
            const volume = back && Date.now() - back.at < 1000 ? back.volume : n.audio.volume;
            const ducked = volume * level;
            next[n.id] = { volume, ducked };
            Quickshell.execDetached(["wpctl", "set-volume", `${n.id}`, ducked.toFixed(3)]);
        }
        saved = next;
    }

    // A level changed meanwhile (by hand, in the app) is left alone.
    function _restore() {
        const back = {};
        for (const id in saved) {
            const n = streams.find(s => s.id === Number(id));
            const s = saved[id];
            if (n?.ready && n.audio && Math.abs(n.audio.volume - s.ducked) < 0.01) {
                Quickshell.execDetached(["wpctl", "set-volume", id, s.volume.toFixed(3)]);
                back[id] = { volume: s.volume, at: Date.now() };
            }
        }
        saved = {};
        restored = back;
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        // Only the first load; later ones are our own writes.
        onLoaded: {
            if (root._loaded)
                return;
            root._loaded = true;
            try {
                root.enabled = JSON.parse(text()).enabled !== false;
            } catch (e) {
                console.warn(`Ducking: ignoring unreadable ${root.path}: ${e}`);
            }
        }
    }

    Timer {
        id: restoreTimer
        interval: 400
        onTriggered: root._restore()
    }

    // Volumes are only live while something tracks the node.
    PwObjectTracker {
        objects: root.streams
    }
}
