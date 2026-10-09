import QtQuick
import qs

// Number picker for time fields: arrows above and below move by `step`
// (snapping onto its grid), the scroll wheel and Up/Down keys by `fineStep`,
// and clicking the number lets you type one, in range only. Wraps around by
// default (59 → 0, 12 → 1).
Column {
    id: root

    property int value: 0
    property int from: 0
    property int to: 59
    property int step: 1
    property int fineStep: step
    property bool wrap: true
    property int digits: 2
    readonly property bool editing: input.visible

    property real _wheel: 0
    property int _before: 0

    // Off-grid values land on the grid first: 07 goes up to 10, down to 05.
    function bump(dir, by) {
        by = by ?? step;
        const off = value - from;
        const v = from + (dir > 0 ? Math.floor(off / by) + 1 : Math.ceil(off / by) - 1) * by;
        const span = to - from + 1;
        value = wrap ? ((v - from) % span + span) % span + from : Math.max(from, Math.min(to, v));
    }

    function edit() {
        _before = value;
        input.visible = true;
        input.forceActiveFocus();
        _show();
    }

    function _show() {
        input.text = input.good = String(value).padStart(digits, "0");
        input.selectAll();
    }

    // Whether typed text is, or can still become, a number in range: for
    // 1–12, "0" and "1" pass (on to 05 or 12) but "00" and "13" don't.
    function _fits(t) {
        for (let v = from; v <= to; v++)
            if (String(v).startsWith(t) || String(v).padStart(input.maximumLength, "0").startsWith(t))
                return true;
        return false;
    }

    // The value follows the typing, so this only has to put the number back.
    // Half-typed text ("0" for an hour) leaves the last whole one standing.
    function finish(revert) {
        if (!editing)
            return;
        if (revert)
            value = _before;
        const focused = input.activeFocus;
        input.visible = false;
        // Keep focus inside the drawer so Esc still closes it, unless it
        // already moved on to another field.
        if (focused)
            root.forceActiveFocus();
    }

    spacing: 2

    Keys.onUpPressed: bump(1, fineStep)
    Keys.onDownPressed: bump(-1, fineStep)

    IconButton {
        anchors.horizontalCenter: parent.horizontalCenter
        size: 26
        icon: Icons.chevronUp
        idleColor: "transparent"
        onClicked: {
            root.finish(false);
            root.bump(1);
        }
    }

    Rectangle {
        width: 56
        height: 44
        radius: Theme.radius
        color: Theme.surfaceHigh
        border.width: root.editing ? 1 : 0
        border.color: Theme.accent

        StyledText {
            anchors.centerIn: parent
            visible: !root.editing
            text: String(root.value).padStart(root.digits, "0")
            font.pixelSize: 24
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: root.edit()
            // Accumulate so touchpads (many small deltas) step like a wheel.
            onWheel: event => {
                root._wheel += event.angleDelta.y;
                while (Math.abs(root._wheel) >= 120) {
                    const dir = root._wheel > 0 ? 1 : -1;
                    root._wheel -= dir * 120;
                    root.finish(false);
                    root.bump(dir, root.fineStep);
                }
            }
        }

        TextInput {
            id: input

            anchors.fill: parent
            visible: false
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            selectionColor: Theme.primary
            selectedTextColor: Theme.primaryFg
            font.family: Theme.font
            font.pixelSize: 24
            font.bold: true
            property string good // last text that passed _fits

            maximumLength: String(root.to).length
            validator: RegularExpressionValidator { regularExpression: /\d*/ }

            // Keystrokes that can't lead anywhere valid are dropped.
            onTextEdited: {
                if (!root._fits(text)) {
                    text = good;
                    cursorPosition = text.length;
                    return;
                }
                good = text;
                const n = parseInt(text, 10);
                if (n >= root.from && n <= root.to)
                    root.value = n;
            }
            onAccepted: root.finish(false)
            onActiveFocusChanged: if (!activeFocus) root.finish(false)
            Keys.onEscapePressed: root.finish(true)
            Keys.onUpPressed: {
                root.bump(1, root.fineStep);
                root._show();
            }
            Keys.onDownPressed: {
                root.bump(-1, root.fineStep);
                root._show();
            }
        }
    }

    IconButton {
        anchors.horizontalCenter: parent.horizontalCenter
        size: 26
        icon: Icons.chevronDown
        idleColor: "transparent"
        onClicked: {
            root.finish(false);
            root.bump(-1);
        }
    }
}
