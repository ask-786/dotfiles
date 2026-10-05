import QtQuick
import qs

Rectangle {
    id: root

    property bool checked: false

    signal toggled

    implicitWidth: 44
    implicitHeight: 24
    radius: Theme.radius
    color: checked ? Theme.primary : Theme.surfaceHighest

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }

    Rectangle {
        property real d: root.checked ? 16 : 12

        x: root.checked ? root.width - d - 4 : 6
        anchors.verticalCenter: parent.verticalCenter
        width: d
        height: d
        radius: 2
        color: root.checked ? Theme.accent : Theme.fgDim

        Behavior on x {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack }
        }
        Behavior on d {
            NumberAnimation { duration: Theme.normal }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }
    }

    StateLayer {
        onClicked: root.toggled()
    }
}
