import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The session lock (ext-session-lock): one LockContent per monitor while
// Lock.locked. If Quickshell dies while locked, Hyprland keeps the session
// locked; from a TTY, `hyprlock` can take over (allow_session_lock_restore).
WlSessionLock {
    locked: Lock.locked

    WlSessionLockSurface {
        color: "black"

        LockContent {
            anchors.fill: parent
        }
    }
}
