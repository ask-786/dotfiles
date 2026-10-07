import QtQuick
import qs
import qs.components
import qs.services

// Old waybar network#speed: down/up rate of the default-route interface,
// hidden when there is none. Click opens quick settings (network stats).
BarModule {
    id: root

    required property string screenName

    visible: Stats.iface !== ""
    // Each rate padded to its widest form ("999.9kB/s"); the font is
    // monospace, so the module keeps one width and the media title next
    // to it doesn't jump around every second.
    text: `${Stats.formatRate(Stats.rxRate).padStart(9)} ${Stats.formatRate(Stats.txRate).padStart(9)} `
    textColor: Theme.green
    tooltip: Stats.ipAddr ? `${Stats.iface} · ${Stats.ipAddr}/${Stats.ipPrefix}` : Stats.iface
    active: Panels.isOpen("quick", screenName) && Panels.page === ""

    onClicked: Panels.toggle("quick", screenName, "")
}
