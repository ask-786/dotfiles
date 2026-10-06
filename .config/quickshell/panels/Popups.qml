import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Popups, top right: fired reminders (with Snooze / Done, until dealt with)
// and then notifications, newest first in each. Over fullscreen windows too,
// on the focused monitor.
PanelWindow {
    id: root

    required property var bar

    screen: bar.screen
    visible: (Reminders.alerts.length > 0 || Notifs.popups.length > 0) && Hyprland.focusedMonitor?.name === bar.screenName
    color: "transparent"

    anchors.top: true
    anchors.right: true
    margins.top: 50
    margins.right: 10

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:popups"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: 360
    implicitHeight: Math.max(1, cards.implicitHeight)

    Column {
        id: cards

        width: parent.width
        spacing: Theme.spacing

        Repeater {
            model: ScriptModel {
                values: Reminders.alerts.slice().reverse()
            }

            Rectangle {
                id: card

                required property var modelData

                width: cards.width
                height: content.implicitHeight + 2 * Theme.padding
                radius: Theme.radius
                color: Theme.panelBg
                border.width: 1
                border.color: Theme.panelBorder

                NumberAnimation on opacity {
                    from: 0
                    to: 1
                    duration: Theme.normal
                }

                Icon {
                    id: icon

                    x: Theme.padding
                    y: Theme.padding
                    text: card.modelData.duration ? Icons.timer : Icons.alarm
                    size: 22
                    color: card.modelData.missed ? Theme.orange : Theme.accent
                }

                Column {
                    id: content

                    anchors.left: icon.right
                    anchors.leftMargin: Theme.padding
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.padding
                    y: Theme.padding
                    spacing: 4

                    StyledText {
                        width: parent.width
                        text: Reminders.title(card.modelData)
                        font.bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                    }

                    StyledText {
                        width: parent.width
                        text: Reminders.alertText(card.modelData)
                        color: Theme.fgDim
                        font.pixelSize: Theme.fontSize - 1
                    }

                    Item { width: 1; height: 4 }

                    Row {
                        anchors.right: parent.right
                        spacing: 6

                        TextButton {
                            icon: Icons.sleep
                            text: `Snooze ${Reminders.snoozeMinutes} min`
                            onClicked: Reminders.snoozeAlert(card.modelData.key)
                        }
                        TextButton {
                            icon: Icons.check
                            text: "Done"
                            fg: Theme.accent
                            onClicked: Reminders.dismiss(card.modelData.key)
                        }
                    }
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: Notifs.popups.map(p => p.n).filter(n => n).reverse()
            }

            NotificationCard {
                required property var modelData

                width: cards.width
                notification: modelData
                popup: true

                NumberAnimation on opacity {
                    from: 0
                    to: 1
                    duration: Theme.normal
                }
            }
        }
    }
}
