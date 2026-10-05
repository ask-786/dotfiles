import QtQuick
import qs

// Month grid with prev/next navigation; today is highlighted.
Column {
    id: root

    required property date today
    property int monthOffset: 0

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
                required property int modelData
                readonly property bool isToday: root.isCurrentMonth && modelData === root.today.getDate()

                width: grid.cell
                height: grid.cell - 8

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: Theme.radius
                    color: Theme.primary
                    visible: parent.isToday
                }

                StyledText {
                    anchors.centerIn: parent
                    text: parent.modelData > 0 ? parent.modelData : ""
                    color: parent.isToday ? Theme.primaryFg : Theme.fg
                    font.bold: parent.isToday
                }
            }
        }
    }
}
