import QtQuick
import qs
import qs.components
import qs.services

// Connected bluetooth device (and its battery); hidden when none.
BarModule {
    id: root

    required property string screenName
    readonly property var device: Bt.connected[0] ?? null
    readonly property int battery: Bt.battery(device)

    visible: device !== null
    text: device ? ` ${device.name}${battery >= 0 ? ` ${battery}%` : ""}${Bt.connected.length > 1 ? ` +${Bt.connected.length - 1}` : ""}` : ""
    active: Panels.isOpen("quick", screenName) && Panels.page === "bluetooth"

    onClicked: Panels.toggle("quick", screenName, "bluetooth")
}
