import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Drawer {
    id: root

    name: "calendar"
    align: Qt.AlignRight
    contentWidth: 320

    onOpenChanged: if (!open) calendar.monthOffset = 0

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Column {
        width: parent.width
        spacing: 4

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "hh:mm:ss AP")
            font.pixelSize: 34
            font.bold: true
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dddd, MMMM d")
            color: Theme.fgDim
        }

        Item { width: 1; height: 10 }

        Calendar {
            id: calendar
            width: parent.width
            today: clock.date
        }
    }
}
