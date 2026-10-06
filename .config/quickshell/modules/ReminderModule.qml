import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// An alarm clock while reminders are set, with a countdown once the next
// one is under an hour away (or is a running timer). Opens the calendar
// drawer, where they're listed.
BarModule {
    id: root

    required property string screenName

    readonly property var next: Reminders.next
    readonly property real remaining: next ? next.due - clock.date.getTime() : -1

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    visible: Reminders.items.length > 0
    text: remaining >= 0 && (remaining < 3600000 || next.duration) ? `${Icons.alarm} ${Reminders.countdown(remaining)}` : Icons.alarm
    tooltip: next ? `${next.text} · ${Reminders.describe(next, clock.date)}` : ""

    onClicked: Panels.toggle("calendar", screenName)
}
