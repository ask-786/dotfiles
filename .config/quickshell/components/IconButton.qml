import QtQuick
import qs

Rectangle {
    id: root

    property string icon
    property real size: 34
    property bool active: false
    property color activeColor: Theme.primary
    property color activeFg: Theme.primaryFg
    property color idleColor: Theme.surfaceHigh
    property bool spinning: false // turn the icon, e.g. while searching

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: Theme.radius
    color: active ? activeColor : idleColor

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }

    Icon {
        id: glyph

        anchors.centerIn: parent
        text: root.icon
        size: root.size * 0.5
        color: root.active ? root.activeFg : Theme.fg

        RotationAnimation on rotation {
            running: root.spinning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1500
            // Upright again once stopped.
            onRunningChanged: if (!running) glyph.rotation = 0
        }
    }

    StateLayer {
        color: root.active ? root.activeFg : Theme.fg
        onClicked: root.clicked()
    }
}
