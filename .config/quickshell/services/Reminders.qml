pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Reminders and timers: a JSON list in ~/.local/state, a Qt timer armed for
// the next one due, and an alert when one fires (shown with Snooze / Done
// buttons by Popups.qml). Alerts are
// saved too, so they survive a restart; anything that came due while
// Quickshell wasn't running fires on load, marked as missed.
//
// The calendar drawer builds entries with pickers. For IPC, parse() also
// takes plain words, parsed by GNU `date -d`:
//   "in 20m stretch"        "tomorrow 9am call dentist"
//   "fri 17:00, timesheet"  "every mon 10:00 standup"  "daily 21:00 meds"
// The longest leading run of words that `date` accepts is the time and the
// rest is the text; a comma splits the two explicitly.
Singleton {
    id: root

    // Sorted by due time; each is { id, text, due (ms), repeat, duration },
    // where repeat is "" | "daily" | "weekdays" | "weekly" and duration (ms)
    // is set only on timers (whose text may be empty). A paused timer has
    // paused: true and its `remaining` ms instead of a live due time, and
    // sorts last.
    property var items: []
    readonly property var next: items.find(r => !r.paused) ?? null
    // Fired and not yet dealt with: reminder fields plus { key, missed }.
    property var alerts: []
    property bool ready: false

    readonly property int snoozeMinutes: 10
    // Fired later than this (Quickshell not running, or asleep) = missed.
    readonly property int graceMs: 2 * 60 * 1000

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/reminders.json`

    readonly property var _months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    readonly property var _days: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // ------------------------------------------------------------ editing

    function _entry(e) {
        const r = { id: _newId(), text: e.text ?? "", due: e.due, repeat: e.repeat ?? "" };
        if (e.duration)
            r.duration = e.duration;
        return r;
    }

    function add(entry) {
        _set(items.concat([_entry(entry)]));
    }

    function remove(id) {
        _set(items.filter(r => r.id !== id));
    }

    function replace(id, entry) {
        _set(items.filter(r => r.id !== id).concat([_entry(entry)]));
    }

    function snooze(r) {
        add({ text: title(r), due: Date.now() + snoozeMinutes * 60000 });
    }

    function dismiss(key) {
        alerts = alerts.filter(a => a.key !== key);
        _save();
    }

    function snoozeAlert(key) {
        const a = alerts.find(a => a.key === key);
        alerts = alerts.filter(a => a.key !== key);
        if (a)
            snooze(a); // saves
        else
            _save();
    }

    // An alert from another service (prayer times), which plays its own sound.
    function raise(entry) {
        alerts = alerts.concat([Object.assign({ key: _newId(), missed: false }, entry)]);
        _save();
    }

    function dismissWhere(test) {
        if (!alerts.some(test))
            return;
        alerts = alerts.filter(a => !test(a));
        _save();
    }

    // Second line of an alert.
    function alertText(a) {
        return a.prayer ? `Adhan · ${Qt.formatTime(new Date(a.due), "hh:mm AP")}`
             : a.missed ? `Missed, was due ${formatDue(a.due)}`
             : a.duration ? `${countdown(a.duration)} timer is up`
             : describe(a);
    }

    function title(r) {
        return r.text || "Timer";
    }

    // ------------------------------------------------------------- timers

    function remainingOf(r, now) {
        return r.paused ? r.remaining : Math.max(0, r.due - (now ?? Date.now()));
    }

    function _update(id, change) {
        _set(items.map(r => r.id === id ? change(Object.assign({}, r)) : r));
    }

    function pauseTimer(id) {
        _update(id, r => {
            r.remaining = remainingOf(r);
            r.paused = true;
            return r;
        });
    }

    function resumeTimer(id) {
        _update(id, r => {
            r.due = Date.now() + r.remaining;
            delete r.paused;
            delete r.remaining;
            return r;
        });
    }

    // Back to the full duration, stopped; resume starts it again.
    function resetTimer(id) {
        _update(id, r => {
            r.remaining = r.duration;
            r.paused = true;
            return r;
        });
    }

    // Parse and add in one go (for IPC); confirms or complains in a notification.
    function addFromText(input) {
        parse(input, r => {
            if (r.error) {
                _notifyLow("Couldn't add reminder", `${r.error}: “${input}”`);
                return;
            }
            add(r);
            _notifyLow("Reminder set", `${title(r)} · ${describe(r)}`);
        });
    }

    // ------------------------------------------------------------ parsing

    // Calls back with { due, text, repeat, error }; `due` is 0 when no time
    // was found, `error` is "" when the result can be added as is.
    function parse(input, callback) {
        const s = _split(input);
        const expanded = s.words.map(w => s.fixed ? w.split(/\s+/).map(_expand).join(" ") : _expand(w));
        if (expanded.length === 0) {
            callback({ due: 0, text: "", repeat: s.repeat, error: "Type a time and what to remind you of" });
            return;
        }
        parser.createObject(root, {
            command: ["bash", "-c", _parseScript, "parse"].concat(expanded),
            done: out => callback(_finish(out, s, expanded))
        });
    }

    // Tries the longest prefix of the words first; prints "<words> <epoch>".
    readonly property string _parseScript: 'for ((n=$#; n>0; n--)); do t=$(date -d "${*:1:n}" +%s 2>/dev/null) && { echo "$n $t"; exit 0; }; done; exit 1'

    function _split(input) {
        let s = input.trim();
        let repeat = "";
        const rules = [
            [/^(daily|every\s+day)\b\s*/i, "daily"],
            [/^(weekdays|every\s+weekday)\b\s*/i, "weekdays"],
            [/^(weekly|every\s+week)\b\s*/i, "weekly"],
            [/^every\s+(?=(mon|tue|wed|thu|fri|sat|sun))/i, "weekly"]
        ];
        for (const [re, r] of rules) {
            if (re.test(s)) {
                repeat = r;
                s = s.replace(re, "");
                break;
            }
        }
        const comma = s.indexOf(",");
        if (comma >= 0) {
            const when = s.slice(0, comma).trim();
            return { repeat, fixed: true, words: when ? [when] : [], rest: s.slice(comma + 1).trim() };
        }
        return { repeat, fixed: false, words: s.split(/\s+/).filter(w => w), rest: "" };
    }

    // Turns one typed word into something `date -d` understands.
    function _expand(word) {
        const w = word.toLowerCase();
        if (w === "at" || w === "in" || w === "on")
            return "";
        if (w === "noon")
            return "12:00";
        if (w === "midnight")
            return "00:00";
        // A lone letter is a military time zone to `date` ("5pm a" = 5pm UTC+1).
        if (/^[a-z]$/.test(w))
            return "@@";
        const units = { w: "weeks", d: "days", h: "hours", m: "minutes", s: "seconds" };
        if (/^(\d+[wdhms])+$/.test(w))
            return w.replace(/(\d+)([wdhms])/g, (_, n, u) => `${n} ${units[u]} `).trim();
        return word;
    }

    function _finish(out, s, expanded) {
        const result = { due: 0, text: "", repeat: s.repeat, error: "" };
        const m = out.trim().match(/^(\d+) (-?\d+)$/);
        let n = m ? parseInt(m[1]) : 0;
        // Filler words ("at", "in") at the end belong to the text.
        while (n > 0 && expanded[n - 1] === "")
            n--;
        if (n === 0) {
            result.error = "No time found";
            return result;
        }
        const when = expanded.slice(0, n).join(" ").trim();
        result.text = s.fixed ? s.rest : s.words.slice(n).join(" ");

        const now = Date.now();
        const d = new Date(parseInt(m[2]) * 1000);
        // A bare day ("fri", "Oct 9") means 9 AM, not midnight.
        if (!/\d|midnight/i.test(when) && d.getHours() === 0 && d.getMinutes() === 0 && d.getSeconds() === 0)
            d.setHours(9);

        if (s.repeat) {
            result.due = upcoming(d.getTime(), s.repeat, now);
        } else if (d.getTime() > now) {
            result.due = d.getTime();
        } else if (/^[\d:\s]*(am|pm)?$/i.test(when)) {
            d.setDate(d.getDate() + 1); // "15:30" when it's later than that
            result.due = d.getTime();
        } else if (/\b(mon|tue|wed|thu|fri|sat|sun)/i.test(when) && !/\b(last|ago)\b/i.test(when)) {
            d.setDate(d.getDate() + 7); // "mon 9am" on a Monday afternoon
            result.due = d.getTime();
        } else {
            result.due = d.getTime();
            result.error = "That's in the past";
        }

        if (!result.error && result.text === "")
            result.error = "Remind you of what?";
        return result;
    }

    // ---------------------------------------------------------- recurrence

    function _step(ms, repeat) {
        const d = new Date(ms);
        do
            d.setDate(d.getDate() + (repeat === "weekly" ? 7 : 1));
        while (repeat === "weekdays" && (d.getDay() === 0 || d.getDay() === 6));
        return d.getTime();
    }

    // First occurrence of a series after `now`, keeping its time of day.
    function upcoming(ms, repeat, now) {
        const day = new Date(ms).getDay();
        if (repeat === "weekdays" && (day === 0 || day === 6))
            ms = _step(ms, repeat);
        while (ms <= now)
            ms = _step(ms, repeat);
        return ms;
    }

    // ---------------------------------------------------------- formatting

    function _dayDiff(ms, now) {
        const a = new Date(ms), b = now ?? new Date();
        return Math.round((new Date(a.getFullYear(), a.getMonth(), a.getDate()) - new Date(b.getFullYear(), b.getMonth(), b.getDate())) / 86400000);
    }

    // "03:30 PM", "Tomorrow 09:00 AM", "Fri 05:00 PM", "Oct 14 09:00 AM"
    // Pass `now` (e.g. a SystemClock's date) to re-evaluate when the day changes.
    function formatDue(ms, now) {
        const d = new Date(ms);
        const time = Qt.formatTime(d, "hh:mm AP");
        const diff = _dayDiff(ms, now);
        if (diff === 0)
            return time;
        if (diff === 1)
            return `Tomorrow ${time}`;
        if (diff === -1)
            return `Yesterday ${time}`;
        if (diff > 1 && diff < 7)
            return `${_days[d.getDay()]} ${time}`;
        const year = d.getFullYear() !== (now ?? new Date()).getFullYear() ? ` ${d.getFullYear()}` : "";
        return `${_months[d.getMonth()]} ${d.getDate()}${year} ${time}`;
    }

    // "Daily at 09:00 PM", "Every Fri at 05:00 PM", "10m timer · ends
    // 05:30 PM", or the one-off time.
    function describe(r, now) {
        const time = Qt.formatTime(new Date(r.due), "hh:mm AP");
        if (r.duration && r.paused)
            return `${countdown(r.remaining)} left · paused`;
        if (r.duration)
            return `${countdown(r.duration)} timer · ends ${formatDue(r.due, now)}`;
        if (r.repeat === "daily")
            return `Daily at ${time}`;
        if (r.repeat === "weekdays")
            return `Weekdays at ${time}`;
        if (r.repeat === "weekly")
            return `Every ${_days[new Date(r.due).getDay()]} at ${time}`;
        return formatDue(r.due, now);
    }

    // "<1m", "25m", "2h 5m"
    function countdown(ms) {
        const m = Math.ceil(ms / 60000);
        if (m < 1)
            return "<1m";
        if (m < 60)
            return `${m}m`;
        return m % 60 ? `${Math.floor(m / 60)}h ${m % 60}m` : `${m / 60}h`;
    }

    // ------------------------------------------------------------- firing

    function _check() {
        if (!ready)
            return;
        const now = Date.now();
        const due = items.filter(r => !r.paused && r.due <= now);
        if (due.length === 0) {
            _arm();
            return;
        }
        const keep = items.filter(r => !due.includes(r));
        for (const r of due) {
            _fire(r, now - r.due > graceMs);
            if (r.repeat)
                keep.push(Object.assign({}, r, { due: upcoming(r.due, r.repeat, now) }));
        }
        _set(keep);
    }

    // Poll at least every 30 s: timers don't count time spent suspended.
    function _arm() {
        if (!ready || next === null) {
            timer.stop();
            return;
        }
        timer.interval = Math.max(50, Math.min(next.due - Date.now(), 30000));
        timer.restart();
    }

    // Saved by the caller.
    function _fire(r, missed) {
        alerts = alerts.concat([Object.assign({}, r, { key: _newId(), missed })]);
        Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"]);
    }

    function _notifyLow(title, body) {
        // Notification bodies are markup and this one may hold typed text.
        const escaped = body.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        Quickshell.execDetached(["notify-send", "-a", "Reminder", "-u", "low", "-t", "4000", title, escaped]);
    }

    // ------------------------------------------------------------ storage

    function _newId() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    }

    // Last text saved, so reloading our own write is skipped.
    property string _written: ""

    function _sorted(list) {
        return list.slice().sort((a, b) => (!!a.paused - !!b.paused) || a.due - b.due);
    }

    function _set(list) {
        items = _sorted(list);
        _save();
        _arm();
    }

    function _save() {
        _written = JSON.stringify({ reminders: items, alerts }, null, 2) + "\n";
        file.setText(_written);
    }

    function _load(text) {
        const valid = r => r && typeof r.text === "string" && typeof r.due === "number";
        try {
            const data = JSON.parse(text);
            items = _sorted((data.reminders ?? []).filter(valid));
            alerts = (data.alerts ?? []).filter(a => valid(a) && a.key);
        } catch (e) {
            console.warn(`Reminders: ignoring unreadable ${path}: ${e}`);
            items = [];
            alerts = [];
        }
        ready = true;
        _check();
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", path.replace(/\/[^/]*$/, "")])

    FileView {
        id: file

        path: root.path
        // Hand edits to the file are picked up too.
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (text() !== root._written) root._load(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.ready = true;
                root._arm();
            } else {
                console.warn(`Reminders: can't read ${root.path} (${error})`);
            }
        }
    }

    Timer {
        id: timer
        onTriggered: root._check()
    }

    Component {
        id: parser

        Process {
            id: proc

            property var done

            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    proc.done(text);
                    proc.destroy();
                }
            }
        }
    }
}
