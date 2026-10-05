import QtQuick
import qs
import qs.components
import qs.services

// Old waybar network format; click opens the Wi-Fi page.
BarModule {
    id: root

    required property string screenName

    text: {
        if (Net.active)
            return `${Net.active.name} (${Math.round(Net.signal * 100)}%) `;
        if (Net.wired)
            return Stats.ipAddr ? `${Stats.ipAddr}/${Stats.ipPrefix} ` : `${Stats.iface} (No IP) `;
        return "Disconnected ⚠";
    }
    textColor: Net.active || (Net.wired && Stats.ipAddr) ? Theme.green
             : Net.wired ? Theme.yellow : Theme.red
    active: Panels.isOpen("quick", screenName) && Panels.page === "wifi"

    onClicked: Panels.toggle("quick", screenName, "wifi")
}
