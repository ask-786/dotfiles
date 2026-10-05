import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

Row {
    spacing: 16

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: item

            required property SystemTrayItem modelData

            width: 18
            height: Theme.barHeight
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: event => {
                tipDelay.stop();
                tip.shown = false;
                if (event.button === Qt.LeftButton && !modelData.onlyMenu)
                    modelData.activate();
                else if (event.button === Qt.MiddleButton)
                    modelData.secondaryActivate();
                else if (modelData.hasMenu)
                    menu.open();
            }
            onWheel: event => modelData.scroll(event.angleDelta.y, false)
            onContainsMouseChanged: {
                if (containsMouse && modelData.tooltipTitle) {
                    tipDelay.restart();
                } else {
                    tipDelay.stop();
                    tip.shown = false;
                }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: item.modelData.icon
                scale: item.containsMouse ? 1.15 : 1

                Behavior on scale {
                    NumberAnimation { duration: Theme.fast; easing.type: Easing.OutBack }
                }
            }

            QsMenuAnchor {
                id: menu
                menu: item.modelData.menu
                anchor.item: item
                anchor.edges: Edges.Top
                anchor.gravity: Edges.Top
            }

            Timer {
                id: tipDelay
                interval: 400
                onTriggered: tip.shown = true
            }

            Tooltip {
                id: tip
                target: item
                text: item.modelData.tooltipTitle
            }
        }
    }
}
