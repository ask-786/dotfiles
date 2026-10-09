pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

// The notification daemon (replaces dunst). Every notification stays in
// `list`, the history shown above quick settings, until it's dismissed there
// or its app closes it; `popups` are the ones currently shown top right,
// each until its timeout runs out (paused while hovered). Do-not-disturb
// holds back popups except critical ones; transient notifications skip the
// history.
Singleton {
    id: root

    property bool dnd: false

    // Oldest first, like the server keeps them.
    readonly property var list: server.trackedNotifications.values
    // { n, until } for each shown popup, oldest first; until 0 = sticky.
    property var popups: []
    property var hovered: null
    // Arrival time (ms) by notification id, for "5m ago"; kept across reloads
    // like the notifications themselves.
    readonly property var arrived: JSON.parse(persist.arrived)

    readonly property int defaultTimeout: 10000

    function timeoutFor(n) {
        if (n.urgency === NotificationUrgency.Critical || n.expireTimeout === 0)
            return 0;
        return n.expireTimeout > 0 ? n.expireTimeout : defaultTimeout; // ms
    }

    // "now", "5m ago", "2h ago", "3d ago"
    function age(n, now) {
        const m = Math.floor((now - (arrived[n?.id] ?? now)) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m}m ago` : m < 1440 ? `${Math.floor(m / 60)}h ago` : `${Math.floor(m / 1440)}d ago`;
    }

    // The image or icon to show for a notification, "" for none.
    function iconSource(n) {
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

    function hidePopup(n) {
        popups = popups.filter(p => p.n !== n);
        if (n?.transient && n.tracked)
            n.expire();
    }

    function dismiss(n) {
        popups = popups.filter(p => p.n !== n);
        n.dismiss();
    }

    function clearAll() {
        popups = [];
        for (const n of list.slice())
            n.dismiss();
    }

    // Clicking a notification, like Android: run its default action, bring
    // its app forward (a window if it has one, else launch it) and clear it.
    // Raising is on us: Quickshell sends apps no activation token, so most
    // can't raise themselves from the action. Notifications from no app
    // (notify-send, scripts) just leave the popup.
    function activate(n) {
        let invoked = false;
        for (let i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default") {
                n.actions[i].invoke(); // also dismisses non-resident ones
                invoked = true;
                break;
            }
        }
        // With a default action the app opens what it wants itself; only
        // raise an existing window then, don't launch a second copy.
        const opened = openApp(n, !invoked);
        if (invoked || opened) {
            Panels.close();
            if (n.tracked && !n.resident)
                dismiss(n);
            else
                hidePopup(n);
        } else {
            hidePopup(n);
        }
    }

    // Focuses the notifying app's window, or launches it when `launch`.
    function openApp(n, launch) {
        const norm = s => (s ?? "").toLowerCase().replace(/\.desktop$/, "").replace(/\s+/g, "-");
        const entry = (n.desktopEntry && DesktopEntries.byId(n.desktopEntry))
                   || DesktopEntries.heuristicLookup(n.desktopEntry || n.appName);
        const names = [n.desktopEntry, entry?.id, entry?.startupClass, n.appName].map(norm).filter(s => s && s !== "notify-send");
        if (names.length === 0)
            return false;
        const win = ToplevelManager.toplevels.values.find(t => names.includes(norm(t.appId)));
        if (win) {
            // Hyprland ignores toplevel activate requests (unless
            // focus_on_activate is set); its own focus also switches to the
            // window's workspace.
            const addr = Hyprland.toplevels.values.find(h => h.wayland === win)?.address;
            if (addr)
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr.startsWith("0x") ? addr : "0x" + addr}" })`);
            else
                win.activate();
            return true;
        }
        if (launch && entry) {
            entry.execute();
            return true;
        }
        return false;
    }

    function _show(n) {
        const t = timeoutFor(n);
        popups = popups.filter(p => p.n !== n).concat([{ n, until: t ? Date.now() + t : 0 }]);
    }

    function stackTag(n) {
        return n.hints["x-dunst-stack-tag"] ?? n.hints["x-canonical-private-synchronous"] ?? "";
    }

    // dunst is still installed as a D-Bus-activated fallback for when
    // Quickshell is down; if it took the bus name meanwhile, stop it, and
    // the server registers as soon as the name is free.
    Component.onCompleted: Quickshell.execDetached(["pkill", "-x", "dunst"])

    PersistentProperties {
        id: persist

        reloadableId: "notifs"
        property string arrived: "{}"
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true;
            // Carried over by a config reload: already seen, no popup again.
            if (n.lastGeneration)
                return;
            // A JSON string: a JS object can't move to the reloaded engine.
            const kept = {};
            for (const o of root.list) {
                if (root.arrived[o.id])
                    kept[o.id] = root.arrived[o.id];
            }
            kept[n.id] = Date.now();
            persist.arrived = JSON.stringify(kept);
            // A stack tag (Battery's alerts, volume OSD scripts) replaces
            // the app's previous notification with the same tag.
            const tag = root.stackTag(n);
            if (tag) {
                for (const o of root.list.slice()) {
                    if (o !== n && o.appName === n.appName && root.stackTag(o) === tag)
                        root.dismiss(o);
                }
            }
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root._show(n);
        }
    }

    // Drops popups whose notification is gone and those that timed out.
    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            const now = Date.now();
            for (const p of root.popups) {
                if (p.n && p.n === root.hovered && p.until)
                    p.until = Math.max(p.until, now + 2000);
            }
            const gone = root.popups.filter(p => !p.n || !p.n.tracked || (p.until && p.until <= now));
            for (const p of gone)
                root.hidePopup(p.n);
        }
    }
}
