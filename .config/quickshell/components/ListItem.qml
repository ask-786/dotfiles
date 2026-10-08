import QtQuick
import qs

// Row for the Wi-Fi / Bluetooth / audio lists.
Rectangle {
    id: root

    property string icon
    property string title
    property string subtitle: ""
    property bool highlighted: false
    default property alias trailing: trailingRow.data

    signal clicked
    signal rightClicked

    implicitHeight: 48
    radius: Theme.radius
    color: highlighted ? Theme.surfaceHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }

    Icon {
        id: icon

        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: 20
        color: root.highlighted ? Theme.accent : Theme.fg
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: trailingRow.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.title
            color: root.highlighted ? Theme.accent : Theme.fg
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 2
        }
    }

    StateLayer {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }

    Row {
        id: trailingRow

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
