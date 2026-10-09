import QtQuick
import qs
import qs.services

// A fired reminder, timer or prayer time, with Snooze (or Stop for the
// adhan) and Done. Shown in the popups and on the lock screen.
Rectangle {
    id: card

    required property var alert

    height: content.implicitHeight + 2 * Theme.padding
    radius: Theme.radius
    color: Theme.panelBg
    border.width: 1
    border.color: Theme.panelBorder

    Icon {
        id: icon

        x: Theme.padding
        y: Theme.padding
        text: card.alert.prayer ? Icons.mosque : card.alert.duration ? Icons.timer : Icons.alarm
        size: 22
        color: card.alert.missed ? Theme.orange : Theme.accent
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
            text: Reminders.title(card.alert)
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 3
        }

        StyledText {
            width: parent.width
            text: Reminders.alertText(card.alert)
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 1
        }

        Item { width: 1; height: 4 }

        Row {
            anchors.right: parent.right
            spacing: 6

            TextButton {
                visible: !card.alert.prayer
                icon: Icons.sleep
                text: `Snooze ${Reminders.snoozeMinutes} min`
                onClicked: Reminders.snoozeAlert(card.alert.key)
            }
            TextButton {
                visible: !!card.alert.prayer && Prayer.playing
                icon: Icons.volumeOff
                text: "Stop"
                onClicked: Prayer.stop()
            }
            TextButton {
                icon: Icons.check
                text: "Done"
                fg: Theme.accent
                onClicked: {
                    if (card.alert.prayer)
                        Prayer.stop();
                    Reminders.dismiss(card.alert.key);
                }
            }
        }
    }
}
