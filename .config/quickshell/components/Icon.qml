import QtQuick
import qs

// A Material Design glyph from the Nerd Font (see Icons.qml).
Text {
    property real size: 18

    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }
}
