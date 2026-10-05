import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.modules

// Same look as the old waybar, trimmed to the basics. Click a module for
// details: volume → sound, network → Wi-Fi, bluetooth → devices, battery →
// quick settings, clock → calendar, menu icon (far right) → quick settings,
// now playing (left, after workspaces) → media.
PanelWindow {
    id: bar

    readonly property string screenName: screen?.name ?? ""

    anchors {
        left: true
        right: true
        bottom: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.bg
    WlrLayershell.namespace: "quickshell:bar"

    // Slides up and fades in when the shell starts or reloads.
    Item {
        id: content

        width: parent.width
        height: parent.height

        ParallelAnimation {
            running: true
            NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: Theme.slow }
            NumberAnimation { target: content; property: "y"; from: 10; to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
            }

            MediaModule {
                anchors.verticalCenter: parent.verticalCenter
                screenName: bar.screenName
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing / 2

            VolumeModule { screenName: bar.screenName }
            Separator {}
            NetworkModule { screenName: bar.screenName }
            Separator { visible: btModule.visible }
            BluetoothModule {
                id: btModule
                screenName: bar.screenName
            }
            Separator { visible: batteryModule.visible }
            BatteryModule {
                id: batteryModule
                screenName: bar.screenName
            }
            Separator { visible: totemModule.visible }
            TotemModule { id: totemModule }
            Separator {}
            ClockModule { screenName: bar.screenName }

            Tray {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 6
                rightPadding: 6
            }

            MenuModule { screenName: bar.screenName }
        }
    }
}
