pragma Singleton

import QtQuick
import Quickshell

// Look of the old waybar (style.css): flat dark background, JetBrains Mono,
// translucent white buttons with 3px corners. Bar and popups share it.
Singleton {
    readonly property string font: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 14
    readonly property int barFontSize: 15

    // Backgrounds. Popups are a touch more opaque so text behind them
    // doesn't bleed through.
    readonly property color bg: Qt.rgba(23 / 255, 25 / 255, 30 / 255, 0.95)
    readonly property color panelBg: Qt.rgba(23 / 255, 25 / 255, 30 / 255, 0.98)
    readonly property color border: Qt.rgba(60 / 255, 60 / 255, 60 / 255, 0.6)
    // Outer edge of drawers, tooltips and notification popups; brighter than
    // `border` so they stand out against dark wallpapers and windows.
    readonly property color panelBorder: Qt.rgba(1, 1, 1, 0.25)
    readonly property color outline: panelBorder

    // Button-ish surfaces, like `#workspaces button`
    readonly property color surface: Qt.rgba(1, 1, 1, 0.05)
    readonly property color surfaceHigh: Qt.rgba(1, 1, 1, 0.1)
    readonly property color surfaceHighest: Qt.rgba(1, 1, 1, 0.15)

    // Active state, like `#workspaces button.active`
    readonly property color primary: Qt.rgba(1, 1, 1, 0.2)
    readonly property color primaryFg: "#ffffff"

    // Text
    readonly property color fg: "#ffffff"
    readonly property color fgDim: "#cccccc"
    readonly property color fgMuted: "#888888"

    // Accents from style.css
    readonly property color accent: "#41ff2b" // #network
    readonly property color green: "#41ff2b"
    readonly property color yellow: "#f1fa8c"
    readonly property color orange: "#ff9f43"
    readonly property color red: "#ff5555"
    readonly property color urgentBg: Qt.rgba(1, 50 / 255, 50 / 255, 0.4)
    readonly property color urgentBorder: Qt.rgba(1, 100 / 255, 100 / 255, 0.8)
    // Critical notifications (was dunstrc's [urgency_critical]).
    readonly property color criticalBg: Qt.rgba(0x74 / 255, 0x23 / 255, 0x26 / 255, 0.98)

    // Shape
    readonly property int barHeight: 29 // what waybar ends up at with this font
    readonly property int radius: 3
    readonly property int spacing: 8
    readonly property int padding: 12
    readonly property int drawerGap: 4 // drawers off the bar and the screen edge

    // Motion (ms) and M3 "emphasized" curves
    readonly property int fast: 150
    readonly property int normal: 250
    readonly property int slow: 400
    readonly property var emphasized: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
}
