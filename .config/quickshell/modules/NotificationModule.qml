import QtQuick
import qs
import qs.components
import qs.services

// Opens the notifications drawer: a bell with the count, an outline when
// there are none, crossed out during do-not-disturb.
BarModule {
    required property string screenName

    readonly property int count: Notifs.list.length

    text: Notifs.dnd ? Icons.bellOff : count > 0 ? `${Icons.bell} ${count}` : Icons.bellOutline
    active: Panels.isOpen("notifications", screenName)

    onClicked: Panels.toggle("notifications", screenName)
}
