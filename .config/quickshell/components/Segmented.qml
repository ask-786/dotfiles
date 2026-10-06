import QtQuick
import qs

// A row of equal-width buttons, one of them selected (like waybar's
// active workspace button). Set `width`; bind `current` to the selected
// index and update it from `activated`.
Row {
    id: root

    property var options: []
    property int current: 0
    property real buttonHeight: 32

    signal activated(int index)

    spacing: 4

    Repeater {
        model: root.options

        Rectangle {
            required property string modelData
            required property int index
            readonly property bool selected: index === root.current

            width: (root.width - root.spacing * (root.options.length - 1)) / root.options.length
            height: root.buttonHeight
            radius: Theme.radius
            color: selected ? Theme.primary : Theme.surfaceHigh

            Behavior on color {
                ColorAnimation { duration: Theme.normal }
            }

            StyledText {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 4)
                text: parent.modelData
                color: parent.selected ? Theme.primaryFg : Theme.fgDim
                font.bold: parent.selected
            }

            StateLayer {
                onClicked: root.activated(parent.index)
            }
        }
    }
}
