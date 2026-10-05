import QtQuick
import qs
import qs.components
import qs.services

// Compact "▶ Title" while a player has a track (waybar mpd-style state
// icon); artist and album are in the tooltip. Click opens the media popup,
// right-click plays/pauses.
BarModule {
    id: root

    required property string screenName
    readonly property int maxChars: 22

    readonly property string label: Media.title

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
