pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon (replaces dunst). Every notification stays in
// `list`, the history shown above quick settings, until it's dismissed there
// or its app closes it; `popups` are the ones currently shown top right,
// each until its timeout runs out (paused while hovered). Do-not-disturb
// holds back popups except critical ones; transient notifications skip the
// history.
//
// The history is grouped like Android: a group per app, or per site for
// browsers (their notifications all come as the browser), and in it a
// thread per chat. A new message replaces its chat's popup, counting up.
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
    // Thread of each notification by id (see _thread), kept the same way.
    readonly property var threadOf: JSON.parse(persist.threads)

    // Newest first: { key, label, icon, count, latest, threads }, each thread
    // { key, title, items (newest first), latest }.
    readonly property var groups: _group(list, threadOf)
    readonly property var groupByKey: {
        const m = {};
        for (const g of groups)
            m[g.key] = g;
        return m;
    }
    readonly property var threadByKey: {
        const m = {};
        for (const g of groups) {
            for (const t of g.threads)
                m[t.key] = t;
        }
        return m;
    }
    // Groups expanded in the drawer, and threads showing all their messages,
    // by key; both reset a moment after the drawer closes.
    property var expanded: ({})
    property var showAll: ({})

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
        return n.image ? _iconPath(n.image.slice("image://icon/".length)) : appIconSource(n);
    }

    // The app's own icon, for group headers: Chrome sends its logo here and
    // the sender's picture as the image.
    function appIconSource(n) {
        return _iconPath(n?.appIcon || DesktopEntries.heuristicLookup(n?.desktopEntry || n?.appName)?.icon || "");
    }

    function _iconPath(name) {
        if (!name)
            return "";
        if (name.startsWith("/"))
            return `file://${name}`;
        if (name.includes("://"))
            return name;
        return Quickshell.iconPath(name, true);
    }

    // Chrome (and other Chromium browsers) start the body with the site as
    // a link and a blank line:
    // <a href="https://www.instagram.com/">www.instagram.com</a>\n\n
    function _siteMatch(n) {
        return /^<a href="https?:\/\/([^\/"]+)[^"]*">[^<]*<\/a>(?:\n\n|$)/.exec(n?.body ?? "");
    }

    // The site a browser notification is from, "" for others.
    function site(n) {
        return _siteMatch(n)?.[1] ?? "";
    }

    // The body without the browser's site line.
    function body(n) {
        const m = _siteMatch(n);
        return m ? n.body.slice(m[0].length) : n?.body ?? "";
    }

    // The body on one line without markup, for one-line rows.
    function plainBody(n) {
        return body(n).replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
    }

    // What to call where a notification is from: the site's name for
    // browsers ("Instagram", not "Google Chrome"), else the app's.
    function label(n) {
        const host = site(n);
        if (!host)
            return n?.appName ?? "";
        const known = {
            "web.whatsapp.com": "WhatsApp",
            "mail.google.com": "Gmail",
            "calendar.google.com": "Google Calendar",
            "chat.google.com": "Google Chat",
            "www.youtube.com": "YouTube",
            "www.linkedin.com": "LinkedIn",
            "github.com": "GitHub"
        };
        if (known[host])
            return known[host];
        const parts = host.split(".");
        const name = parts.length > 1 ? parts[parts.length - 2] : host;
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    function groupKey(n) {
        const host = site(n);
        return (n.desktopEntry || n.appName) + (host ? `|${host}` : "");
    }

    function threadKey(n) {
        return `${groupKey(n)}\n${threadOf[n.id] ?? _thread(n)}`;
    }

    // A chat's key within its group: the title, which is the chat's name
    // for most messengers (WhatsApp Web, Discord, Telegram). Instagram's
    // title is just "Instagram", the site's name, and only the picture
    // tells senders apart, so then it's a hash of the picture's file (a new
    // temp file per notification, but the same bytes for the same sender).
    function _thread(n) {
        const title = (n.summary ?? "").trim();
        if (title && title.toLowerCase() !== label(n).toLowerCase() && title !== n.appName)
            return `s:${title}`;
        let path = n.hints["image-path"] ?? n.hints["image_path"] ?? "";
        if (path.startsWith("file://"))
            path = path.slice("file://".length);
        if (path.startsWith("/")) {
            const file = fileReader.createObject(null, { path });
            const data = file.data();
            file.destroy();
            if (data && data.byteLength > 0) {
                // FNV-1a
                const bytes = new Uint8Array(data);
                let h = 0x811c9dc5;
                for (let i = 0; i < bytes.length; i++)
                    h = Math.imul(h ^ bytes[i], 0x01000193);
                return `i:${(h >>> 0).toString(16)}`;
            }
        }
        return `s:${title}`;
    }

    // The chat's name to show, "" when it's only known by its picture.
    function _title(thread) {
        return thread.startsWith("s:") ? thread.slice(2) : "";
    }

    function _group(ns, threads) {
        const groups = {};
        const out = [];
        // ns is oldest first, so a higher rank is newer.
        for (let i = 0; i < ns.length; i++) {
            const n = ns[i];
            const gk = groupKey(n);
            let g = groups[gk];
            if (!g) {
                g = groups[gk] = { key: gk, threadMap: {}, threads: [], count: 0 };
                out.push(g);
            }
            const tid = threads[n.id] ?? _thread(n);
            const tk = `${gk}\n${tid}`;
            let t = g.threadMap[tk];
            if (!t) {
                t = g.threadMap[tk] = { key: tk, group: gk, title: "", items: [] };
                g.threads.push(t);
            }
            t.items.unshift(n);
            t.latest = n;
            t.title = _title(tid);
            t.rank = g.rank = i;
            g.latest = n;
            g.count++;
        }
        for (const g of out) {
            g.threads.sort((a, b) => b.rank - a.rank);
            g.label = label(g.latest);
            g.icon = appIconSource(g.latest) || iconSource(g.latest);
            delete g.threadMap;
        }
        return out.sort((a, b) => b.rank - a.rank);
    }

    function toggleGroup(key) {
        expanded = Object.assign({}, expanded, { [key]: !expanded[key] });
    }

    function toggleShowAll(key) {
        showAll = Object.assign({}, showAll, { [key]: !showAll[key] });
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

    function dismissThread(t) {
        for (const n of t.items.slice())
            dismiss(n);
    }

    function dismissGroup(g) {
        for (const t of g.threads)
            dismissThread(t);
    }

    // Opening a chat opens its latest message and clears the rest, like
    // Android does.
    function activateThread(t) {
        const rest = t.items.slice(1);
        if (activate(t.latest)) {
            for (const n of rest) {
                if (n.tracked)
                    dismiss(n);
            }
        }
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
    // (notify-send, scripts) just leave the popup. True if something opened.
    function activate(n) {
        const wsId = parseInt(n.hints["x-qs-workspace"]);
        if (wsId > 0) {
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`);
            Panels.close();
            if (n.tracked) dismiss(n);
            else hidePopup(n);
            return true;
        }
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
            return true;
        }
        hidePopup(n);
        return false;
    }

    // Focuses the notifying app's window, or launches it when `launch`.
    function openApp(n, launch) {
        const norm = s => (s ?? "").toLowerCase().replace(/\.desktop$/, "").replace(/\s+/g, "-");
        const entry = (n.desktopEntry && DesktopEntries.byId(n.desktopEntry))
                   || DesktopEntries.heuristicLookup(n.desktopEntry || n.appName);
        const names = [n.desktopEntry, entry?.id, entry?.startupClass, n.appName].map(norm).filter(s => s && s !== "notify-send");
        if (names.length === 0)
            return false;
        // Match via h.wayland.appId string comparison instead of h.wayland ===
        // win: identity comparison breaks because QML may give a fresh JS
        // wrapper for the same C++ pointer on each property read.
        const win = Hyprland.toplevels.values.find(h => h.wayland && names.includes(norm(h.wayland.appId)));
        if (win) {
            const addr = win.address.startsWith("0x") ? win.address : "0x" + win.address;
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr}" })`);
            return true;
        }
        if (launch && entry) {
            entry.execute();
            return true;
        }
        return false;
    }

    // A message from a chat with a popup up replaces it, counting up
    // ("3 new"); the earlier ones stay in the history.
    function _show(n) {
        const t = timeoutFor(n);
        const tk = threadKey(n);
        const prev = popups.find(p => p.n && p.n !== n && p.n.tracked && threadKey(p.n) === tk);
        const count = prev ? prev.count + 1 : 1;
        // Hidden like a timed-out popup, so a transient one goes too.
        if (prev)
            hidePopup(prev.n);
        popups = popups.filter(p => p.n !== n).concat([{ n, until: t ? Date.now() + t : 0, count }]);
    }

    // How many messages a popup stands for.
    function popupCount(n) {
        return popups.find(p => p.n === n)?.count ?? 1;
    }

    // Saves when n arrived and its thread, dropping notifications that are
    // gone. JSON strings: a JS object can't move to the reloaded engine.
    function _remember(ns) {
        const arrived = {};
        const threads = {};
        for (const o of root.list) {
            if (root.arrived[o.id])
                arrived[o.id] = root.arrived[o.id];
            if (root.threadOf[o.id])
                threads[o.id] = root.threadOf[o.id];
        }
        for (const n of ns) {
            if (!arrived[n.id])
                arrived[n.id] = Date.now();
            if (!threads[n.id])
                threads[n.id] = _thread(n);
        }
        persist.arrived = JSON.stringify(arrived);
        persist.threads = JSON.stringify(threads);
    }

    function stackTag(n) {
        return n.hints["x-dunst-stack-tag"] ?? n.hints["x-canonical-private-synchronous"] ?? "";
    }

    // dunst is still installed as a D-Bus-activated fallback for when
    // Quickshell is down; if it took the bus name meanwhile, stop it, and
    // the server registers as soon as the name is free.
    Component.onCompleted: {
        Quickshell.execDetached(["pkill", "-x", "dunst"]);
        _backfill();
    }

    // Saves a time and thread for kept notifications that have none: after
    // an edit of this file the singleton starts over with empty maps, and
    // a restore (onReloaded) would come after onCompleted, over its writes.
    function _backfill() {
        const missing = list.filter(n => !arrived[n.id] || !threadOf[n.id]);
        if (missing.length > 0)
            _remember(missing);
    }

    // Reads a sender's picture for _thread; one per read, as a FileView
    // doesn't read again when its path changes.
    Component {
        id: fileReader

        FileView {
            blockLoading: true
            printErrors: false
        }
    }

    // Collapse everything once the drawer has finished closing.
    Connections {
        target: Panels

        function onOpenChanged() {
            if (Panels.open === "notifications")
                collapse.stop();
            else
                collapse.restart();
        }
    }

    Timer {
        id: collapse

        interval: 500 // past the drawer closing
        onTriggered: {
            root.expanded = {};
            root.showAll = {};
        }
    }

    PersistentProperties {
        id: persist

        reloadableId: "notifs"
        property string arrived: "{}"
        property string threads: "{}"

        onReloaded: root._backfill()
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
            // Carried over by a config reload: already seen, no popup again.
            if (n.lastGeneration) {
                n.tracked = true;
                return;
            }
            // Before tracking, so the history groups it right away.
            root._remember([n]);
            n.tracked = true;
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
