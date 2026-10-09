import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The session lock (ext-session-lock): one LockContent per monitor while
// Lock.locked. If Quickshell dies while locked, Hyprland keeps the session
// locked; from a TTY, `hyprlock` can take over (allow_session_lock_restore).
Scope {
    WlSessionLock {
        id: sessionLock

        locked: Lock.locked

        WlSessionLockSurface {
            id: surface

            color: "black"

            LockContent {
                anchors.fill: parent
                screen: surface.screen
            }
        }
    }

    Binding {
        target: Lock
        property: "secure"
        value: sessionLock.secure
    }

    // Quickshell gives up on a lock it can't set up (a lock surface that
    // fails to load, the compositor refusing) before asking the compositor
    // for it, and `locked` just stays false without a change signal.
    Connections {
        target: Lock

        function onLockedChanged() {
            Qt.callLater(() => {
                if (Lock.locked && !sessionLock.locked)
                    Lock.abort();
            });
        }
    }
}
