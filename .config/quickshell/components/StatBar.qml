import QtQuick
import qs

// Labelled stat with a thin progress bar (CPU, battery levels, …).
Column {
    id: stat

    property string icon
    property string label
    property string value
    property real fraction: 0
    property bool warn: false

    spacing: 6

    Item {
        width: parent.width
        height: 18

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Icon { text: stat.icon; size: 15; color: Theme.fgDim }
            StyledText { text: stat.label; color: Theme.fgDim; font.pixelSize: Theme.fontSize - 2 }
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: stat.value
            color: stat.warn ? Theme.red : Theme.fg
            font.pixelSize: Theme.fontSize - 1
        }
    }

    Rectangle {
        width: parent.width
        height: 5
        radius: 3
        color: Theme.surfaceHighest

        Rectangle {
            width: Math.max(height, parent.width * Math.min(1, stat.fraction))
            height: parent.height
            radius: 3
            color: stat.warn ? Theme.red : Theme.fgDim

            Behavior on width {
                NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic }
            }
        }
    }
}
