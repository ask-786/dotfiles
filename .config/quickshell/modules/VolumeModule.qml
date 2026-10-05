import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Old waybar pulseaudio format. Click: quick settings, right-click: mute,
// scroll: volume.
BarModule {
    id: root

    required property string screenName

    readonly property int volume: Math.round(Audio.volume * 100)
    readonly property string icon: Audio.bluetooth ? "" : ["", "", ""][Math.min(2, Math.floor(volume / 34))]

    text: Audio.muted ? `\u{F075F}${Audio.bluetooth ? " " : ""}`
                      : `${volume}% ${icon}${Audio.bluetooth ? "" : ""}`
    textColor: Audio.muted ? Theme.orange : "#e0e0e0"
    active: Panels.isOpen("quick", screenName) && Panels.page === "audio"

    onClicked: button => {
        if (button === Qt.RightButton)
            Audio.toggleMute();
        else
            Panels.toggle("quick", screenName, "audio");
    }
    onScrolled: steps => Audio.setVolume(Audio.volume + steps * 0.05)
}
