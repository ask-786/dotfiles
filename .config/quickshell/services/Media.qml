pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The one MPRIS player the bar and media popup act on: the one picked in the
// popup's switcher, else whichever is playing, else the last one that played,
// else a paused one with a track.
Singleton {
    id: root

    // Some apps (VLC) register the same player under two bus names; keep one.
    readonly property var players: {
        const seen = new Set();
        return Mpris.players.values.filter(p => {
            const key = `${p.identity}|${p.trackTitle}|${p.length}`;
            if (seen.has(key))
                return false;
            seen.add(key);
            return true;
        });
    }
    property var _picked: null
    property var _lastActive: null

    readonly property var player: {
        if (_picked && players.includes(_picked))
            return _picked;
        const playing = players.find(p => p.isPlaying);
        if (playing)
            return playing;
        if (_lastActive && players.includes(_lastActive))
            return _lastActive;
        // Nothing recorded yet (e.g. right after a restart): prefer a paused
        // player with a track over idle ones.
        return players.find(p => p.playbackState === MprisPlaybackState.Paused && p.trackTitle)
            ?? players.find(p => p.trackTitle)
            ?? players[0] ?? null;
    }

    // Untagged media (some browser tabs, bare files) has no title; fall back
    // to the player's name so it still shows up while playing or paused.
    readonly property bool hasTrack: player !== null
        && ((player.trackTitle ?? "") !== "" || player.playbackState !== MprisPlaybackState.Stopped)
    readonly property string title: player?.trackTitle || player?.identity || ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property bool playing: player?.isPlaying ?? false

    function pick(p) {
        _picked = p;
        _lastActive = p;
    }

    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${m}:${pad(sec)}`;
    }

    // A player that starts playing becomes the active one, overriding a pick.
    Instantiator {
        model: Mpris.players

        Connections {
            required property var modelData

            target: modelData

            function onIsPlayingChanged() {
                if (!modelData.isPlaying)
                    return;
                root._lastActive = modelData;
                if (root._picked !== modelData)
                    root._picked = null;
            }
        }
    }

    // MPRIS doesn't push position updates; poll while playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: root.player?.positionChanged()
    }
}
