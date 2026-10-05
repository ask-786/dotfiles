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

    signal clicked

    implicitWidth: size
    implicitHeight: size
    radius: Theme.radius
    color: active ? activeColor : idleColor

    Behavior on color {
        ColorAnimation { duration: Theme.normal }
    }

    Icon {
        anchors.centerIn: parent
        text: root.icon
        size: root.size * 0.5
        color: root.active ? root.activeFg : Theme.fg
    }

    StateLayer {
        color: root.active ? root.activeFg : Theme.fg
        onClicked: root.clicked()
    }
}
