import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Reminders and timers on top, clock and month calendar at the bottom next
// to the bar. The reminders fold away behind their header row (which sits
// right above the calendar, so opening them grows the drawer upwards).
// SUPER+R (`qs ipc call drawer page calendar reminders`) opens it straight
// on a new reminder. Presets start a timer in one click; the form builds a
// labelled timer, a one-off on a day picked in the calendar, or a daily /
// weekdays / weekly repeat, with pickers that open from compact rows.
// Today's prayer times sit between the date and the month, with the switch
// that turns them off and the location they're for (a city search, or a
// Detect button that guesses from the IP address; either is only used once
// it's clicked).
Drawer {
    id: root

    name: "calendar"
    align: Qt.AlignRight
    contentWidth: 320

    property bool showReminders: false // kept between opens
    property bool composing: false
    property string editing: "" // id of the reminder being edited
    property string picking: "" // open picker: "" | "time" | "duration"

    // The form; the spinners hold the times.
    property int kind: 1 // 0 = timer, 1 = once, 2 = repeat
    property int repeatKind: 0 // index into `repeats`
    property int weekday: 1 // for weekly, 0 = Sunday
    property date day: new Date() // for once
    property bool pm: false
    readonly property var repeats: ["daily", "weekdays", "weekly"]
    readonly property var presets: [5, 10, 15, 30, 60] // timer minutes
    readonly property var presetLabels: presets.map(m => m < 60 ? `${m}m` : `${m / 60}h`)

    readonly property string todayKey: Prayer.dayKey(clock.date)
    readonly property var prayers: Prayer.timesOn(todayKey)
    readonly property var nextPrayer: Prayer.enabled ? Prayer.nextAfter(clock.date.getTime()) : null
    property bool locating: false // the location search is open
    property var places: [] // its results
    property string placesNote: "" // "Searching…", "No matches", ...

    readonly property int durationMinutes: timerHours.value * 60 + timerMinutes.value
    readonly property int hour24: hour.value % 12 + (pm ? 12 : 0)

    // What the form would add, re-evaluated every second.
    readonly property var draft: {
        const now = clock.date.getTime();
        const text = what.text.trim();
        if (kind === 0) {
            const duration = durationMinutes * 60000;
            return { text, due: now + duration, duration, repeat: "", error: duration > 0 ? "" : "Set how long" };
        }
        let due;
        if (kind === 1) {
            due = new Date(day.getFullYear(), day.getMonth(), day.getDate(), hour24, minute.value).getTime();
        } else {
            const d = new Date(now);
            d.setHours(hour24, minute.value, 0, 0);
            if (repeatKind === 2)
                d.setDate(d.getDate() + (weekday - d.getDay() + 7) % 7);
            due = Reminders.upcoming(d.getTime(), repeats[repeatKind], now);
        }
        const error = text === "" ? "Remind you of what?" : kind === 1 && due <= now ? "That time has passed" : "";
        return { text, due, repeat: kind === 2 ? repeats[repeatKind] : "", error };
    }

    // Opens the form, on `entry` to edit it or empty for a new one.
    function compose(entry) {
        showReminders = true;
        composing = true;
        picking = "";
        editing = entry?.id ?? "";
        what.text = entry?.text ?? "";
        if (entry) {
            kind = entry.duration ? 0 : entry.repeat ? 2 : 1;
            repeatKind = Math.max(0, repeats.indexOf(entry.repeat));
        }
        // New ones start on the next quarter hour at least 5 min away.
        const t = entry && !entry.duration ? new Date(entry.due)
                : new Date(Math.ceil((Date.now() + 5 * 60000) / 900000) * 900000);
        hour.value = t.getHours() % 12 || 12;
        minute.value = t.getMinutes();
        pm = t.getHours() >= 12;
        day = t;
        weekday = t.getDay();
        const mins = entry?.duration ? Math.round(entry.duration / 60000) : 10;
        timerHours.value = Math.floor(mins / 60);
        timerMinutes.value = mins % 60;
        Qt.callLater(() => what.forceActiveFocus());
    }

    function closeForm() {
        composing = false;
        editing = "";
        picking = "";
    }

    function submit() {
        const r = Object.assign({}, draft);
        if (r.error)
            return;
        if (r.duration)
            r.due = Date.now() + r.duration;
        if (editing)
            Reminders.replace(editing, r);
        else
            Reminders.add(r);
        closeForm();
    }

    // One click, like a phone: starts right away, with the form's label if
    // it's open.
    function startTimer(minutes) {
        const r = { text: composing ? what.text.trim() : "", due: Date.now() + minutes * 60000, duration: minutes * 60000 };
        if (editing)
            Reminders.replace(editing, r);
        else
            Reminders.add(r);
        closeForm();
    }

    function openLocating() {
        locating = true;
        places = [];
        placesNote = "";
        placeQuery.text = "";
        Qt.callLater(() => placeQuery.forceActiveFocus());
    }

    function findPlaces() {
        const q = placeQuery.text.trim();
        if (q.length < 2) {
            places = [];
            placesNote = "";
            return;
        }
        placesNote = "Searching…";
        Prayer.search(q, list => {
            if (q !== placeQuery.text.trim())
                return; // typed on meanwhile
            places = list ?? [];
            placesNote = list === null ? "Couldn't reach the search" : list.length ? "" : "No matches";
        });
    }

    function detectPlace() {
        placesNote = "Detecting…";
        Prayer.detect(p => {
            places = p ? [p] : [];
            placesNote = p ? "Guessed from your IP address, so check the town" : "Couldn't detect it";
        });
    }

    function dayLabel(d) {
        const today = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate());
        const diff = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000);
        return diff === 0 ? "Today" : diff === 1 ? "Tomorrow" : Qt.formatDate(d, "ddd, MMM d");
    }

    // "4:05", "1:02:09"
    function clockText(ms) {
        const s = Math.ceil(ms / 1000);
        const pad = n => String(n).padStart(2, "0");
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        return h > 0 ? `${h}:${pad(m)}:${pad(s % 60)}` : `${m}:${pad(s % 60)}`;
    }

    onOpenChanged: {
        if (open) {
            if (Panels.page === "reminders")
                compose(null);
        } else {
            calendar.monthOffset = 0;
            closeForm();
            locating = false;
        }
    }
    onKindChanged: picking = ""

    Connections {
        target: Panels

        function onPageChanged() {
            if (root.open && Panels.page === "reminders")
                root.compose(null);
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // A compact form row ("Time  05:30 PM ˅") that opens its picker.
    component FieldRow: Rectangle {
        id: field

        property string icon
        property string label
        property string value
        property bool expanded: false

        signal clicked

        width: parent.width
        height: 38
        radius: Theme.radius
        color: expanded ? Theme.surfaceHighest : Theme.surfaceHigh

        Icon {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: field.icon
            size: 16
            color: Theme.fgDim
        }

        StyledText {
            x: 38
            anchors.verticalCenter: parent.verticalCenter
            text: field.label
            color: Theme.fgDim
        }

        StyledText {
            anchors.right: chevron.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: field.value
            font.bold: true
        }

        Icon {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: field.expanded ? Icons.chevronUp : Icons.chevronDown
            size: 16
            color: Theme.fgDim
        }

        StateLayer {
            onClicked: field.clicked()
        }
    }

    // A timer in the list: big countdown, progress, pause / reset.
    component TimerCard: Rectangle {
        id: card

        required property var r
        readonly property real remaining: Reminders.remainingOf(r, clock.date.getTime())
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
            text: root.clockText(card.remaining)
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

    Column {
        width: parent.width
        spacing: 4

        // ------------------------------------------------- reminders
        Column {
            width: parent.width
            spacing: 6
            visible: root.showReminders

            // The form
            Column {
                width: parent.width
                spacing: 8
                visible: root.composing

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: Theme.radius
                    color: Theme.surfaceHigh

                    TextInput {
                        id: what

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                        selectionColor: Theme.primary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        clip: true
                        onAccepted: root.submit()

                        StyledText {
                            width: parent.width
                            visible: what.text === ""
                            text: root.kind === 0 ? "Label (optional)" : "Remind me to…"
                            color: Theme.fgMuted
                        }
                    }
                }

                Segmented {
                    width: parent.width
                    options: ["Timer", "Once", "Repeat"]
                    current: root.kind
                    onActivated: i => root.kind = i
                }

                // Timer: presets start it at once; or pick a duration.
                Segmented {
                    width: parent.width
                    visible: root.kind === 0
                    buttonHeight: 28
                    options: root.presetLabels
                    current: -1
                    onActivated: i => root.startTimer(root.presets[i])
                }

                FieldRow {
                    visible: root.kind === 0
                    icon: Icons.timer
                    label: "Duration"
                    value: root.durationMinutes >= 60 ? `${Math.floor(root.durationMinutes / 60)}h ${root.durationMinutes % 60}m` : `${root.durationMinutes}m`
                    expanded: root.picking === "duration"
                    onClicked: root.picking = expanded ? "" : "duration"
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: root.kind === 0 && root.picking === "duration"

                    Spinner {
                        id: timerHours
                        to: 23
                        digits: 1
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "h"
                        color: Theme.fgDim
                    }
                    Item { width: 8; height: 1 }
                    Spinner {
                        id: timerMinutes
                        to: 59
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "m"
                        color: Theme.fgDim
                    }
                }

                // Once: the day (or pick one in the calendar below).
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: Theme.radius
                    color: Theme.surfaceHigh
                    visible: root.kind === 1

                    Icon {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.calendar
                        size: 16
                        color: Theme.fgDim
                    }

                    StyledText {
                        x: 38
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Date"
                        color: Theme.fgDim
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        IconButton {
                            size: 30
                            icon: Icons.chevronLeft
                            idleColor: "transparent"
                            onClicked: root.day = new Date(root.day.getFullYear(), root.day.getMonth(), root.day.getDate() - 1)
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 92
                            horizontalAlignment: Text.AlignHCenter
                            text: root.dayLabel(root.day)
                            font.bold: true
                        }
                        IconButton {
                            size: 30
                            icon: Icons.chevronRight
                            idleColor: "transparent"
                            onClicked: root.day = new Date(root.day.getFullYear(), root.day.getMonth(), root.day.getDate() + 1)
                        }
                    }
                }

                // Repeat: how often, and the weekday for weekly.
                Segmented {
                    width: parent.width
                    visible: root.kind === 2
                    options: ["Daily", "Weekdays", "Weekly"]
                    current: root.repeatKind
                    onActivated: i => root.repeatKind = i
                }

                Segmented {
                    readonly property int first: Qt.locale().firstDayOfWeek % 7

                    width: parent.width
                    visible: root.kind === 2 && root.repeatKind === 2
                    buttonHeight: 28
                    spacing: 3
                    options: [0, 1, 2, 3, 4, 5, 6].map(i => Qt.locale().dayName((first + i) % 7, Locale.ShortFormat).slice(0, 2))
                    current: (root.weekday - first + 7) % 7
                    onActivated: i => root.weekday = (first + i) % 7
                }

                // Time of day for once and repeat.
                FieldRow {
                    visible: root.kind !== 0
                    icon: Icons.clock
                    label: "Time"
                    value: Qt.formatTime(new Date(2000, 0, 1, root.hour24, minute.value), "hh:mm AP")
                    expanded: root.picking === "time"
                    onClicked: root.picking = expanded ? "" : "time"
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: root.kind !== 0 && root.picking === "time"

                    Spinner {
                        id: hour
                        from: 1
                        to: 12
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Spinner {
                        id: minute
                        to: 59
                        step: 5
                    }
                    Item { width: 4; height: 1 }
                    Segmented {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 96
                        options: ["AM", "PM"]
                        current: root.pm ? 1 : 0
                        onActivated: i => root.pm = i === 1
                    }
                }

                // What it adds, or what's missing.
                StyledText {
                    x: 4
                    width: parent.width - 8
                    text: root.draft.error || `${root.kind === 0 ? Icons.timer : Icons.alarm}  ${Reminders.describe(root.draft, clock.date)}`
                    color: root.draft.error ? Theme.fgMuted : Theme.accent
                    font.pixelSize: Theme.fontSize - 1
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    TextButton {
                        text: "Cancel"
                        onClicked: root.closeForm()
                    }
                    TextButton {
                        icon: Icons.check
                        text: root.editing ? "Save" : root.kind === 0 ? "Start" : "Add"
                        fg: root.draft.error ? Theme.fgMuted : Theme.accent
                        onClicked: root.submit()
                    }
                }

                Item { width: 1; height: 2 }
            }

            // Soonest at the bottom, next to the header.
            ListView {
                width: parent.width
                height: Math.min(contentHeight, 300)
                visible: count > 0
                clip: true
                spacing: 4
                verticalLayoutDirection: ListView.BottomToTop
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    objectProp: "id"
                    values: Reminders.items
                }

                delegate: Column {
                    id: row

                    required property var modelData

                    width: ListView.view.width

                    TimerCard {
                        width: parent.width
                        visible: !!row.modelData.duration
                        r: row.modelData
                    }

                    ListItem {
                        width: parent.width
                        visible: !row.modelData.duration
                        icon: row.modelData.repeat ? Icons.repeat : Icons.alarm
                        title: Reminders.title(row.modelData)
                        subtitle: Reminders.describe(row.modelData, clock.date)
                        highlighted: root.editing === row.modelData.id
                        onClicked: root.compose(row.modelData)

                        IconButton {
                            size: 28
                            icon: Icons.close
                            idleColor: "transparent"
                            onClicked: Reminders.remove(row.modelData.id)
                        }
                    }
                }
            }

            StyledText {
                width: parent.width
                height: 32
                visible: Reminders.items.length === 0 && !root.composing
                horizontalAlignment: Text.AlignHCenter
                text: "No reminders"
                color: Theme.fgMuted
            }

            // One-click timers and the full form.
            Item {
                width: parent.width
                height: 28
                visible: !root.composing

                Icon {
                    id: quickIcon

                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.timer
                    size: 16
                    color: Theme.fgDim
                }

                Segmented {
                    anchors.left: quickIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    buttonHeight: 28
                    options: root.presetLabels
                    current: -1
                    onActivated: i => root.startTimer(root.presets[i])
                }
            }

            TextButton {
                width: parent.width
                visible: !root.composing
                icon: Icons.plus
                text: "New reminder"
                onClicked: root.compose(null)
            }
        }

        // Section header; folds the reminders in and out, upwards.
        Rectangle {
            width: parent.width
            height: 38
            radius: Theme.radius
            color: "transparent"

            Icon {
                id: headerIcon

                x: 6
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.alarm
                size: 18
            }

            StyledText {
                id: headerTitle

                anchors.left: headerIcon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Reminders"
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }

            StyledText {
                anchors.left: headerTitle.right
                anchors.leftMargin: 10
                anchors.right: chevron.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: Reminders.items.length > 0
                text: Reminders.next ? `${Reminders.items.length} · next ${Reminders.formatDue(Reminders.next.due, clock.date)}`
                    : Reminders.items.length
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSize - 1
            }

            Icon {
                id: chevron

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.showReminders ? Icons.chevronDown : Icons.chevronUp
                size: 18
                color: Theme.fgDim
            }

            StateLayer {
                onClicked: {
                    root.showReminders = !root.showReminders;
                    root.closeForm();
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        Item { width: 1; height: 6 }

        // ------------------------------------------- clock and calendar
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "hh:mm:ss AP")
            font.pixelSize: 34
            font.bold: true
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dddd, MMMM d")
            color: Theme.fgDim
        }

        Item { width: 1; height: 10 }

        // ------------------------------------------------- prayer times
        Rectangle {
            width: parent.width
            height: prayerContent.implicitHeight + 16
            radius: Theme.radius
            color: Theme.surface

            Column {
                id: prayerContent

                x: 12
                y: 8
                width: parent.width - 24
                spacing: 8

                Item {
                    width: parent.width
                    height: 24

                    Icon {
                        id: prayerIcon

                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.mosque
                        size: 16
                        color: Prayer.enabled ? Theme.accent : Theme.fgMuted
                    }

                    StyledText {
                        anchors.left: prayerIcon.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.nextPrayer ? `${root.nextPrayer.name} in ${Reminders.countdown(root.nextPrayer.at - clock.date.getTime())}` : "Prayer times"
                        color: Theme.fgDim
                    }

                    StyledText {
                        anchors.right: prayerSwitch.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.nextPrayer
                        text: !Prayer.enabled ? "Off" : !Prayer.location ? "" : Prayer.failed ? "Offline, retrying" : "Loading…"
                        color: Theme.fgMuted
                        font.pixelSize: Theme.fontSize - 1
                    }

                    StyledSwitch {
                        id: prayerSwitch

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Prayer.enabled
                        onToggled: {
                            root.locating = false;
                            Prayer.setEnabled(!checked);
                        }
                    }
                }

                // Passed ones dimmed, the next one in green.
                Row {
                    width: parent.width
                    visible: Prayer.enabled && root.prayers.length > 0

                    Repeater {
                        model: root.prayers

                        Column {
                            id: prayer

                            required property var modelData
                            readonly property bool isNext: modelData.at === root.nextPrayer?.at
                            readonly property bool passed: modelData.at <= clock.date.getTime()

                            width: parent.width / 5
                            spacing: 2

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: prayer.modelData.name
                                color: prayer.isNext ? Theme.accent : Theme.fgMuted
                                font.pixelSize: Theme.fontSize - 2
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.formatTime(new Date(prayer.modelData.at), "h:mm AP").replace(/ [AP]M$/i, "") // the order says which
                                color: prayer.isNext ? Theme.accent : prayer.passed ? Theme.fgMuted : Theme.fg
                                font.bold: prayer.isNext
                            }
                        }
                    }
                }

                // Where the times are for; click to change it.
                Item {
                    width: parent.width
                    height: 22
                    visible: Prayer.enabled && !root.locating

                    Icon {
                        id: pinIcon

                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.mapMarker
                        size: 14
                        color: Prayer.location ? Theme.fgMuted : Theme.orange
                    }

                    StyledText {
                        anchors.left: pinIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Prayer.location ? [Prayer.location.name, Prayer.location.detail].filter(x => x).join(", ") : "Set your location"
                        color: Prayer.location ? Theme.fgMuted : Theme.orange
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                    }

                    StateLayer {
                        onClicked: root.openLocating()
                    }
                }

                // The location search.
                Column {
                    width: parent.width
                    spacing: 6
                    visible: Prayer.enabled && root.locating

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: Theme.radius
                        color: Theme.surfaceHigh

                        Icon {
                            id: searchIcon

                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.magnify
                            size: 16
                            color: Theme.fgDim
                        }

                        TextInput {
                            id: placeQuery

                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.fg
                            selectionColor: Theme.primary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            clip: true
                            onTextChanged: searchDelay.restart()
                            onAccepted: root.findPlaces()

                            StyledText {
                                width: parent.width
                                visible: placeQuery.text === ""
                                text: "Search a city…"
                                color: Theme.fgMuted
                            }
                        }

                        // Searches once typing pauses.
                        Timer {
                            id: searchDelay
                            interval: 400
                            onTriggered: root.findPlaces()
                        }
                    }

                    Repeater {
                        model: root.places

                        ListItem {
                            required property var modelData

                            width: parent.width
                            icon: Icons.mapMarker
                            title: modelData.name
                            subtitle: [modelData.detail, `${modelData.latitude.toFixed(2)}, ${modelData.longitude.toFixed(2)}`].filter(x => x).join(" · ")
                            onClicked: {
                                Prayer.setLocation(modelData);
                                root.locating = false;
                            }
                        }
                    }

                    StyledText {
                        x: 4
                        width: parent.width - 8
                        visible: text !== ""
                        text: root.placesNote
                        color: Theme.fgMuted
                        font.pixelSize: Theme.fontSize - 1
                        wrapMode: Text.Wrap
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 6

                        TextButton {
                            icon: Icons.crosshairs
                            text: "Detect"
                            onClicked: root.detectPlace()
                        }
                        TextButton {
                            text: "Cancel"
                            onClicked: root.locating = false
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 6 }

        Calendar {
            id: calendar

            width: parent.width
            today: clock.date
            marked: Reminders.items.filter(r => !r.paused).map(r => r.due)
            selected: root.composing && root.kind === 1 ? root.day : null

            // A day starts (or moves) a one-off on it; with a weekly
            // repeat it picks the weekday instead.
            onPicked: d => {
                if (!root.composing)
                    root.compose(null);
                if (root.kind === 2 && root.repeatKind === 2) {
                    root.weekday = d.getDay();
                } else {
                    root.kind = 1;
                    root.day = d;
                }
            }
        }
    }
}
