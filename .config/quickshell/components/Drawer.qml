import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// A panel that grows up out of the bar (the motion is borrowed from
// Caelestia; the look is the bar's own). Put a single content item inside;
// the drawer sizes itself to it.
PanelWindow {
    id: root

    required property var bar
    required property string name
    property int align: Qt.AlignRight // AlignLeft | AlignHCenter | AlignRight
    property int contentWidth: 400
    // Raises the body off the bar, e.g. to stack on another open drawer.
    property real lift: 0
    default property alias content: inner.data

    readonly property bool open: Panels.isOpen(name, bar.screenName)
    readonly property real targetHeight: inner.implicitHeight + 2 * Theme.padding

    // 0 → 1 as the drawer opens; the height follows content changes too.
    property real progress: open ? 1 : 0
    property real bodyHeight: targetHeight
    readonly property real h: bodyHeight * progress
    // Room a drawer stacked on this one has to clear (body plus a gap).
    readonly property real stackHeight: h + Theme.spacing * progress

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? Theme.slow : Theme.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Theme.emphasized : Theme.emphasizedAccel
        }
    }
    Behavior on bodyHeight {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.emphasized
        }
    }

    screen: bar.screen
    visible: open || progress > 0
    color: "transparent"

    anchors.bottom: true
    anchors.left: align === Qt.AlignLeft
    anchors.right: align === Qt.AlignRight
    margins.left: align === Qt.AlignLeft ? Theme.drawerGap : 0
    margins.right: align === Qt.AlignRight ? Theme.drawerGap : 0

    // Sit on top of the bar without reserving space or pushing windows. Over
    // a fullscreen window the bar is hidden, so grow from the screen edge.
    exclusionMode: bar.fullscreen ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: 0
    // Overlay keeps it above the ClickCatcher (Top) that closes it; over a
    // fullscreen window both are Overlay and the catcher cuts a hole for the
    // body instead (stacking there follows map order). Keyboard
    // focus must stay OnDemand: an Exclusive layer makes Hyprland route all
    // pointer input to exclusive layers only, so outside clicks never land.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: `quickshell:${name}`
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    implicitWidth: contentWidth
    // Tall enough for a lifted drawer; the mask keeps the rest click-through.
    implicitHeight: (screen?.height ?? 1080) - Theme.barHeight

    // Only the visible body takes input; the rest of the window is click-through.
    mask: Region {
        item: body
    }

    // Flat panel in the bar's colours, a small gap off the bar.
    Rectangle {
        x: body.x
        y: body.y
        width: body.width
        height: root.h
        visible: root.h > 0
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.panelBorder
        radius: Theme.radius
    }

    Item {
        id: body

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.lift + Theme.drawerGap
        width: root.contentWidth
        height: root.h
        clip: true
        focus: true

        Keys.onEscapePressed: Panels.close()

        // Opening, pinned to the top edge, so content rides up out of the
        // bar. Resizing while open, pinned to the bottom, so what's next to
        // the bar stands still and only the top edge moves.
        Column {
            id: inner

            x: Theme.padding
            y: Theme.padding + (root.bodyHeight - root.targetHeight) * root.progress
            width: parent.width - 2 * Theme.padding
            opacity: Math.min(1, root.progress * 1.5)
        }
    }
}
