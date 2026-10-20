import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services

// One app's notifications in the history (one site's, for browsers), like
// Android's groups: a header with the app, count and age, then a line per
// chat while collapsed, or each chat's card (NotificationThread) once
// expanded. Clicking a collapsed group, or an expanded one's header, toggles
// it; × clears the whole group. A lone notification is just its card.
Item {
    id: root

    required property string groupKey

    readonly property var group: Notifs.groupByKey[groupKey] ?? null
    readonly property bool single: (group?.count ?? 0) === 1
    readonly property bool expanded: Notifs.expanded[groupKey] === true
    // Chats listed while collapsed.
    readonly property int maxLines: 3

    implicitHeight: single ? lone.implicitHeight : box.implicitHeight

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
            notification: root.group?.latest ?? null
        }
    }

    Rectangle {
        id: box

        visible: !root.single
        width: parent.width
        implicitHeight: header.height + body.height + 6
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        StateLayer {
            enabled: !root.expanded
            onClicked: Notifs.toggleGroup(root.groupKey)
        }

        Item {
            id: header

            width: parent.width
            height: 40

            StateLayer {
                enabled: root.expanded
                onClicked: Notifs.toggleGroup(root.groupKey)
            }

            Item {
                id: appIcon

                x: Theme.padding
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20

                IconImage {
                    id: appImage

                    anchors.fill: parent
                    source: root.group?.icon ?? ""
                    visible: source !== "" && status === Image.Ready
                    asynchronous: true
                    mipmap: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: !appImage.visible
                    text: Icons.bell
                    size: 16
                    color: Theme.fgDim
                }
            }

            StyledText {
                id: appName

                anchors.left: appIcon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - 200)
                text: root.group?.label ?? ""
                font.bold: true
            }

            StyledText {
                anchors.left: appName.right
                anchors.right: tools.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: ` · ${root.group?.count ?? 0} · ${Notifs.age(root.group?.latest, clock.date.getTime())}`
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSize - 2
            }

            Row {
                id: tools

                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    text: root.expanded ? Icons.chevronUp : Icons.chevronDown
                    size: 16
                    color: Theme.fgDim
                }

                IconButton {
                    size: 24
                    icon: Icons.close
                    idleColor: "transparent"
                    onClicked: if (root.group) Notifs.dismissGroup(root.group)
                }
            }
        }

        // Clipped so expanding and collapsing slide.
        Item {
            id: body

            y: header.height
            width: parent.width
            height: root.expanded ? threads.implicitHeight : lines.implicitHeight
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
            }

            // Collapsed: a line per chat, newest first.
            Column {
                id: lines

                visible: !root.expanded
                width: parent.width

                Repeater {
                    model: ScriptModel {
                        values: (root.group?.threads ?? []).slice(0, root.maxLines).map(t => t.key)
                    }

                    ThreadLine {
                        required property string modelData

                        width: lines.width
                        thread: Notifs.threadByKey[modelData] ?? null
                    }
                }

                StyledText {
                    readonly property int more: (root.group?.threads.length ?? 0) - root.maxLines

                    visible: more > 0
                    x: Theme.padding + 32
                    height: 24
                    text: `+${more} more`
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            // Expanded: each chat's card.
            Column {
                id: threads

                visible: root.expanded
                x: 6
                width: parent.width - 12
                spacing: 6

                Repeater {
                    model: ScriptModel {
                        values: root.expanded ? (root.group?.threads ?? []).map(t => t.key) : []
                    }

                    NotificationThread {
                        required property string modelData

                        width: threads.width
                        threadKey: modelData
                    }
                }
            }
        }
    }

    // One chat on one line: picture, name and count, then its latest message.
    component ThreadLine: Item {
        id: line

        required property var thread
        readonly property int count: thread?.items.length ?? 0

        height: 28

        Item {
            id: avatar

            x: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20

            IconImage {
                id: avatarImage

                anchors.fill: parent
                source: Notifs.iconSource(line.thread?.latest)
                visible: source !== "" && status === Image.Ready
                asynchronous: true
                mipmap: true
            }

            Icon {
                anchors.centerIn: parent
                visible: !avatarImage.visible
                text: Icons.bell
                size: 14
                color: Theme.fgMuted
            }
        }

        StyledText {
            id: name

            anchors.left: avatar.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 140)
            visible: text !== ""
            text: line.thread?.title ?? ""
            font.bold: true
            font.pixelSize: Theme.fontSize - 1
        }

        StyledText {
            id: count

            anchors.left: name.visible ? name.right : avatar.right
            anchors.leftMargin: name.visible ? 6 : 10
            anchors.verticalCenter: parent.verticalCenter
            visible: line.count > 1
            text: line.count
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSize - 2
        }

        StyledText {
            anchors.left: count.visible ? count.right : name.visible ? name.right : avatar.right
            anchors.leftMargin: count.visible || name.visible ? 8 : 10
            anchors.right: parent.right
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            text: Notifs.plainBody(line.thread?.latest) || (line.thread?.latest?.summary ?? "")
            textFormat: Text.PlainText
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
