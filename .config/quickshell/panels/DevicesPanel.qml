import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Accessories: Totem keyboard halves, Galaxy Buds (per bud + case) and any
// other connected Bluetooth device with a battery. Toggled from quick
// settings or SUPER+B; stacks on top of the open drawer like media does.
Drawer {
    id: root

    // Bluetooth devices without a card of their own; Galaxy Buds land here
    // while GalaxyBudsClient isn't running.
    readonly property var others: Bt.connected.filter(d => !(Buds.present && d.address === Buds.address)
        && (Bt.battery(d) >= 0 || /Galaxy Buds/.test(d.name)))

    name: "devices"
    align: Qt.AlignRight
    contentWidth: 400

    Column {
        width: parent.width
        spacing: 10

        StyledText {
            width: parent.width
            height: 40
            visible: !Totem.present && !Buds.present && root.others.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "No devices connected"
            color: Theme.fgMuted
        }

        // Totem keyboard halves (only while connected)
        Card {
            visible: Totem.present

            Item {
                width: parent.width
                height: 18

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Icon { text: Icons.keyboard; size: 16 }
                    StyledText { text: "Totem keyboard"; font.bold: true }
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: [Totem.left, Totem.right].every(h => h.present) ? "Both halves connected" : "One half connected"
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            Grid {
                id: totemGrid

                readonly property real cellWidth: (width - columnSpacing) / 2

                width: parent.width
                columns: 2
                columnSpacing: 16

                Repeater {
                    model: [{ name: "Left", half: Totem.left }, { name: "Right", half: Totem.right }]

                    StatBar {
                        required property var modelData
                        readonly property var half: modelData.half

                        width: totemGrid.cellWidth
                        icon: !half.present ? Icons.close
                            : half.status === "Charging" ? Icons.batteryCharging
                            : Icons.level(Icons.batteryLevels, half.capacity / 100)
                        label: modelData.name
                        value: !half.present ? "off"
                             : half.status === "Charging" ? `${half.capacity}% ⚡`
                             : half.status === "Full" ? "Full"
                             : `${half.capacity}%`
                        fraction: half.present ? half.capacity / 100 : 0
                        warn: half.present && half.capacity < 20 && half.status !== "Charging"
                    }
                }
            }
        }

        // Galaxy Buds per bud and case (via GalaxyBudsClient)
        Card {
            id: budsCard

            readonly property var wearText: ({ Wearing: "in ear", Idle: "out", Case: "in case", ClosedCase: "case closed", Disconnected: "off" })

            visible: Buds.present

            Item {
                width: parent.width
                height: 30

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.headphones
                        size: 16
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText { text: Buds.name; font.bold: true }
                        StyledText {
                            text: Buds.wearLeft === Buds.wearRight ? `Both ${budsCard.wearText[Buds.wearLeft] ?? ""}`
                                : `L ${budsCard.wearText[Buds.wearLeft] ?? "?"} · R ${budsCard.wearText[Buds.wearRight] ?? "?"}`
                            color: Theme.fgMuted
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Beeps until pressed again.
                    IconButton {
                        size: 30
                        icon: Icons.bellRing
                        active: Buds.finding
                        onClicked: Buds.toggleFind()
                    }

                    IconButton {
                        size: 30
                        icon: Icons.cog
                        onClicked: {
                            Panels.close();
                            Buds.openApp();
                        }
                    }
                }
            }

            Grid {
                id: budsGrid

                readonly property real cellWidth: (width - 2 * columnSpacing) / 3

                width: parent.width
                columns: 3
                columnSpacing: 16

                Repeater {
                    model: [{ name: "Left", level: Buds.left, wear: Buds.wearLeft },
                            { name: "Right", level: Buds.right, wear: Buds.wearRight }]

                    StatBar {
                        required property var modelData
                        readonly property bool on: modelData.wear !== "Disconnected" && modelData.level >= 0
                        readonly property bool charging: modelData.wear === "Case" && modelData.level < 100

                        width: budsGrid.cellWidth
                        icon: !on ? Icons.close
                            : charging ? Icons.batteryCharging
                            : Icons.level(Icons.batteryLevels, modelData.level / 100)
                        label: modelData.name
                        value: !on ? "off" : charging ? `${modelData.level}% ⚡` : `${modelData.level}%`
                        fraction: on ? modelData.level / 100 : 0
                        warn: on && modelData.level < 20 && !charging
                    }
                }

                // The case only reports with a bud inside and the lid
                // open; otherwise show the last reading, marked with "~".
                StatBar {
                    width: budsGrid.cellWidth
                    icon: Buds.caseLevel < 0 ? Icons.close : Icons.level(Icons.batteryLevels, Buds.caseLevel / 100)
                    label: "Case"
                    value: Buds.caseLevel < 0 ? "?" : `${Buds.caseFresh ? "" : "~"}${Buds.caseLevel}%`
                    fraction: Math.max(0, Buds.caseLevel) / 100
                    warn: Buds.caseFresh && Buds.caseLevel < 20
                }
            }
        }

        // Other Bluetooth devices: the single level BlueZ reports. For Galaxy
        // Buds the gear starts GalaxyBudsClient for the per-bud view.
        Repeater {
            model: root.others

            Card {
                id: other

                required property var modelData
                readonly property int battery: Bt.battery(modelData)
                readonly property bool isBuds: /Galaxy Buds/.test(modelData.name)

                Item {
                    width: parent.width
                    height: other.isBuds ? 30 : 18

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Icon { text: Icons.forDevice(other.modelData.icon ?? ""); size: 16 }
                        StyledText { text: other.modelData.name; font.bold: true }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: other.battery >= 0
                            text: `${other.battery}%`
                            color: Bt.isLow(other.modelData) ? Theme.red : Theme.fg
                            font.pixelSize: Theme.fontSize - 1
                        }

                        IconButton {
                            visible: other.isBuds
                            size: 30
                            icon: Icons.cog
                            onClicked: {
                                Panels.close();
                                Buds.openApp();
                            }
                        }
                    }
                }
            }
        }
    }

    // Rounded surface with padding, like the quick settings cards.
    component Card: Rectangle {
        default property alias content: cardColumn.data

        width: parent?.width ?? 0
        height: cardColumn.implicitHeight + 24
        radius: Theme.radius
        color: Theme.surface

        Column {
            id: cardColumn

            x: 14
            y: 12
            width: parent.width - 28
            spacing: 12
        }
    }
}
