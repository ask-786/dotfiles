import QtQuick
import qs

// Thick M3-style slider with the icon inside the filled part.
// Click the icon for `iconClicked` (e.g. mute); drag, click or scroll the
// track for `moved(value)`.
Item {
    id: root

    property real value: 0 // 0..1
    property string icon
    property bool dimmed: false
    property real step: 0.05

    readonly property real shown: area.pressed ? dragValue : value
    property real dragValue: 0

    signal moved(real value)
    signal iconClicked

    implicitHeight: 36

    function setFrom(x) {
        dragValue = Math.max(0, Math.min(1, x / width));
        moved(dragValue);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surfaceHigh
    }

    Rectangle {
        id: fill

        height: parent.height
        width: Math.max(height, root.shown * parent.width)
        radius: Theme.radius
        color: root.dimmed ? Theme.surfaceHigh : Qt.rgba(1, 1, 1, 0.28)

        Behavior on width {
            enabled: !area.pressed
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }
    }

    StyledText {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: `${Math.round(root.shown * 100)}%`
        color: Theme.fgDim
        font.pixelSize: Theme.fontSize - 2
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: event => root.setFrom(event.x)
        onPositionChanged: event => root.setFrom(event.x)
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? root.step : -root.step))))
    }

    // Icon sits on the fill's rounded left end; clicking it doesn't drag.
    Item {
        width: parent.height
        height: parent.height

        Icon {
            anchors.centerIn: parent
            text: root.icon
            size: 18
            color: Theme.fg
        }

        StateLayer {
            radius: Theme.radius
            color: Theme.fg
            onClicked: root.iconClicked()
        }
    }
}
