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
    text: `${Stats.formatRate(Stats.rxRate)} ${Stats.formatRate(Stats.txRate)} `
    textColor: Theme.green
    tooltip: Stats.ipAddr ? `${Stats.iface} · ${Stats.ipAddr}/${Stats.ipPrefix}` : Stats.iface
    active: Panels.isOpen("quick", screenName) && Panels.page === ""

    onClicked: Panels.toggle("quick", screenName, "")
}
