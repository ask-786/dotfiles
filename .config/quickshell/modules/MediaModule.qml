import QtQuick
import qs
import qs.components
import qs.services

// "▶ Artist - Title" while a player has a track (waybar mpd-style state
// icon). Click opens the media popup, right-click plays/pauses.
BarModule {
    id: root

    required property string screenName
    readonly property int maxChars: 45

    readonly property string label: Media.artist ? `${Media.artist} - ${Media.title}` : Media.title

    visible: Media.hasTrack
    text: `${Media.playing ? "" : ""} ${label.length > maxChars ? label.slice(0, maxChars - 1) + "…" : label}`
    textColor: Media.playing ? Theme.fg : Theme.fgDim
    tooltip: Media.player ? `${Media.title}${Media.artist ? " — " + Media.artist : ""}${Media.player.trackAlbum ? " (" + Media.player.trackAlbum + ")" : ""} · ${Media.player.identity}` : ""
    active: Panels.isOpen("media", screenName)

    onClicked: button => {
        if (button === Qt.RightButton || button === Qt.MiddleButton)
            Media.player?.togglePlaying();
        else
            Panels.toggle("media", screenName);
    }
}
