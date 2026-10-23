pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Idle options read by hypridle's scripts. hypr/scripts/idle-suspend.sh
// holds off the 30 min suspend while media plays unless mediaAwake is off.
// The switch is on the Settings page, kept in ~/.local/state.
Singleton {
    id: root

    property bool mediaAwake: true

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/idle.json`
    property bool _loaded: false

    function setMediaAwake(on) {
        mediaAwake = on;
        file.setText(JSON.stringify({ mediaAwake }) + "\n");
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        // Only the first load; later ones are our own writes.
        onLoaded: {
            if (root._loaded)
                return;
            root._loaded = true;
            try {
                root.mediaAwake = JSON.parse(text()).mediaAwake !== false;
            } catch (e) {
                console.warn(`Idle: ignoring unreadable ${root.path}: ${e}`);
            }
        }
    }
}
