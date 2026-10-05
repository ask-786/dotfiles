import QtQuick
import qs

// Back button + title for a quick-settings detail page.
Item {
    id: root

    property string title
    default property alias trailing: trailingRow.data

    signal back

    implicitHeight: 36

    IconButton {
        id: backButton

        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.chevronLeft
        onClicked: root.back()
    }

    StyledText {
        anchors.left: backButton.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.pixelSize: Theme.fontSize + 3
        font.bold: true
    }

    Row {
        id: trailingRow

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
