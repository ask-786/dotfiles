import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

// One chat in an expanded notification group. A lone message is its own
// card; more make one card like Android's conversations: the picture, the
// chat's name and count, and the latest three messages (oldest at the top)
// with the rest behind "Show N earlier". Clicking it opens the latest
// message and clears the chat; × just clears it.
Item {
    id: root

    required property string threadKey

    readonly property var thread: Notifs.threadByKey[threadKey] ?? null
    readonly property int count: thread?.items.length ?? 0
    readonly property bool single: count === 1
    readonly property bool all: Notifs.showAll[threadKey] === true
    readonly property int shown: all ? count : Math.min(count, 3)
    readonly property var latest: thread?.latest ?? null
    readonly property bool critical: latest?.urgency === NotificationUrgency.Critical
    readonly property string iconSource: Notifs.iconSource(latest)

    implicitHeight: single ? lone.implicitHeight : card.implicitHeight

    SystemClock {
        id: clock
        enabled: !Sleep.sleeping // re-read the time on wake
        precision: SystemClock.Minutes
    }

    Loader {
        id: lone

        width: parent.width
        active: root.single

        sourceComponent: NotificationCard {
            notification: root.latest
            showApp: false
        }
    }

    Rectangle {
        id: card

        visible: !root.single
        width: parent.width
        implicitHeight: Math.max(content.implicitHeight, iconBox.height) + 2 * Theme.padding
        radius: Theme.radius
        color: root.critical ? Theme.criticalBg : Theme.surface
        border.width: 1
        border.color: root.critical ? Theme.urgentBorder : Theme.border

        StateLayer {
            onClicked: if (root.thread) Notifs.activateThread(root.thread)
        }

        Item {
            id: iconBox

            x: Theme.padding
            y: Theme.padding
            width: 36
            height: 36

            IconImage {
                id: image

                anchors.fill: parent
                source: root.iconSource
                visible: root.iconSource !== "" && status === Image.Ready
                asynchronous: true
                mipmap: true
            }

            Icon {
                anchors.centerIn: parent
                visible: !image.visible
                text: Icons.bell
                size: 24
                color: Theme.fgDim
            }
        }

        Column {
            id: content

            anchors.left: iconBox.right
            anchors.leftMargin: Theme.padding
            anchors.right: close.left
            anchors.rightMargin: 4
            y: Theme.padding
            spacing: 3

            StyledText {
                width: parent.width
                text: `${root.count} messages · ${Notifs.age(root.latest, clock.date.getTime())}`
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSize - 2
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.thread?.title ?? ""
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            StyledText {
                visible: root.count > 3
                height: 22
                text: root.all ? "Show fewer" : `Show ${root.count - 3} earlier`
                color: earlier.containsMouse ? Theme.fg : Theme.fgMuted
                font.pixelSize: Theme.fontSize - 2

                MouseArea {
                    id: earlier

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.toggleShowAll(root.threadKey)
                }
            }

            Repeater {
                // Oldest at the top, like a chat.
                model: (root.thread?.items ?? []).slice(0, root.shown).reverse()

                StyledText {
                    required property var modelData
                    required property int index

                    width: content.width
                    text: Notifs.body(modelData) || modelData.summary
                    textFormat: Text.StyledText
                    color: index === root.shown - 1 ? Theme.fg : Theme.fgDim
                    linkColor: Theme.accent
                    font.pixelSize: Theme.fontSize - 1
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            Flow {
                width: parent.width
                spacing: 6
                topPadding: 6
                visible: actions.count > 0

                Repeater {
                    id: actions

                    model: Array.prototype.filter.call(root.latest?.actions ?? [], a => a.identifier !== "default")

                    TextButton {
                        required property var modelData

                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
        }

        IconButton {
            id: close

            anchors.right: parent.right
            anchors.rightMargin: 6
            y: 6
            size: 24
            icon: Icons.close
            idleColor: "transparent"
            onClicked: if (root.thread) Notifs.dismissThread(root.thread)
        }
    }
}
