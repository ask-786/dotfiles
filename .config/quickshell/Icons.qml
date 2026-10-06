pragma Singleton

import QtQuick
import Quickshell

// Material Design glyphs from the Nerd Font (nf-md-*), plus helpers that pick
// the right one for a level.
Singleton {
    readonly property string wifiOff: "\u{F092E}"
    readonly property string wifiNone: "\u{F092F}"
    readonly property var wifiLevels: ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"]
    readonly property string ethernet: "\u{F0200}"
    readonly property string lock: "\u{F033E}"

    readonly property string bluetooth: "\u{F00AF}"
    readonly property string bluetoothConnected: "\u{F00B1}"
    readonly property string bluetoothOff: "\u{F00B2}"

    readonly property string volumeOff: "\u{F0581}"
    readonly property var volumeLevels: ["\u{F057F}", "\u{F0580}", "\u{F057E}"]
    readonly property string mic: "\u{F036C}"
    readonly property string micOff: "\u{F036D}"
    readonly property string headphones: "\u{F02CB}"
    readonly property string headset: "\u{F02CE}"
    readonly property string speaker: "\u{F04C3}"
    readonly property string brightness: "\u{F00DF}"

    readonly property var batteryLevels: ["\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}", "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"]
    readonly property string batteryCharging: "\u{F0084}"
    readonly property string plug: "\u{F06A5}"
    readonly property string batteryAlert: "\u{F10CD}"

    readonly property string night: "\u{F0594}"
    readonly property string bell: "\u{F009A}"
    readonly property string bellOff: "\u{F009B}"
    readonly property string bellRing: "\u{F009E}"
    readonly property string bellPlus: "\u{F009D}"
    readonly property string bellOutline: "\u{F009C}"
    readonly property string alarm: "\u{F0020}"
    readonly property string mosque: "\u{F1827}"
    readonly property string mapMarker: "\u{F034E}"
    readonly property string crosshairs: "\u{F01A4}"
    readonly property string magnify: "\u{F0349}"
    readonly property string coffee: "\u{F0176}"
    readonly property string leaf: "\u{F032A}"
    readonly property string balance: "\u{F05D1}"
    readonly property string rocket: "\u{F14DE}"

    readonly property string cpu: "\u{F0EE0}"
    readonly property string memory: "\u{F035B}"
    readonly property string thermometer: "\u{F050F}"
    readonly property string down: "\u{F19B3}"
    readonly property string up: "\u{F19B2}"
    readonly property string keyboard: "\u{F030C}"

    readonly property string power: "\u{F0425}"
    readonly property string restart: "\u{F0709}"
    readonly property string logout: "\u{F0343}"
    readonly property string sleep: "\u{F04B2}"
    readonly property string cog: "\u{F0493}"
    readonly property string refresh: "\u{F0450}"

    readonly property string music: "\u{F075A}"
    readonly property string play: "\u{F040A}"
    readonly property string pause: "\u{F03E4}"
    readonly property string previous: "\u{F04AE}"
    readonly property string next: "\u{F04AD}"
    readonly property string shuffle: "\u{F049D}"
    readonly property string shuffleOff: "\u{F049E}"
    readonly property string repeat: "\u{F0456}"
    readonly property string repeatOnce: "\u{F0458}"
    readonly property string repeatOff: "\u{F0457}"

    readonly property string chevronRight: "\u{F0142}"
    readonly property string chevronLeft: "\u{F0141}"
    readonly property string chevronUp: "\u{F0143}"
    readonly property string chevronDown: "\u{F0140}"
    readonly property string plus: "\u{F0415}"
    readonly property string timer: "\u{F051B}"
    readonly property string calendar: "\u{F00F6}"
    readonly property string clock: "\u{F0150}"
    readonly property string check: "\u{F012C}"
    readonly property string close: "\u{F0156}"

    function level(list, fraction) {
        return list[Math.max(0, Math.min(list.length - 1, Math.floor(fraction * list.length)))];
    }

    function forDevice(name) {
        if (/headset/.test(name))
            return headset;
        if (/headphone|audio-card/.test(name))
            return headphones;
        if (/keyboard/.test(name))
            return keyboard;
        if (/phone/.test(name))
            return "\u{F011C}";
        if (/mouse/.test(name))
            return "\u{F037D}";
        if (/speaker|audio/.test(name))
            return speaker;
        return bluetooth;
    }
}
