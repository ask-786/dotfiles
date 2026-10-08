pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Polls /proc and /sys for the numbers waybar used to work out by itself:
// cpu, memory, network throughput/address, temperature and backlight.
Singleton {
    id: root

    property int cpu: 0

    // Memory, in GiB
    property real memUsed: 0
    property real memTotal: 0
    property int memPercent: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property int swapPercent: 0

    // Network: the interface carrying the default route
    property string iface: ""
    property string gateway: ""
    property string ipAddr: ""
    property int ipPrefix: 0
    property real rxRate: 0 // bytes/s
    property real txRate: 0

    property int temp: 0 // °C
    property int brightness: 0 // %

    // Only quick settings shows cpu, memory, temperature and brightness, so
    // poll those just while it's open; the bar needs only the network.
    readonly property bool detailed: Panels.open === "quick"

    onDetailedChanged: {
        if (detailed) {
            _pollDetails();
        } else {
            _cpuPrev = null;
        }
    }

    property var _cpuPrev: null
    property var _netPrev: null
    property string _tempPath: ""
    property string _backlightDir: ""
    property int _brightnessMax: 0

    // Matches waybar's {bandwidthDownBytes}: SI units, one decimal. At most
    // 9 characters ("999.9kB/s"): 999.95 and up would round to "1000.0", so
    // move to the next unit there.
    function formatRate(bytes) {
        const units = ["B", "kB", "MB", "GB"];
        let i = 0;
        while (bytes >= 999.95 && i < units.length - 1) {
            bytes /= 1000;
            i++;
        }
        return bytes.toFixed(1) + units[i] + "/s";
    }

    // Slider drags fire fast; run one brightnessctl at a time and apply the
    // latest value when it finishes.
    property int _pendingBrightness: -1

    // Floor of 2% (not 0) so the slider can't black out the panel.
    function setBrightness(percent) {
        brightness = Math.max(2, Math.min(100, Math.round(percent)));
        _pendingBrightness = brightness;
        if (!brightnessProc.running)
            _applyBrightness();
    }

    function _applyBrightness() {
        if (_pendingBrightness < 0)
            return;
        brightnessProc.command = ["brightnessctl", "-q", "set", `${_pendingBrightness}%`];
        _pendingBrightness = -1;
        brightnessProc.running = true;
    }

    function _parseCpu(text) {
        const f = text.split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
        const idle = f[3] + f[4];
        const total = f.reduce((a, b) => a + b, 0);
        if (_cpuPrev) {
            const dt = total - _cpuPrev.total;
            if (dt > 0)
                cpu = Math.round(100 * (1 - (idle - _cpuPrev.idle) / dt));
        }
        _cpuPrev = { idle, total };
    }

    function _parseMem(text) {
        const kb = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                kb[m[1]] = Number(m[2]);
        }
        const gib = 1024 * 1024;
        memTotal = kb.MemTotal / gib;
        memUsed = (kb.MemTotal - kb.MemAvailable) / gib;
        memPercent = Math.round(100 * memUsed / memTotal);
        swapTotal = kb.SwapTotal / gib;
        swapUsed = (kb.SwapTotal - kb.SwapFree) / gib;
        swapPercent = swapTotal > 0 ? Math.round(100 * swapUsed / swapTotal) : 0;
    }

    function _parseRoute(text) {
        let best = null;
        for (const line of text.split("\n").slice(1)) {
            const f = line.trim().split(/\s+/);
            if (f.length < 8 || f[1] !== "00000000")
                continue;
            const metric = Number(f[6]);
            if (!best || metric < best.metric)
                best = { iface: f[0], gw: f[2], metric };
        }
        if (!best) {
            iface = "";
            gateway = "";
            return;
        }
        // Gateway is a little-endian hex IPv4 address.
        const gw = [];
        for (let i = 6; i >= 0; i -= 2)
            gw.push(parseInt(best.gw.substr(i, 2), 16));
        gateway = gw.join(".");
        if (iface !== best.iface) {
            iface = best.iface;
            _netPrev = null;
            ipProc.running = true;
        }
    }

    function _parseNetDev(text) {
        if (!iface) {
            rxRate = txRate = 0;
            return;
        }
        for (const line of text.split("\n")) {
            const parts = line.split(":");
            if (parts.length !== 2 || parts[0].trim() !== iface)
                continue;
            const f = parts[1].trim().split(/\s+/).map(Number);
            const now = Date.now();
            if (_netPrev) {
                const dt = (now - _netPrev.time) / 1000;
                if (dt > 0) {
                    rxRate = Math.max(0, (f[0] - _netPrev.rx) / dt);
                    txRate = Math.max(0, (f[8] - _netPrev.tx) / dt);
                }
            }
            _netPrev = { rx: f[0], tx: f[8], time: now };
            return;
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root._parseCpu(text())
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: root._parseMem(text())
    }

    FileView {
        id: routeFile
        path: "/proc/net/route"
        onLoaded: root._parseRoute(text())
    }

    FileView {
        id: netDevFile
        path: "/proc/net/dev"
        onLoaded: root._parseNetDev(text())
    }

    FileView {
        id: tempFile
        path: root._tempPath
        onLoaded: root.temp = Math.round(Number(text()) / 1000)
    }

    FileView {
        id: brightnessFile
        path: root._backlightDir ? root._backlightDir + "/brightness" : ""
        onLoaded: {
            if (root._brightnessMax > 0)
                root.brightness = Math.round(100 * Number(text()) / root._brightnessMax);
        }
    }

    FileView {
        path: root._backlightDir ? root._backlightDir + "/max_brightness" : ""
        onLoaded: {
            root._brightnessMax = Number(text());
            brightnessFile.reload();
        }
    }

    function _pollDetails() {
        statFile.reload();
        memFile.reload();
        if (_tempPath)
            tempFile.reload();
        if (_backlightDir)
            brightnessFile.reload();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            routeFile.reload();
            netDevFile.reload();
            if (root.detailed)
                root._pollDetails();
        }
    }

    // Address can change without the interface changing (DHCP renew, VPN).
    Timer {
        interval: 5000
        running: root.iface !== ""
        repeat: true
        onTriggered: ipProc.running = true
    }

    Process {
        id: ipProc
        command: ["ip", "-j", "-4", "addr", "show", "dev", root.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text)[0]?.addr_info?.[0];
                    root.ipAddr = info?.local ?? "";
                    root.ipPrefix = info?.prefixlen ?? 0;
                } catch (e) {
                    root.ipAddr = "";
                }
            }
        }
    }

    // Prefer the CPU package sensor (Intel coretemp, AMD k10temp/zenpower);
    // fall back to what waybar read. ACPI zones can be static (the HP's
    // acpitz always reads 10°C), so they're the last resort.
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do case \"$(cat $d/name)\" in coretemp|k10temp|zenpower) echo $d/temp1_input; exit ;; esac; done; echo /sys/class/thermal/thermal_zone0/temp"]
        stdout: StdioCollector {
            onStreamFinished: root._tempPath = text.trim()
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root._backlightDir = text.trim()
        }
    }

    Process {
        id: brightnessProc
        onExited: root._pendingBrightness >= 0 ? root._applyBrightness() : brightnessFile.reload()
    }
}
