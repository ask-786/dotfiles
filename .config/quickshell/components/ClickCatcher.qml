import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Invisible full-screen layer under an open drawer: any click outside the
// drawer lands here and closes it. It respects the bar's exclusive zone, so
// bar clicks still reach the bar (switching drawers instead of closing).
PanelWindow {
    id: root

    required property var bar
    // The drawers on this screen; their bodies are cut out of the input mask.
    property list<var> drawers

    screen: bar.screen
    visible: Panels.any && Panels.screen === bar.screenName
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: bar.fullscreen ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: 0
    // Fullscreen windows cover the Top layer (and the hidden bar); go above
    // them and over the bar's zone so outside clicks still land here.
    WlrLayershell.layer: bar.fullscreen ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "quickshell:catcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // On the Overlay layer the catcher and the drawers stack in the order they
    // were mapped, so the catcher can end up on top and swallow every click
    // meant for a drawer. Holes where the drawer bodies are let those clicks
    // fall through whatever the order. Both windows sit on the same bottom
    // edge (the bar, or the screen edge over a fullscreen window).
    mask: Region {
        item: catcher
        regions: holes.instances
    }

    Variants {
        id: holes

        model: root.drawers

        Region {
            required property var modelData

            intersection: Intersection.Subtract
            width: modelData.contentWidth
            height: Math.ceil(modelData.h)
            x: modelData.align === Qt.AlignLeft ? Theme.drawerGap
                : modelData.align === Qt.AlignHCenter ? (root.width - width) / 2
                : root.width - Theme.drawerGap - width
            y: root.height - modelData.lift - Theme.drawerGap - height
        }
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Panels.close()
    }
}
