import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Popups, top right: Bluetooth pairing questions (unless the Bluetooth page
// is open to show them), fired reminders (with Snooze / Done, until dealt
// with) and prayer times (Stop for the adhan, Done), then notifications,
// newest first in each. Over fullscreen windows too, on the focused monitor.
PanelWindow {
    id: root

    required property var bar

    readonly property bool pairing: Bt.request !== null && Bt.pageScreen === ""

    screen: bar.screen
    visible: (pairing || Reminders.alerts.length > 0 || Notifs.popups.length > 0) && Hyprland.focusedMonitor?.name === bar.screenName
    color: "transparent"

    anchors.top: true
    anchors.right: true
    margins.top: 50
    margins.right: 10

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:popups"
    // Only a PIN or passkey to type needs the keyboard.
    WlrLayershell.keyboardFocus: pairing && pairingPrompt.entry ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    implicitWidth: 360
    implicitHeight: Math.max(1, cards.implicitHeight)

    Column {
        id: cards

        width: parent.width
        spacing: Theme.spacing

        PairingPrompt {
            id: pairingPrompt

            width: cards.width
            visible: root.pairing
            popup: true
        }

        Repeater {
            model: ScriptModel {
                values: Reminders.alerts.slice().reverse()
            }

            AlertCard {
                required property var modelData

                width: cards.width
                alert: modelData

                NumberAnimation on opacity {
                    from: 0
                    to: 1
                    duration: Theme.normal
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: Notifs.popups.map(p => p.n).filter(n => n).reverse()
            }

            NotificationCard {
                required property var modelData

                width: cards.width
                notification: modelData
                popup: true

                NumberAnimation on opacity {
                    from: 0
                    to: 1
                    duration: Theme.normal
                }
            }
        }
    }
}
