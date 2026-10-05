import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// Hyprland workspaces styled like waybar's `#workspaces button`. The active
// highlight slides between buttons; buttons pop in/out as workspaces come
// and go.
Item {
    id: root

    property Item activeItem: null

    implicitWidth: list.contentWidth + 4
    implicitHeight: Theme.barHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    // Under the list: adds to the button's own 0.1 white to make 0.2.
    Rectangle {
        id: highlight

        // Don't animate the very first placement.
        property bool ready: false

        visible: root.activeItem !== null
        x: list.x + (root.activeItem ? root.activeItem.x + 2 : 0)
        y: 4
        width: root.activeItem ? root.activeItem.width - 4 : 0
        height: parent.height - 8
        radius: Theme.radius
        color: Qt.rgba(1, 1, 1, 0.12)

        Behavior on x {
            enabled: highlight.ready
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: highlight.ready
            NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        Timer {
            running: root.activeItem !== null
            interval: 100
            onTriggered: highlight.ready = true
        }
    }

    ListView {
        id: list

        x: 2
        width: contentWidth
        height: parent.height
        orientation: ListView.Horizontal
        interactive: false

        model: ScriptModel {
            values: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
        }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
            NumberAnimation { property: "scale"; from: 0.4; to: 1; duration: Theme.normal; easing.type: Easing.OutBack }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast }
            NumberAnimation { property: "scale"; to: 0.4; duration: Theme.fast }
        }
        displaced: Transition {
            NumberAnimation { properties: "x"; duration: Theme.normal; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: ws

            required property var modelData
            readonly property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
            readonly property bool urgent: modelData.urgent

            width: name.implicitWidth + 20
            height: list.height

            onIsActiveChanged: if (isActive) root.activeItem = ws
            Component.onCompleted: if (isActive) root.activeItem = ws
            Component.onDestruction: if (root.activeItem === ws) root.activeItem = null

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                radius: Theme.radius
                color: ws.urgent ? Theme.urgentBg
                     : area.containsMouse ? Qt.rgba(1, 1, 1, 0.16)
                     : Qt.rgba(1, 1, 1, 0.08)
                border.width: ws.urgent ? 1 : 0
                border.color: Theme.urgentBorder

                Behavior on color {
                    ColorAnimation { duration: Theme.fast }
                }

                SequentialAnimation on opacity {
                    running: ws.urgent
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    NumberAnimation { to: 0.5; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            Text {
                id: name

                anchors.centerIn: parent
                text: ws.modelData.name
                color: ws.isActive || ws.urgent ? Theme.fg : Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.barFontSize
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation { duration: Theme.normal }
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Lua-config dispatcher syntax (hyprland.lua), not `workspace N`.
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws.modelData.id} })`)
            }
        }
    }
}
