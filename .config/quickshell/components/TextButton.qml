import QtQuick
import qs

Rectangle {
    id: root

    property string text
    property string icon: ""
    property color fg: Theme.fg

    signal clicked

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    radius: Theme.radius
    color: Theme.surfaceHigh

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 8

        Icon {
            visible: root.icon !== ""
            text: root.icon
            size: 16
            color: root.fg
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.text
            color: root.fg
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    StateLayer {
        color: root.fg
        onClicked: root.clicked()
    }
}
