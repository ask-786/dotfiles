pragma Singleton

import QtQuick
import Quickshell

// Which drawer is open, and on which monitor. Only one at a time.
Singleton {
    property string open: "" // "quick" | "calendar" | ""
    property string screen: ""
    property string page: "" // sub-page to open on, e.g. "wifi"

    // Same button again closes; a different page on an open drawer switches.
    function toggle(name, screenName, target) {
        target = target ?? "";
        if (open === name && screen === screenName && page === target) {
            open = "";
        } else {
            screen = screenName;
            page = target;
            open = name;
        }
    }

    function isOpen(name, screenName) {
        return open === name && screen === screenName;
    }

    function close() {
        open = "";
    }
}
