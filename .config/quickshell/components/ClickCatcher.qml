import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Invisible full-screen layer under an open drawer: any click outside the
// drawer lands here and closes it. It respects the bar's exclusive zone, so
// bar clicks still reach the bar (switching drawers instead of closing).
PanelWindow {
    required property var bar

    screen: bar.screen
    visible: Panels.open !== "" && Panels.screen === bar.screenName
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:catcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Panels.close()
    }
}
