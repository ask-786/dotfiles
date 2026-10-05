import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

BarModule {
    id: root

    required property string screenName

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "ddd MMM-dd hh:mm AP")
    bold: true
    active: Panels.isOpen("calendar", screenName)

    onClicked: Panels.toggle("calendar", screenName)
}
