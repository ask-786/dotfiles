import QtQuick
import qs

// Hover/press overlay for anything clickable. Drop it inside a Rectangle;
// it fills the parent and copies its radius.
MouseArea {
    id: root

    property color color: Theme.fg
    property real radius: parent?.radius ?? 0

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.color
        opacity: !root.enabled ? 0 : root.pressed ? 0.16 : root.containsMouse ? 0.08 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }
    }
}
