pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Prayer times from AlAdhan (api.aladhan.com, free, no key), fetched a month
// at a time and cached in ~/.local/state, so they keep working offline. At
// each of the five prayers an alert pops up (next to the reminders' alerts,
// see Popups.qml) and the adhan plays, unless the sound is turned off for
// just the popup. The location is picked in the
// calendar drawer (a city search, or a guess from the IP address) and saved
// with the cache; the switch there turns all of it off, fetching included.
Singleton {
    id: root

    // ------------------------------------------------------------ settings

    // https://aladhan.com/calculation-methods: 1 Karachi, 2 ISNA, 3 MWL,
    // 4 Umm al-Qura, 5 Egypt, ...
    readonly property int method: 1
    // Asr: 0 standard (Shafi'i, Maliki, Hanbali), 1 Hanafi.
    readonly property int school: 0
    // Minutes added to a prayer to match a local timetable, e.g. ({ Isha: 2 }).
    readonly property var offsets: ({})
    readonly property string sound: `${Quickshell.env("HOME")}/.local/share/sounds/adhan.mp3`
    // Downloaded to `sound` when that's missing (a fresh install).
    readonly property string soundUrl: "https://cdn.aladhan.com/audio/adhans/a1.mp3"
    // Played for Fajr instead, when set (an adhan with "as-salatu khayrun
    // min an-nawm").
    readonly property string fajrSound: ""

    // ---------------------------------------------------------------- state

    readonly property var names: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    property bool enabled: true
    property bool playAdhan: true
    // { name, detail, latitude, longitude }, or null until one is picked.
    property var location: null
    // Cached days, "2026-10-06": { Fajr: ms, ... } (before offsets).
    property var days: ({})
    property bool ready: false
    property bool failed: false
    readonly property bool playing: player.running

    // Fired later than this (asleep, or Quickshell not running) = skipped:
    // an adhan out of the blue long after the time is worse than none.
    readonly property int graceMs: 2 * 60 * 1000
    readonly property int retryMs: 5 * 60 * 1000

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/prayer.json`
    // What the cache was fetched for; changing a setting refetches.
    readonly property string _source: location ? `${location.latitude},${location.longitude},${method},${school}` : ""

    property real _checked: Date.now() // prayers up to here are dealt with
    property real _failedAt: 0
    property var _loading: [] // being fetched, "<_source>|2026-10"
    property real _soundCheckedAt: 0

    // -------------------------------------------------------------- reading

    function _pad(n) {
        return String(n).padStart(2, "0");
    }

    // "2026-10-06", in local time.
    function dayKey(d) {
        return `${d.getFullYear()}-${_pad(d.getMonth() + 1)}-${_pad(d.getDate())}`;
    }

    // A day's five as [{ name, at }], or [] if they aren't fetched (yet).
    function timesOn(key) {
        const day = days[key];
        return day ? names.map(name => ({ name, at: day[name] + (offsets[name] ?? 0) * 60000 })) : [];
    }

    function nextAfter(ms) {
        const d = new Date(ms);
        const tomorrow = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
        return timesOn(dayKey(d)).concat(timesOn(dayKey(tomorrow))).find(t => t.at > ms) ?? null;
    }

    // ------------------------------------------------------------- control

    function setEnabled(on) {
        enabled = on;
        _checked = Date.now();
        _failedAt = 0;
        _soundCheckedAt = 0;
        if (!on) {
            stop();
            Reminders.dismissWhere(a => a.prayer);
        }
        _save();
        _tick();
    }

    function setPlayAdhan(on) {
        playAdhan = on;
        _soundCheckedAt = 0;
        if (!on)
            stop();
        _save();
        _tick();
    }

    function setLocation(place) {
        location = { name: place.name, detail: place.detail, latitude: place.latitude, longitude: place.longitude };
        days = {};
        failed = false;
        _failedAt = 0;
        _save();
        _tick();
    }

    // Places matching a typed name, as [{ name, detail, latitude, longitude }]
    // (Open-Meteo's geocoding, free, no key); null when the search failed.
    function search(query, done) {
        _get(`https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=5`, data => {
            done(data ? (data.results ?? []).map(r => ({
                name: r.name,
                detail: [r.admin1, r.country].filter(x => x).join(", "),
                latitude: r.latitude,
                longitude: r.longitude
            })) : null);
        });
    }

    // A guess from the IP address (ipinfo.io): one place, or null. It's
    // where the ISP routes from, which can be another town.
    function detect(done) {
        _get("https://ipinfo.io/json", data => {
            const [lat, lon] = (data?.loc ?? "").split(",").map(Number);
            done(data && !isNaN(lat) && !isNaN(lon) ? {
                name: data.city || "Detected location",
                detail: [data.region, data.country].filter(x => x).join(", "),
                latitude: lat,
                longitude: lon
            } : null);
        });
    }

    // Calls back with the parsed JSON, or null.
    function _get(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            try {
                if (xhr.status === 200)
                    data = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (!data)
                console.warn(`Prayer: ${url} failed (HTTP ${xhr.status})`);
            done(data);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function stop() {
        player.running = false;
    }

    // The next prayer's alert and adhan, right now (to try the sound).
    function test() {
        _fire(nextAfter(Date.now()) ?? { name: "Fajr", at: Date.now() });
    }

    // ------------------------------------------------------------- firing

    function _tick() {
        if (!ready || !enabled) {
            timer.stop();
            return;
        }
        const now = Date.now();
        const since = new Date(_checked);
        const seen = new Set();
        const due = timesOn(dayKey(since)).concat(timesOn(dayKey(new Date(now))))
            .filter(t => t.at > _checked && t.at <= now && !seen.has(t.at) && seen.add(t.at));
        _checked = now;
        const last = due[due.length - 1];
        if (last && now - last.at <= graceMs)
            _fire(last);

        _fetchMissing(now);
        if (playAdhan)
            _fetchSound(now);
        // Poll at least every 30 s: timers don't count time spent suspended.
        const next = nextAfter(now);
        timer.interval = next ? Math.max(50, Math.min(next.at - now, 30000)) : 30000;
        timer.restart();
    }

    function _fire(t) {
        Reminders.dismissWhere(a => a.prayer);
        Reminders.raise({ text: t.name, due: t.at, prayer: true });
        if (!playAdhan)
            return;
        // Falls back to a chime if the adhan file is missing.
        player.exec(["sh", "-c", 'f=$1; [ -r "$f" ] || f=/usr/share/sounds/freedesktop/stereo/complete.oga; exec pw-play --media-role Notification "$f"',
            "adhan", t.name === "Fajr" && fajrSound ? fajrSound : sound]);
    }

    // ------------------------------------------------------------ fetching

    // Today's and tomorrow's months, unless a fetch failed a moment ago.
    function _fetchMissing(now) {
        if (!location || now - _failedAt < retryMs)
            return;
        const d = new Date(now);
        for (const day of [d, new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)]) {
            if (!days[dayKey(day)])
                _fetch(day.getFullYear(), day.getMonth() + 1);
        }
    }

    // Checked every few minutes rather than once: the file can go missing
    // later, and this object outlives config reloads that don't touch it.
    function _fetchSound(now) {
        if (soundGet.running || now - _soundCheckedAt < retryMs)
            return;
        _soundCheckedAt = now;
        soundGet.exec(["sh", "-c", 'f=$1; [ -s "$f" ] && exit 0; mkdir -p "${f%/*}" && curl -sfL --max-time 300 -o "$f.part" "$2" && mv "$f.part" "$f" || { rm -f "$f.part"; exit 1; }',
            "adhan", sound, soundUrl]);
    }

    function _fetch(year, month) {
        const source = _source;
        const key = `${source}|${year}-${_pad(month)}`;
        if (_loading.includes(key))
            return;
        _loading = _loading.concat([key]);
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            _loading = _loading.filter(k => k !== key);
            if (source !== _source)
                return; // the location changed meanwhile
            try {
                if (xhr.status !== 200)
                    throw `HTTP ${xhr.status || "request failed"}`;
                const added = {};
                for (const d of JSON.parse(xhr.responseText).data) {
                    const [dd, mm, yyyy] = d.date.gregorian.date.split("-");
                    const times = {};
                    for (const name of names) {
                        times[name] = Date.parse(d.timings[name]);
                        if (isNaN(times[name]))
                            throw `unreadable time “${d.timings[name]}”`;
                    }
                    added[`${yyyy}-${mm}-${dd}`] = times;
                }
                // Keep this month and later.
                const first = dayKey(new Date()).slice(0, 8) + "01";
                const merged = Object.assign({}, days, added);
                for (const k of Object.keys(merged))
                    if (k < first)
                        delete merged[k];
                days = merged;
                failed = false;
                _failedAt = 0;
                _save();
                _tick();
            } catch (e) {
                console.warn(`Prayer: can't fetch ${key}: ${e}`);
                failed = true;
                _failedAt = Date.now();
            }
        };
        xhr.open("GET", `https://api.aladhan.com/v1/calendar/${year}/${month}?latitude=${location.latitude}&longitude=${location.longitude}&method=${method}&school=${school}&iso8601=true`);
        xhr.send();
    }

    // ------------------------------------------------------------ storage

    function _save() {
        file.setText(JSON.stringify({ enabled, playAdhan, location, source: _source, days }) + "\n");
    }

    function _load(text) {
        try {
            const data = JSON.parse(text);
            enabled = data.enabled !== false;
            playAdhan = data.playAdhan !== false;
            const l = data.location;
            if (l && typeof l.name === "string" && typeof l.latitude === "number" && typeof l.longitude === "number")
                location = l;
            days = data.source === _source && data.days ? data.days : {};
        } catch (e) {
            console.warn(`Prayer: ignoring unreadable ${path}: ${e}`);
        }
        ready = true;
        _tick();
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        // Only the first load; later ones are our own writes.
        onLoaded: if (!root.ready) root._load(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn(`Prayer: can't read ${root.path} (${error})`);
            root.ready = true;
            root._tick();
        }
    }

    Timer {
        id: timer
        onTriggered: root._tick()
    }

    Process {
        id: player
    }

    Process {
        id: soundGet
        onExited: code => {
            if (code !== 0)
                console.warn(`Prayer: can't download the adhan from ${root.soundUrl}`);
        }
    }
}
