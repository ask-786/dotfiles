import QtQuick
import qs

// Month grid with prev/next navigation; today is highlighted. Days with
// something on them (`marked`, timestamps in ms) get a dot, clicking a day
// emits `picked`, and `selected` (a date, or null) gets an outline.
Column {
    id: root

    required property date today
    property int monthOffset: 0
    property var marked: []
    property var selected: null

    signal picked(date day)

    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7 // 0 = Sunday
    readonly property var cells: {
        const y = shown.getFullYear(), m = shown.getMonth();
        const lead = (new Date(y, m, 1).getDay() - firstDay + 7) % 7;
        const days = new Date(y, m + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < lead; i++)
            out.push(0);
        for (let d = 1; d <= days; d++)
            out.push(d);
        return out;
    }
    readonly property bool isCurrentMonth: monthOffset === 0
    readonly property var markedDays: {
        const out = {};
        for (const t of marked) {
            const d = new Date(t);
            if (d.getFullYear() === shown.getFullYear() && d.getMonth() === shown.getMonth())
                out[d.getDate()] = true;
        }
        return out;
    }

    spacing: 8

    Item {
        width: parent.width
        height: 34

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            x: 4
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            IconButton {
                size: 30
                icon: Icons.chevronLeft
                onClicked: root.monthOffset--
            }
            IconButton {
                size: 30
                icon: Icons.chevronRight
                onClicked: root.monthOffset++
            }
        }
    }

    Grid {
        id: grid

        readonly property real cell: Math.floor(root.width / 7)

        columns: 7

        Repeater {
            model: 7

            StyledText {
                required property int index

                width: grid.cell
                height: 26
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
                color: Theme.fgMuted
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Repeater {
            model: root.cells

            Item {
                id: cell

                required property int modelData
                readonly property bool isToday: root.isCurrentMonth && modelData === root.today.getDate()
                readonly property bool isSelected: root.selected !== null && modelData > 0
                    && root.selected.getFullYear() === root.shown.getFullYear()
                    && root.selected.getMonth() === root.shown.getMonth()
                    && root.selected.getDate() === modelData

                width: grid.cell
                height: grid.cell - 8

                Rectangle {
                    id: day

                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: Theme.radius
                    color: parent.isToday ? Theme.primary : "transparent"
                    border.width: parent.isSelected ? 1 : 0
                    border.color: Theme.accent

                    StateLayer {
                        enabled: cell.modelData > 0
                        onClicked: root.picked(new Date(root.shown.getFullYear(), root.shown.getMonth(), cell.modelData))
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: parent.modelData > 0 ? parent.modelData : ""
                    color: parent.isToday ? Theme.primaryFg : Theme.fg
                    font.bold: parent.isToday
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: day.bottom
                    anchors.bottomMargin: 3
                    width: 4
                    height: 4
                    radius: 2
                    color: Theme.accent
                    visible: parent.modelData > 0 && root.markedDays[parent.modelData] === true
                }
            }
        }
    }
}
