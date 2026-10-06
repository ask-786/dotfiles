import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

// One notification: icon or image, app and age, summary, body and action
// buttons. Clicking it runs its default action; × dismisses it. The popups
// (`popup`, which pause their timeout while hovered) and the history panel
// share it.
Rectangle {
    id: root

    required property var notification
    property bool popup: false

    readonly property var n: notification
    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    readonly property bool low: n?.urgency === NotificationUrgency.Low
    readonly property string iconSource: {
        if (!n)
            return "";
        // notify-send's -i also arrives as an unchecked image://icon/<name>;
        // a missing theme icon would show the magenta placeholder.
        if (n.image && !n.image.startsWith("image://icon/"))
            return n.image;
        // Apps that send no icon get their desktop entry's (as DMS does).
        const name = n.image ? n.image.slice("image://icon/".length)
                   : n.appIcon || DesktopEntries.heuristicLookup(n.desktopEntry || n.appName)?.icon || "";
        if (!name)
            return "";
        if (name.startsWith("/"))
            return `file://${name}`;
        if (name.includes("://"))
            return name;
        return Quickshell.iconPath(name, true);
    }

    implicitHeight: Math.max(content.implicitHeight, iconBox.height) + 2 * Theme.padding
    radius: Theme.radius
    color: critical ? Theme.criticalBg : popup ? Theme.panelBg : Theme.surface
    border.width: 1
    border.color: critical ? Theme.urgentBorder : popup ? Theme.panelBorder : Theme.border

    function age(now) {
        const m = Math.floor((now - (Notifs.arrived[n?.id] ?? now)) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m}m ago` : m < 1440 ? `${Math.floor(m / 60)}h ago` : `${Math.floor(m / 1440)}d ago`;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    HoverHandler {
        enabled: root.popup
        onHoveredChanged: {
            if (hovered)
                Notifs.hovered = root.n;
            else if (Notifs.hovered === root.n)
                Notifs.hovered = null;
        }
    }

    StateLayer {
        onClicked: if (root.n) Notifs.activate(root.n)
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
            color: root.critical ? Theme.fg : Theme.fgDim
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
            text: [root.n?.appName ?? "", root.age(clock.date.getTime())].filter(s => s).join(" · ")
            color: root.critical ? Theme.fgDim : Theme.fgMuted
            font.pixelSize: Theme.fontSize - 2
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.n?.summary ?? ""
            color: root.low ? Theme.fgDim : Theme.fg
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.n?.body ?? ""
            textFormat: Text.StyledText
            color: root.critical ? Theme.fg : Theme.fgDim
            linkColor: Theme.accent
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
            maximumLineCount: root.popup ? 5 : 3
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Flow {
            width: parent.width
            spacing: 6
            topPadding: 6
            visible: actions.count > 0

            Repeater {
                id: actions

                model: Array.prototype.filter.call(root.n?.actions ?? [], a => a.identifier !== "default")

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
        onClicked: Notifs.dismiss(root.n)
    }
}
