import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services

// Now playing: art, track info, seekable progress, transport controls and a
// switcher when several players are open. Opens on its own or stacked on
// top of quick settings / the calendar (shell.qml sets the lift).
Drawer {
    id: root

    name: "media"
    align: Qt.AlignRight
    contentWidth: 400

    readonly property var player: Media.player

    Column {
        width: parent.width
        spacing: 14

        StyledText {
            width: parent.width
            visible: !Media.hasTrack
            height: 60
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing playing"
            color: Theme.fgDim
        }

        // Art + track info
        Row {
            width: parent.width
            spacing: 14
            visible: Media.hasTrack

            Rectangle {
                id: art

                width: 96
                height: 96
                radius: Theme.radius
                color: Theme.surfaceHigh
                border.width: 1
                border.color: Theme.border
                clip: true

                Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: Icons.music
                    size: 36
                    color: Theme.fgMuted
                }

                Image {
                    id: cover

                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 192
                    sourceSize.height: 192
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.normal }
                    }
                }
            }

            Column {
                width: parent.width - art.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                StyledText {
                    width: parent.width
                    text: Media.title
                    font.bold: true
                    font.pixelSize: Theme.fontSize + 2
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: Media.artist
                    color: Theme.fgDim
                }
                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: root.player?.trackAlbum ?? ""
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSize - 2
                }
                StyledText {
                    width: parent.width
                    text: root.player?.identity ?? ""
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSize - 2
                    topPadding: 4
                }
            }
        }

        // Progress (click/drag to seek when the player allows it)
        Column {
            width: parent.width
            spacing: 6
            visible: Media.hasTrack && (root.player?.lengthSupported ?? false) && root.player.length > 0

            Item {
                id: bar

                readonly property real fraction: root.player && root.player.length > 0
                    ? Math.min(1, root.player.position / root.player.length) : 0
                readonly property real shown: seek.pressed ? seek.dragFraction : fraction

                width: parent.width
                height: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: Theme.radius
                    color: Theme.surfaceHigh

                    Rectangle {
                        width: parent.width * bar.shown
                        height: parent.height
                        radius: Theme.radius
                        color: Theme.fgDim

                        Behavior on width {
                            enabled: !seek.pressed
                            NumberAnimation { duration: 900; easing.type: Easing.Linear }
                        }
                    }
                }

                Rectangle {
                    x: parent.width * bar.shown - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: Theme.radius
                    color: Theme.fg
                    visible: root.player?.canSeek ?? false
                    opacity: seek.containsMouse || seek.pressed ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.fast }
                    }
                }

                MouseArea {
                    id: seek

                    property real dragFraction: 0

                    anchors.fill: parent
                    enabled: root.player?.canSeek ?? false
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: event => dragFraction = Math.max(0, Math.min(1, event.x / width))
                    onPositionChanged: event => {
                        if (pressed)
                            dragFraction = Math.max(0, Math.min(1, event.x / width));
                    }
                    onReleased: root.player.position = dragFraction * root.player.length
                }
            }

            Item {
                width: parent.width
                height: 16

                StyledText {
                    text: Media.formatTime(seek.pressed ? seek.dragFraction * (root.player?.length ?? 0) : (root.player?.position ?? 0))
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 2
                }
                StyledText {
                    anchors.right: parent.right
                    text: Media.formatTime(root.player?.length ?? 0)
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }

        // Transport controls
        Item {
            width: parent.width
            height: 48
            visible: Media.hasTrack

            IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.player?.shuffleSupported ?? false
                size: 32
                icon: root.player?.shuffle ? Icons.shuffle : Icons.shuffleOff
                active: root.player?.shuffle ?? false
                onClicked: root.player.shuffle = !root.player.shuffle
            }

            Row {
                anchors.centerIn: parent
                spacing: 14

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.previous
                    size: 38
                    enabled: root.player?.canGoPrevious ?? false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.player.previous()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Media.playing ? Icons.pause : Icons.play
                    size: 48
                    active: true
                    onClicked: root.player.togglePlaying()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.next
                    size: 38
                    enabled: root.player?.canGoNext ?? false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.player.next()
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.player?.loopSupported ?? false
                size: 32
                icon: root.player?.loopState === MprisLoopState.Track ? Icons.repeatOnce
                    : root.player?.loopState === MprisLoopState.Playlist ? Icons.repeat
                    : Icons.repeatOff
                active: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: {
                    const order = [MprisLoopState.None, MprisLoopState.Playlist, MprisLoopState.Track];
                    root.player.loopState = order[(order.indexOf(root.player.loopState) + 1) % order.length];
                }
            }
        }

        // Player switcher
        Flow {
            width: parent.width
            spacing: 6
            visible: Media.players.length > 1

            Repeater {
                model: ScriptModel {
                    values: Media.players
                }

                TextButton {
                    required property var modelData

                    implicitHeight: 28
                    text: modelData.identity || modelData.dbusName
                    icon: modelData.isPlaying ? Icons.play : ""
                    color: modelData === root.player ? Theme.primary : Theme.surface
                    onClicked: Media.pick(modelData)
                }
            }
        }
    }
}
