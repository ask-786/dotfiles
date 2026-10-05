import QtQuick
import Quickshell
import qs

// Small popup that fades and slides in above the bar item it belongs to.
// Shows `text`, or `content` when a module wants something richer.
PopupWindow {
    id: root

    required property Item target
    property bool shown: false
    property string text: ""
    property Component content: null

    readonly property int gap: 6

    anchor.item: target
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top

    implicitWidth: box.width
    implicitHeight: box.height + gap
    color: "transparent"
    visible: box.opacity > 0

    // Never take input, so the popup can't steal hover from the bar.
    mask: Region {}

    Rectangle {
        id: box

        width: body.implicitWidth + 20
        height: body.implicitHeight + 12
        radius: Theme.radius
        color: Theme.bg
        border.color: Theme.outline

        opacity: root.shown ? 1 : 0
        y: root.shown ? 0 : 4

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }
        Behavior on y {
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Loader {
            id: body
            anchors.centerIn: parent
            sourceComponent: root.content ?? plainText
        }
    }

    Component {
        id: plainText

        Text {
            text: root.text
            textFormat: Text.PlainText
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
