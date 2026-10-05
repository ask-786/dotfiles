import QtQuick
import qs

// GNOME-style quick toggle: the body toggles, the chevron (if any) opens
// the detail page.
Rectangle {
    id: root

    property string icon
    property string title
    property string subtitle: ""
    property bool active: false
    property bool hasDetails: false

    signal toggled
    signal detailsRequested

    readonly property color fg: active ? Theme.fg : Theme.fgDim

    implicitHeight: 58
    radius: Theme.radius
    color: active ? Theme.primary : Theme.surface
    border.width: 1
    border.color: active ? Theme.surfaceHighest : Theme.border

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }

    Item {
        id: main

        anchors.left: parent.left
        anchors.right: details.visible ? details.left : parent.right
        height: parent.height

        Icon {
            id: icon

            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: 20
            color: root.active ? Theme.accent : Theme.fgDim
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: root.title
                color: root.fg
                font.bold: true
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.subtitle
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSize - 2
            }
        }

        StateLayer {
            radius: Theme.radius
            color: root.fg
            onClicked: root.toggled()
        }
    }

    Item {
        id: details

        visible: root.hasDetails
        anchors.right: parent.right
        width: 40
        height: parent.height

        Rectangle {
            width: 1
            height: parent.height - 24
            anchors.verticalCenter: parent.verticalCenter
            color: root.fg
            opacity: 0.2
        }

        Icon {
            anchors.centerIn: parent
            text: Icons.chevronRight
            size: 18
            color: root.fg
        }

        StateLayer {
            radius: Theme.radius
            color: root.fg
            onClicked: root.detailsRequested()
        }
    }
}
