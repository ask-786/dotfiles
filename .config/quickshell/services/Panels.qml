pragma Singleton

import QtQuick
import Quickshell

// Which drawers are open, and on which monitor. Quick settings, the
// calendar and notifications replace each other; media is independent and
// stacks on top of whichever of them is open.
Singleton {
    property string open: "" // "quick" | "calendar" | "notifications" | ""
    property bool media: false
    property string screen: ""
    property string page: "" // sub-page to open on, e.g. "wifi"

    readonly property bool any: open !== "" || media

    // Same button again closes; a different page on an open drawer switches.
    // Opening on another monitor closes everything on the old one.
    function toggle(name, screenName, target) {
        target = target ?? "";
        if (screen !== screenName) {
            close();
            screen = screenName;
        }
        if (name === "media") {
            media = !media;
        } else if (open === name && page === target) {
            open = "";
        } else {
            page = target;
            open = name;
        }
    }

    function isOpen(name, screenName) {
        return screen === screenName && (name === "media" ? media : open === name);
    }

    function close() {
        open = "";
        media = false;
    }
}
