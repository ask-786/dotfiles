import QtQuick
import qs
import qs.services

// A timer: big countdown, progress, pause / reset / remove. The calendar
// drawer and the lock screen pass `now` from their own SystemClock.
Rectangle {
    id: card

    required property var r
    required property real now
    readonly property real remaining: Reminders.remainingOf(r, now)
    readonly property bool paused: r.paused === true

    height: 82
    radius: Theme.radius
    color: Theme.surface

    Icon {
        x: 12
        y: 12
        text: Icons.timer
        size: 16
        color: card.paused ? Theme.fgMuted : Theme.accent
    }

    StyledText {
        x: 36
        y: 10
        width: buttons.x - x - 8
        text: Reminders.title(card.r)
        color: Theme.fgDim
        font.pixelSize: Theme.fontSize - 1
    }

    Row {
        id: buttons

        anchors.right: parent.right
        anchors.rightMargin: 6
        y: 6
        spacing: 2

        IconButton {
            size: 28
            icon: card.paused ? Icons.play : Icons.pause
            idleColor: "transparent"
            onClicked: card.paused ? Reminders.resumeTimer(card.r.id) : Reminders.pauseTimer(card.r.id)
        }
        IconButton {
            size: 28
            icon: Icons.restart
            idleColor: "transparent"
            onClicked: Reminders.resetTimer(card.r.id)
        }
        IconButton {
            size: 28
            icon: Icons.close
            idleColor: "transparent"
            onClicked: Reminders.remove(card.r.id)
        }
    }

    StyledText {
        id: countdown

        x: 36
        y: 32
        text: Reminders.clockText(card.remaining)
        color: card.paused ? Theme.fgDim : Theme.fg
        font.pixelSize: 24
        font.bold: true
    }

    StyledText {
        anchors.left: countdown.right
        anchors.leftMargin: 10
        anchors.baseline: countdown.baseline
        text: card.paused ? (card.remaining === card.r.duration ? "Ready" : "Paused")
            : `ends ${Qt.formatTime(new Date(card.r.due), "hh:mm AP")}`
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSize - 2
    }

    Rectangle {
        x: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: parent.width - 24
        height: 4
        radius: 2
        color: Theme.surfaceHigh

        Rectangle {
            width: parent.width * Math.min(1, card.remaining / card.r.duration)
            height: parent.height
            radius: 2
            color: card.paused ? Theme.fgMuted : Theme.accent

            Behavior on width {
                NumberAnimation { duration: Theme.normal }
            }
        }
    }
}
