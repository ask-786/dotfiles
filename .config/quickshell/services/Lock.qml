pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The lock screen's state and its PAM conversation (replaces hyprlock). It
// uses hyprlock's stack, /etc/pam.d/hyprlock, so the order is unchanged:
// the password is tried first, and an empty Enter or a wrong password falls
// through to face unlock (howdy). PAM starts on Enter, not on lock, so a
// failed attempt can't loop when faillock refuses straight away.
//
// Locking goes through `loginctl lock-session` → hypridle's lock_cmd →
// `qs ipc call lock lock`. Nothing unlocks except a successful PAM run.
Singleton {
    id: root

    readonly property bool locked: persist.locked
    // Taking the screenshots; the lock follows.
    property bool locking: false
    // The compositor has confirmed the lock (from LockScreen).
    property bool secure: false
    // PAM is working on an answer (checking the password, or the camera).
    readonly property bool busy: pam.active && !pam.responseRequired
    // The last answer was empty, so this attempt is face only.
    property bool faceOnly: false
    // Under the field: howdy's progress, or why the last attempt failed.
    property string status: ""
    property bool statusIsError: false

    // What was on screen, one half-size shot per monitor (<name>.ppm),
    // blurred behind the lock screen like hyprlock's `path = screenshot`.
    // Taken before locking: once locked, Hyprland shows nothing else to
    // capture. Private to the user, and deleted as soon as every monitor's
    // lock screen has loaded its shot (a monitor added while locked gets
    // the wallpaper), or else on unlock or the next start.
    readonly property string shotDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-lock`
    // Monitors whose lock screen hasn't loaded its shot yet.
    property var _unloadedShots: []
    // hyprpaper's wallpaper, in case a shot is missing.
    property string wallpaper: ""

    property string _pending: ""
    property bool _hasPending: false

    function lock() {
        if (persist.locked || locking)
            return;
        status = "";
        statusIsError = false;
        locking = true;
        _unloadedShots = Quickshell.screens.map(s => s.name);
        shooter.exec(["sh", "-c", 'umask 077; d=$1; shift; rm -rf "$d"; mkdir -p "$d"; for o; do grim -s 0.5 -t ppm -o "$o" "$d/$o.ppm" & done; wait',
                      "sh", shotDir].concat(Quickshell.screens.map(s => s.name)));
        shotTimeout.restart();
    }

    // LockScreen couldn't take the lock, so nothing is locked: forget it, or
    // every later lock() would think it's already up.
    function abort() {
        if (!persist.locked)
            return;
        console.warn("Lock: the session lock didn't start");
        persist.locked = false;
        _removeShots();
    }

    // A lock screen is done with its shot (loaded, or missing).
    function shotLoaded(screenName) {
        if (_unloadedShots.length === 0)
            return;
        _unloadedShots = _unloadedShots.filter(n => n !== screenName);
        if (_unloadedShots.length === 0)
            _removeShots();
    }

    function _removeShots() {
        _unloadedShots = [];
        Quickshell.execDetached(["rm", "-rf", shotDir]);
    }

    function _engage() {
        if (!locking)
            return;
        locking = false;
        shotTimeout.stop();
        persist.locked = true;
        Panels.close();
    }

    // Enter in the password field, possibly empty.
    function submit(text) {
        if (!persist.locked || busy)
            return;
        faceOnly = text === "";
        status = faceOnly ? "Looking for your face…" : "";
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

    Process {
        id: shooter

        onExited: root._engage()
    }

    // Lock anyway if grim hangs; the wallpaper stands in.
    Timer {
        id: shotTimeout

        interval: 1500
        onTriggered: root._engage()
    }

    PersistentProperties {
        id: persist

        reloadableId: "lock"
        property bool locked: false

        // A fresh start (not a reload): shots left over if Quickshell died
        // while locked.
        onLoaded: {
            if (!root.locking && !locked)
                root._removeShots();
        }
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
                // Otherwise a second prompt (the stack's `include login`
                // asks again after face unlock failed): wait for Enter.
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
                root._removeShots();
            } else if (result === PamResult.MaxTries) {
                root._fail("Too many attempts, try again later");
            } else {
                root._fail(root.faceOnly ? "Face not recognized" : "Wrong password or face not recognized");
            }
        }

        onError: error => {
            root._hasPending = false;
            root._pending = "";
            root._fail(`Authentication error: ${PamError.toString(error)}`);
        }
    }
}
