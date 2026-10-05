import QtQuick
import Quickshell
import qs

// One waybar-style text block with a hover highlight, optional tooltip and
// click/scroll signals. Modules set `text` and handle the rest.
Item {
    id: root

    property string text: ""
    property color textColor: Theme.fg
    property bool bold: false
    property bool blink: false
    property bool active: false // its drawer is open
    property string tooltip: ""

    property bool _tipShown: false

    property real _wheel: 0

    signal clicked(int button)
    signal scrolled(int steps)

    implicitWidth: label.implicitWidth + 16
    implicitHeight: Theme.barHeight

    onActiveChanged: _tipShown = false

    Timer {
        id: tipDelay
        interval: 400
        onTriggered: root._tipShown = true
    }

    LazyLoader {
        active: root.tooltip !== ""

        Tooltip {
            target: root
            shown: root._tipShown && !root.active
            text: root.tooltip
        }
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        radius: Theme.radius
        color: Theme.fg
        opacity: root.active ? 0.2 : mouse.containsMouse ? 0.1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.fast }
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        textFormat: Text.PlainText
        color: root.textColor
        font.family: Theme.font
        font.pixelSize: Theme.barFontSize
        font.bold: root.bold
        // Native FreeType rendering with full hinting, like GTK/waybar, so
        // text comes out the same size (Qt's default renderer ignores hinting).
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering

        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }

        SequentialAnimation on opacity {
            running: root.blink
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            root._tipShown = false;
            root.clicked(event.button);
        }
        onContainsMouseChanged: {
            if (containsMouse && root.tooltip !== "") {
                tipDelay.restart();
            } else {
                tipDelay.stop();
                root._tipShown = false;
            }
        }

        // Accumulate so touchpads (many small deltas) step like a wheel.
        onWheel: event => {
            root._wheel += event.angleDelta.y;
            while (Math.abs(root._wheel) >= 120) {
                const step = root._wheel > 0 ? 1 : -1;
                root._wheel -= step * 120;
                root.scrolled(step);
            }
        }
    }
}
