import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Notification history, newest first, with do-not-disturb and Clear all.
// Opened from the bell next to the quick settings button.
Drawer {
    id: root

    name: "notifications"
    align: Qt.AlignRight
    contentWidth: 400

    Column {
        width: parent.width
        spacing: 10

        Item {
            width: parent.width
            height: 34

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                text: "Notifications"
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                IconButton {
                    icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                    active: Notifs.dnd
                    onClicked: Notifs.dnd = !Notifs.dnd
                }

                TextButton {
                    visible: Notifs.list.length > 0
                    text: "Clear all"
                    onClicked: Notifs.clearAll()
                }
            }
        }

        StyledText {
            width: parent.width
            height: 60
            visible: Notifs.list.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: Notifs.dnd ? "No notifications · do not disturb is on" : "No notifications"
            color: Theme.fgMuted
        }

        ListView {
            width: parent.width
            height: Math.min(contentHeight, 560)
            visible: count > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: Notifs.list.slice().reverse()
            }

            delegate: NotificationCard {
                required property var modelData

                width: ListView.view.width
                notification: modelData
            }
        }
    }
}
