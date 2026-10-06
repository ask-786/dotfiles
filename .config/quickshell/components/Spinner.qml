import QtQuick
import qs

// Number picker for time fields: arrows above and below, and the scroll
// wheel on the number. Wraps around by default (59 → 0, 12 → 1).
Column {
    id: root

    property int value: 0
    property int from: 0
    property int to: 59
    property int step: 1
    property bool wrap: true
    property int digits: 2

    property real _wheel: 0

    function bump(dir) {
        const span = to - from + 1;
        const v = value + dir * step;
        value = wrap ? ((v - from) % span + span) % span + from : Math.max(from, Math.min(to, v));
    }

    spacing: 2

    IconButton {
        anchors.horizontalCenter: parent.horizontalCenter
        size: 26
        icon: Icons.chevronUp
        idleColor: "transparent"
        onClicked: root.bump(1)
    }

    Rectangle {
        width: 56
        height: 44
        radius: Theme.radius
        color: Theme.surfaceHigh

        StyledText {
            anchors.centerIn: parent
            text: String(root.value).padStart(root.digits, "0")
            font.pixelSize: 24
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            // Accumulate so touchpads (many small deltas) step like a wheel.
            onWheel: event => {
                root._wheel += event.angleDelta.y;
                while (Math.abs(root._wheel) >= 120) {
                    const dir = root._wheel > 0 ? 1 : -1;
                    root._wheel -= dir * 120;
                    root.bump(dir);
                }
            }
        }
    }

    IconButton {
        anchors.horizontalCenter: parent.horizontalCenter
        size: 26
        icon: Icons.chevronDown
        idleColor: "transparent"
        onClicked: root.bump(-1)
    }
}
