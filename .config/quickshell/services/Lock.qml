pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The lock screen's state and its PAM conversation (replaces hyprlock). It
// uses hyprlock's stack, /etc/pam.d/hyprlock, so whatever a machine set up
// for hyprlock applies here too. PAM starts on Enter, not on lock, so a
// failed attempt can't loop when faillock refuses straight away.
//
// Locking goes through `loginctl lock-session` → hypridle's lock_cmd →
// `qs ipc call lock lock`. Nothing unlocks except a successful PAM run.
Singleton {
    id: root

    readonly property bool locked: persist.locked
    // PAM is working on an answer.
    readonly property bool busy: pam.active && !pam.responseRequired
    // Under the field: PAM's messages, or why the last attempt failed.
    property string status: ""
    property bool statusIsError: false

    // hyprpaper's wallpaper, blurred behind the lock screen.
    property string wallpaper: ""

    property string _pending: ""
    property bool _hasPending: false

    function lock() {
        if (persist.locked)
            return;
        status = "";
        statusIsError = false;
        persist.locked = true;
        Panels.close();
    }

    // Enter in the password field, possibly empty.
    function submit(text) {
        if (!persist.locked || busy)
            return;
        status = "";
        statusIsError = false;
        if (pam.active && pam.responseRequired) {
            pam.respond(text);
            return;
        }
        _pending = text;
        _hasPending = true;
        if (!pam.active && !pam.start()) {
            _hasPending = false;
            _fail("Couldn't start authentication");
        }
    }

    function _fail(text) {
        status = text;
        statusIsError = true;
    }

    PersistentProperties {
        id: persist

        reloadableId: "lock"
        property bool locked: false
    }

    FileView {
        id: wallpaperConf

        path: `${Quickshell.env("HOME")}/.config/hypr/hyprpaper.conf`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.wallpaper = (text().match(/^\s*path\s*=\s*(\S.*?)\s*$/m) ?? [])[1] ?? ""
    }

    PamContext {
        id: pam

        config: "hyprlock"

        onPamMessage: {
            if (responseRequired) {
                if (root._hasPending) {
                    root._hasPending = false;
                    respond(root._pending);
                    root._pending = "";
                }
                // Otherwise a second prompt (a module further down the
                // stack asking again): wait for Enter.
                return;
            }
            if (message.trim() !== "") {
                root.status = message.trim();
                root.statusIsError = messageIsError;
            }
        }

        onCompleted: result => {
            root._hasPending = false;
            root._pending = "";
            if (result === PamResult.Success) {
                root.status = "";
                root.statusIsError = false;
                persist.locked = false;
            } else if (result === PamResult.MaxTries) {
                root._fail("Too many attempts, try again later");
            } else {
                root._fail("Wrong password");
            }
        }

        onError: error => {
            root._hasPending = false;
            root._pending = "";
            root._fail(`Authentication error: ${PamError.toString(error)}`);
        }
    }
}
