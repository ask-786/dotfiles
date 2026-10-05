import QtQuick
import qs
import qs.components
import qs.services

// Old waybar battery format; click opens quick settings.
BarModule {
    id: root

    required property string screenName
    readonly property bool critical: Battery.percent <= 15 && !Battery.plugged
    readonly property string icon: ["\u{F007A}", "\u{F007C}", "\u{F007E}", "\u{F0081}", "\u{F0079}"][Math.min(4, Math.floor(Battery.percent / 20))]

    visible: Battery.available
    text: Battery.charging ? `${Battery.percent}% `
        : Battery.plugged ? `${Battery.percent}% `
        : `${Battery.percent}% ${icon}`
    textColor: critical ? Theme.red : Theme.fg
    blink: critical
    active: Panels.isOpen("quick", screenName) && Panels.page === ""

    onClicked: Panels.toggle("quick", screenName, "")
}
