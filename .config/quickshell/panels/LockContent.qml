import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// What one monitor shows while locked: the blurred screen, the clock and
// date above the password field (where hyprlock had them), and below it
// anything that needs you: fired reminders, what's playing, running timers
// and a one-line-each list of the latest notifications (no bodies or
// actions while locked). The battery sits bottom right, like the bar.
Item {
    id: root

    required property var screen
    readonly property var timers: Reminders.items.filter(r => r.duration)
    readonly property var notifications: Notifs.list.slice().reverse()
    readonly property int maxNotifications: 5
    readonly property int columnWidth: 400

    SystemClock {
        id: clock
        // Seconds only while a timer counts down.
        precision: root.timers.some(r => !r.paused) ? SystemClock.Seconds : SystemClock.Minutes
    }

    NumberAnimation on opacity {
        from: 0
        to: 1
        duration: Theme.normal
    }

    // ---------------------------------------------------------- background

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    // What was on screen when it locked (see Lock.shotDir), else the wallpaper.
    Image {
        id: shot

        anchors.fill: parent
        source: root.screen ? `file://${Lock.shotDir}/${root.screen.name}.ppm` : ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        visible: false
        // Kept in memory from here on; the file can go.
        // (`shot.status`: a bare `status` is the status line's id.)
        onStatusChanged: {
            if (root.screen && (shot.status === Image.Ready || shot.status === Image.Error))
                Lock.shotLoaded(root.screen.name);
        }
    }

    Image {
        id: wallpaper

        anchors.fill: parent
        source: shot.status === Image.Error && Lock.wallpaper ? `file://${Lock.wallpaper}` : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        sourceSize.height: height
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: shot.status === Image.Ready ? shot : wallpaper
        visible: shot.status === Image.Ready || wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    // --------------------------------------------------------- clock + date

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: field.top
        anchors.bottomMargin: 40
        spacing: 4

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "h:mm")
            font.pixelSize: 96
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dddd, MMMM d")
            color: Theme.fgDim
            font.pixelSize: 22
        }
    }

    // ------------------------------------------------------- password field

    Rectangle {
        id: field

        anchors.horizontalCenter: parent.horizontalCenter
        // A little above the middle, leaving room for the cards.
        y: Math.round(parent.height * 0.42 - height / 2)
        width: root.columnWidth
        height: 44
        radius: Theme.radius
        color: Theme.panelBg
        border.width: 1
        border.color: Lock.statusIsError ? Theme.urgentBorder : input.activeFocus ? Theme.panelBorder : Theme.border

        Behavior on border.color {
            ColorAnimation { duration: Theme.normal }
        }

        Icon {
            id: lockIcon

            x: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.lock
            size: 18
            color: Lock.statusIsError ? Theme.red : Theme.fgDim
        }

        TextInput {
            id: input

            anchors.left: lockIcon.right
            anchors.leftMargin: Theme.padding
            anchors.right: busy.left
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            clip: true
            echoMode: TextInput.Password
            passwordCharacter: "•"
            color: Theme.fg
            selectionColor: Theme.primary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            Component.onCompleted: forceActiveFocus()

            onAccepted: {
                Lock.submit(text);
                text = "";
            }
            Keys.onEscapePressed: text = ""

            StyledText {
                anchors.fill: parent
                visible: input.text === ""
                text: "Password"
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSize
            }
        }

        Icon {
            id: busy

            anchors.right: parent.right
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.refresh
            size: 18
            color: Theme.accent
            opacity: Lock.busy ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.fast }
            }

            RotationAnimation on rotation {
                running: Lock.busy
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1500
                onRunningChanged: if (!running) target.rotation = 0
            }
        }
    }

    StyledText {
        id: status

        anchors.top: field.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.columnWidth
        height: 20
        horizontalAlignment: Text.AlignHCenter
        text: Lock.status
        color: Lock.statusIsError ? Theme.red : Theme.fgDim
        font.pixelSize: Theme.fontSize - 1
    }

    // ---------------------------------------------------------------- cards

    // Scrolls when there's more than fits.
    Flickable {
        anchors.top: status.bottom
        anchors.topMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.columnWidth
        clip: true
        contentHeight: cards.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: cards

            width: parent.width
            spacing: Theme.spacing

            Repeater {
                model: ScriptModel {
                    values: Reminders.alerts.slice().reverse()
                }

                AlertCard {
                    required property var modelData

                    width: parent.width
                    alert: modelData
                }
            }

            MediaCard {
                width: parent.width
                visible: Media.hasTrack
            }

            Repeater {
                model: ScriptModel {
                    objectProp: "id"
                    values: root.timers
                }

                TimerCard {
                    required property var modelData

                    width: parent.width
                    r: modelData
                    now: clock.date.getTime()
                    color: Theme.panelBg
                    border.width: 1
                    border.color: Theme.panelBorder
                }
            }

            NotificationList {
                width: parent.width
                visible: root.notifications.length > 0
            }
        }
    }

    // ------------------------------------------------------------- battery

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.padding
        visible: Battery.available
        width: batteryRow.implicitWidth + 2 * Theme.padding
        height: Theme.barHeight
        radius: Theme.radius
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        Row {
            id: batteryRow

            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.icon
                size: 16
                color: Battery.low ? Theme.red : Battery.charging ? Theme.green : Theme.fg
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Battery.percent}%`
                color: Battery.low ? Theme.red : Theme.fg
            }
        }
    }

    // ------------------------------------------------------------ media card

    // Art, title and artist, previous / play-pause / next.
    component MediaCard: Rectangle {
        id: mediaCard

        readonly property var player: Media.player

        height: 80
        radius: Theme.radius
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.panelBorder

        ClippingRectangle {
            id: art

            x: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            height: 56
            radius: Theme.radius
            color: Theme.surfaceHigh

            Icon {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: Icons.music
                size: 24
                color: Theme.fgMuted
            }

            Image {
                id: cover

                anchors.fill: parent
                source: mediaCard.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 112
                sourceSize.height: 112
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: Theme.padding
            anchors.right: controls.left
            anchors.rightMargin: Theme.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            StyledText {
                width: parent.width
                text: Media.title
                font.bold: true
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                text: Media.artist
                color: Theme.fgDim
                font.pixelSize: Theme.fontSize - 1
            }
            StyledText {
                width: parent.width
                text: mediaCard.player?.identity ?? ""
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 30
                icon: Icons.previous
                idleColor: "transparent"
                enabled: mediaCard.player?.canGoPrevious ?? false
                opacity: enabled ? 1 : 0.4
                onClicked: mediaCard.player.previous()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 38
                icon: Media.playing ? Icons.pause : Icons.play
                active: true
                onClicked: mediaCard.player.togglePlaying()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 30
                icon: Icons.next
                idleColor: "transparent"
                enabled: mediaCard.player?.canGoNext ?? false
                opacity: enabled ? 1 : 0.4
                onClicked: mediaCard.player.next()
            }
        }
    }

    // ----------------------------------------------------- notification list

    // One panel, one line per notification: icon, app, summary, age.
    component NotificationList: Rectangle {
        height: list.implicitHeight
        radius: Theme.radius
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.panelBorder

        Column {
            id: list

            width: parent.width
            topPadding: 4
            bottomPadding: 4

            Repeater {
                model: ScriptModel {
                    values: root.notifications.slice(0, root.maxNotifications)
                }

                Item {
                    id: line

                    required property var modelData
                    required property int index
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                    width: list.width
                    height: 36

                    Rectangle {
                        visible: line.index > 0
                        x: Theme.padding
                        width: parent.width - 2 * Theme.padding
                        height: 1
                        color: Theme.border
                    }

                    Item {
                        id: lineIcon

                        x: Theme.padding
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20

                        IconImage {
                            id: lineImage

                            anchors.fill: parent
                            source: Notifs.iconSource(line.modelData)
                            visible: source !== "" && status === Image.Ready
                            asynchronous: true
                            mipmap: true
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !lineImage.visible
                            text: Icons.bell
                            size: 16
                            color: line.critical ? Theme.red : Theme.fgDim
                        }
                    }

                    StyledText {
                        id: app

                        anchors.left: lineIcon.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 110)
                        text: line.modelData.appName ?? ""
                        color: line.critical ? Theme.red : Theme.fgMuted
                        font.pixelSize: Theme.fontSize - 1
                    }

                    StyledText {
                        anchors.left: app.right
                        anchors.leftMargin: app.text ? 10 : 0
                        anchors.right: age.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.summary || line.modelData.body || ""
                        textFormat: Text.PlainText
                    }

                    StyledText {
                        id: age

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.padding
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.age(line.modelData, clock.date.getTime())
                        color: Theme.fgMuted
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            StyledText {
                visible: root.notifications.length > root.maxNotifications
                x: Theme.padding
                width: list.width - 2 * Theme.padding
                height: 28
                text: `+${root.notifications.length - root.maxNotifications} more`
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
