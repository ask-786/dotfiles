import QtQuick
import qs
import qs.services

// A question from the Bluetooth pairing agent (Bt.request): a code to type
// on the device, a code to compare, a PIN to enter, or a yes/no. Shown on
// the Bluetooth page, or as a popup (`popup`) while that's closed.
Rectangle {
    id: root

    property bool popup: false

    readonly property var req: Bt.request
    readonly property string kind: req?.kind ?? ""
    readonly property string device: req?.name || req?.address || "the device"
    readonly property bool entry: kind === "pin" || kind === "passkey"
    readonly property bool showCode: kind === "display" || kind === "confirm"

    // A few service UUIDs (0000xxxx-0000-1000-8000-00805f9b34fb) by name.
    readonly property var services: ({
        "110a": "audio", "110b": "audio", "110c": "media controls", "110e": "media controls",
        "1105": "file transfer", "1106": "file transfer", "1112": "calls", "111f": "calls",
        "1116": "networking", "1124": "keyboard or mouse input", "112f": "contacts", "1132": "messages"
    })

    function submit() {
        if (entry && field.text === "")
            return;
        Bt.answer(true, field.text);
        field.text = "";
    }

    implicitHeight: content.implicitHeight + 2 * Theme.padding
    radius: Theme.radius
    color: popup ? Theme.panelBg : Theme.surface
    border.width: 1
    border.color: popup ? Theme.panelBorder : Theme.border

    Icon {
        id: icon

        x: Theme.padding
        y: Theme.padding
        text: Icons.bluetooth
        size: 22
        color: Theme.accent
    }

    Column {
        id: content

        anchors.left: icon.right
        anchors.leftMargin: Theme.padding
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        y: Theme.padding
        spacing: 6

        StyledText {
            width: parent.width
            text: root.kind === "service" ? root.device : `Pair with ${root.device}`
            font.bold: true
            wrapMode: Text.Wrap
        }

        StyledText {
            width: parent.width
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
            text: root.kind === "display" ? `Type this code on ${root.device}, then press Enter.`
                : root.kind === "confirm" ? `Check that ${root.device} shows the same code.`
                : root.kind === "authorize" ? `${root.device} wants to pair with no code.`
                : root.kind === "service" ? `Wants to use ${root.services[(root.req?.uuid ?? "").slice(4, 8)] ?? "a Bluetooth service"}.`
                : root.kind === "pin" ? "Enter the PIN from the device or its manual (often 0000)."
                : root.kind === "passkey" ? "Enter the 6-digit code shown on the device." : ""
        }

        // The code, typed digits in green as the keyboard reports them.
        Row {
            visible: root.showCode
            topPadding: 4
            bottomPadding: 4
            spacing: 6

            Repeater {
                model: root.showCode ? (root.req?.code ?? "").split("") : []

                StyledText {
                    required property string modelData
                    required property int index

                    text: modelData
                    font.pixelSize: 26
                    font.bold: true
                    color: index < (root.req?.entered ?? 0) ? Theme.accent : Theme.fg
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 42
            visible: root.entry
            radius: Theme.radius
            color: Theme.surfaceHigh

            onVisibleChanged: if (visible) field.forceActiveFocus()

            TextInput {
                id: field

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
                selectionColor: Theme.primary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                maximumLength: root.kind === "passkey" ? 6 : 16
                validator: RegularExpressionValidator {
                    regularExpression: root.kind === "passkey" ? /[0-9]*/ : /.*/
                }
                clip: true
                onAccepted: root.submit()

                StyledText {
                    visible: field.text === ""
                    text: root.kind === "passkey" ? "Code" : "PIN"
                    color: Theme.fgMuted
                }
            }
        }

        Row {
            anchors.right: parent.right
            topPadding: 4
            spacing: 6

            TextButton {
                text: root.kind === "service" ? "Deny" : "Cancel"
                onClicked: Bt.answer(false)
            }
            TextButton {
                visible: root.kind !== "display"
                icon: Icons.check
                text: root.kind === "service" ? "Allow" : "Pair"
                fg: Theme.accent
                onClicked: root.submit()
            }
        }
    }
}
