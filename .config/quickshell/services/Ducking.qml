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
//
// WirePlumber saves each app's level and starts the app's next stream at
// it, so a stream that closes while ducked (Chrome drops its stream soon
// after a sound ends) would leave the app at the ducked level, lower with
// every miss. Those apps are kept with their own level until they play
// again; the state file keeps them, and the levels of streams ducked right
// now, so a restart mid-alert doesn't lose them.
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

    // Node id → { key, volume, ducked } for each stream turned down.
    property var saved: ({})
    // Node id → { volume, at } for streams just turned back up. wpctl takes
    // a moment, and an alert starting meanwhile would otherwise read the
    // ducked level as the stream's own and restore to that.
    property var restored: ({})
    // App key → { volume, ducked } for apps whose stream closed while ducked.
    property var pending: ({})
    // Their streams playing again at the ducked level. One at another level
    // was set since (or WirePlumber hasn't restored it yet) and is left be.
    readonly property var reopened: streams.filter(n => {
        const p = n.ready && n.audio ? pending[appKey(n)] : undefined;
        return p !== undefined && Math.abs(n.audio.volume - p.ducked) < 0.01;
    })

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/ducking.json`
    property bool _loaded: false

    function isAlert(n) {
        return alertRoles.includes(String(n.properties["media.role"] ?? "").toLowerCase());
    }

    // The key WirePlumber saves an app's level under.
    function appKey(n) {
        for (const k of ["application.id", "application.name", "media.name"]) {
            const v = n.properties[k];
            if (v !== undefined && v !== "")
                return `${k}:${v}`;
        }
        return "";
    }

    function setEnabled(on) {
        enabled = on;
        restoreTimer.stop();
        if (!on)
            _restore();
        else if (alerting)
            _duck();
        _save();
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

    // Later, since it changes what reopened reads.
    onReopenedChanged: Qt.callLater(_reopen)

    function _reopen() {
        if (!reopened.length)
            return;
        const left = Object.assign({}, pending);
        for (const n of reopened) {
            const key = appKey(n);
            Quickshell.execDetached(["wpctl", "set-volume", `${n.id}`, pending[key].volume.toFixed(3)]);
            delete left[key];
        }
        pending = left;
        _save();
    }

    // Only streams playing when the alert starts; one that starts meanwhile
    // has no settled level to restore yet. A node shows up unbound (no role,
    // volume 0) and drops back to that as it goes, so an unready one could be
    // another alert, and setting it would save its level as the role's.
    function _duck() {
        const next = Object.assign({}, saved);
        const left = Object.assign({}, pending);
        for (const n of streams) {
            if (!n.ready || isAlert(n) || !n.audio || next[n.id] || reopened.includes(n))
                continue;
            const back = restored[n.id];
            const volume = back && Date.now() - back.at < 1000 ? back.volume : n.audio.volume;
            const ducked = volume * level;
            const key = appKey(n);
            next[n.id] = { key, volume, ducked };
            // Its app plays at a level of its own again.
            delete left[key];
            Quickshell.execDetached(["wpctl", "set-volume", `${n.id}`, ducked.toFixed(3)]);
        }
        saved = next;
        pending = left;
        _save();
    }

    // A level changed meanwhile (by hand, in the app) is left alone. A stream
    // that's gone (or going) left its app at the ducked level.
    function _restore() {
        const back = {};
        const left = Object.assign({}, pending);
        const up = [];
        for (const id in saved) {
            const n = streams.find(s => s.id === Number(id));
            const s = saved[id];
            if (!n?.ready || !n.audio) {
                if (s.key)
                    left[s.key] = { volume: s.volume, ducked: s.ducked };
            } else if (Math.abs(n.audio.volume - s.ducked) < 0.01) {
                Quickshell.execDetached(["wpctl", "set-volume", id, s.volume.toFixed(3)]);
                back[id] = { volume: s.volume, at: Date.now() };
                up.push(s.key);
            }
        }
        // Another stream of the app turned back up saves its level anyway.
        for (const key of up)
            delete left[key];
        saved = {};
        restored = back;
        pending = left;
        _save();
    }

    function _save() {
        const keep = Object.assign({}, pending);
        for (const id in saved) {
            const s = saved[id];
            if (s.key)
                keep[s.key] = { volume: s.volume, ducked: s.ducked };
        }
        file.setText(JSON.stringify({ enabled, pending: keep }) + "\n");
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
                const state = JSON.parse(text());
                root.enabled = state.enabled !== false;
                if (state.pending && typeof state.pending === "object")
                    root.pending = state.pending;
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
