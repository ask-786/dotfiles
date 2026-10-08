import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services

// GNOME-style quick settings: battery + power, sliders, toggle tiles and
// system stats. Wi-Fi, Bluetooth and Sound open detail pages that slide in.
Drawer {
    id: root

    name: "quick"
    align: Qt.AlignRight
    contentWidth: 400

    property string page: "" // "" = main, or "wifi" | "bluetooth" | "audio"
    property string detail: "" // last detail page, kept while sliding back
    property bool powerMenu: false

    function go(target) {
        page = target;
    }

    function run(cmd) {
        Panels.close();
        Quickshell.execDetached(cmd);
    }

    onOpenChanged: {
        if (open) {
            page = Panels.page;
        } else {
            page = "";
            powerMenu = false;
        }
    }

    Connections {
        target: Panels

        function onPageChanged() {
            if (root.open)
                root.page = Panels.page;
        }
    }

    onPageChanged: {
        if (page)
            detail = page;
        Net.setScanning(page === "wifi");
        if (page !== "bluetooth" && Bt.adapter?.discovering)
            Bt.adapter.discovering = false;
        // Pairing questions show on this page while it's up, else as popups.
        if (page === "bluetooth")
            Bt.pageScreen = root.bar.screenName;
        else if (Bt.pageScreen === root.bar.screenName)
            Bt.pageScreen = "";
    }

    Item {
        id: pages

        width: parent.width
        implicitHeight: root.page ? detailLoader.implicitHeight : mainPage.implicitHeight
        clip: true

        Item {
            x: root.page ? -pages.width - Theme.padding : 0
            width: pages.width

            Behavior on x {
                NumberAnimation {
                    duration: Theme.slow
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.emphasized
                }
            }

            MainPage {
                id: mainPage
                width: pages.width
            }

            Loader {
                id: detailLoader

                x: pages.width + Theme.padding
                width: pages.width
                sourceComponent: root.detail === "wifi" ? wifiPage
                               : root.detail === "bluetooth" ? bluetoothPage
                               : root.detail === "audio" ? audioPage : null
            }
        }
    }

    // ---------------------------------------------------------------- main

    component MainPage: Column {
        spacing: 14

        // Battery summary + lock/power buttons
        Item {
            width: parent.width
            height: 44

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                visible: Battery.available

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Battery.icon
                    size: 28
                    color: Battery.low ? Theme.red : Battery.charging ? Theme.green : Theme.fg
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: `${Battery.percent}%`
                        font.pixelSize: Theme.fontSize + 4
                        font.bold: true
                    }
                    StyledText {
                        text: Battery.status
                        color: Theme.fgDim
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            // Small clock, handy while the bar is hidden over fullscreen windows.
            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Column {
                anchors.right: headerButtons.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    anchors.right: parent.right
                    text: Qt.formatTime(clock.date, "hh:mm AP")
                    font.bold: true
                }
                StyledText {
                    anchors.right: parent.right
                    text: Qt.formatDate(clock.date, "ddd, MMM d")
                    color: Theme.fgDim
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            Row {
                id: headerButtons

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Devices panel (per-bud battery and the like), also SUPER+B
                IconButton {
                    icon: Icons.devices
                    active: Panels.isOpen("devices", root.bar.screenName)
                    onClicked: Panels.toggle("devices", root.bar.screenName)
                }
                IconButton {
                    icon: Icons.lock
                    onClicked: root.run(["loginctl", "lock-session"])
                }
                IconButton {
                    icon: Icons.power
                    active: root.powerMenu
                    onClicked: root.powerMenu = !root.powerMenu
                }
            }
        }

        // Power actions, revealed by the power button
        Item {
            width: parent.width
            height: root.powerMenu ? powerRow.implicitHeight : 0
            visible: height > 0
            clip: true
            opacity: root.powerMenu ? 1 : 0

            Behavior on height {
                NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.normal }
            }

            Row {
                id: powerRow

                readonly property real itemWidth: (width - 3 * spacing) / 4

                width: parent.width
                spacing: 8

                PowerButton {
                    width: powerRow.itemWidth
                    icon: Icons.sleep
                    label: "Suspend"
                    confirm: false
                    onActivated: root.run(["systemctl", "suspend"])
                }
                PowerButton {
                    width: powerRow.itemWidth
                    icon: Icons.logout
                    label: "Log out"
                    onActivated: root.run(["hyprshutdown"])
                }
                PowerButton {
                    width: powerRow.itemWidth
                    icon: Icons.restart
                    label: "Restart"
                    onActivated: root.run(["systemctl", "reboot"])
                }
                PowerButton {
                    width: powerRow.itemWidth
                    icon: Icons.power
                    label: "Shut down"
                    onActivated: root.run(["systemctl", "poweroff"])
                }
            }
        }

        // Sliders
        Column {
            width: parent.width
            spacing: 8

            Row {
                width: parent.width
                spacing: 8

                StyledSlider {
                    width: parent.width - 42
                    icon: Audio.icon
                    value: Audio.volume
                    dimmed: Audio.muted
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.chevronRight
                    onClicked: root.go("audio")
                }
            }

            StyledSlider {
                width: parent.width - 42
                visible: Audio.source !== null
                icon: Audio.micMuted ? Icons.micOff : Icons.mic
                value: Audio.micVolume
                dimmed: Audio.micMuted
                onMoved: v => Audio.setMicVolume(v)
                onIconClicked: Audio.toggleMic()
            }

            StyledSlider {
                width: parent.width - 42
                visible: Stats._backlightDir !== ""
                icon: Icons.brightness
                value: Stats.brightness / 100
                onMoved: v => Stats.setBrightness(v * 100)
            }
        }

        // Toggle tiles
        Grid {
            id: tiles

            readonly property real tileWidth: (width - columnSpacing) / 2

            width: parent.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Tile {
                width: tiles.tileWidth
                icon: Net.icon
                title: "Wi-Fi"
                subtitle: Net.label
                active: Net.wifiEnabled
                hasDetails: true
                onToggled: Net.toggleWifi()
                onDetailsRequested: root.go("wifi")
            }
            Tile {
                width: tiles.tileWidth
                icon: Bt.icon
                title: "Bluetooth"
                subtitle: Bt.label
                active: Bt.enabled
                hasDetails: true
                onToggled: Bt.toggle()
                onDetailsRequested: root.go("bluetooth")
            }
            Tile {
                width: tiles.tileWidth
                icon: [Icons.leaf, Icons.balance, Icons.rocket][PowerProfiles.profile] ?? Icons.balance
                title: "Power mode"
                subtitle: System.profileName
                active: PowerProfiles.profile !== PowerProfile.Balanced
                onToggled: System.cycleProfile()
            }
            Tile {
                width: tiles.tileWidth
                icon: Icons.night
                title: "Night light"
                subtitle: System.nightLight ? `${System.nightTemperature} K` : "Off"
                active: System.nightLight
                onToggled: System.toggleNightLight()
            }
            Tile {
                width: tiles.tileWidth
                icon: System.dnd ? Icons.bellOff : Icons.bell
                title: "Do not disturb"
                subtitle: System.dnd ? "Notifications paused" : "Off"
                active: System.dnd
                onToggled: System.toggleDnd()
            }
            Tile {
                width: tiles.tileWidth
                icon: Icons.coffee
                title: "Caffeine"
                subtitle: System.caffeine ? "Staying awake" : "Off"
                active: System.caffeine
                onToggled: System.caffeine = !System.caffeine
            }
        }

        // System stats
        Rectangle {
            width: parent.width
            height: stats.implicitHeight + 24
            radius: Theme.radius
            color: Theme.surface

            Column {
                id: stats

                x: 14
                y: 12
                width: parent.width - 28
                spacing: 12

                Grid {
                    id: statGrid

                    readonly property real cellWidth: (width - columnSpacing) / 2

                    width: parent.width
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    StatBar {
                        width: statGrid.cellWidth
                        icon: Icons.cpu
                        label: "CPU"
                        value: `${Stats.cpu}%`
                        fraction: Stats.cpu / 100
                    }
                    StatBar {
                        width: statGrid.cellWidth
                        icon: Icons.memory
                        label: "Memory"
                        value: `${Stats.memUsed.toFixed(1)}G`
                        fraction: Stats.memPercent / 100
                    }
                    StatBar {
                        width: statGrid.cellWidth
                        icon: Icons.thermometer
                        label: "Temp"
                        value: `${Stats.temp}°C`
                        fraction: Stats.temp / 100
                        warn: Stats.temp >= 80
                    }
                    StatBar {
                        width: statGrid.cellWidth
                        icon: "\u{F04E1}"
                        label: "Swap"
                        value: `${Stats.swapUsed.toFixed(1)}G`
                        fraction: Stats.swapPercent / 100
                    }
                }

                // Network throughput + address
                Item {
                    width: parent.width
                    height: 20
                    visible: Stats.iface !== ""

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Icon { text: Icons.down; size: 16; color: Theme.green }
                        StyledText { text: Stats.formatRate(Stats.rxRate); font.pixelSize: Theme.fontSize - 1 }
                        Item { width: 6; height: 1 }
                        Icon { text: Icons.up; size: 16; color: Theme.green }
                        StyledText { text: Stats.formatRate(Stats.txRate); font.pixelSize: Theme.fontSize - 1 }
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Stats.ipAddr ? `${Stats.iface} · ${Stats.ipAddr}` : Stats.iface
                        color: Theme.fgDim
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }

    component PowerButton: Rectangle {
        id: btn

        property string icon
        property string label
        property bool confirm: true
        property bool armed: false

        signal activated

        implicitHeight: 66
        radius: Theme.radius
        color: armed ? Theme.urgentBg : Theme.surface
        border.width: 1
        border.color: armed ? Theme.urgentBorder : Theme.border

        Behavior on color {
            ColorAnimation { duration: Theme.normal }
        }

        Column {
            anchors.centerIn: parent
            spacing: 4

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.icon
                size: 20
                color: btn.armed ? Theme.primaryFg : Theme.fg
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.armed ? "Confirm" : btn.label
                color: btn.armed ? Theme.primaryFg : Theme.fgDim
                font.pixelSize: Theme.fontSize - 2
            }
        }

        StateLayer {
            radius: Theme.radius
            onClicked: {
                if (!btn.confirm || btn.armed) {
                    btn.armed = false;
                    btn.activated();
                } else {
                    btn.armed = true;
                    disarm.restart();
                }
            }
        }

        // Second click must come within 3 s.
        Timer {
            id: disarm
            interval: 3000
            onTriggered: btn.armed = false
        }
    }

    // ---------------------------------------------------------------- pages

    Component {
        id: wifiPage
        WifiPage {}
    }

    Component {
        id: bluetoothPage
        BluetoothPage {}
    }

    Component {
        id: audioPage
        AudioPage {}
    }

    component WifiPage: Column {
        spacing: 10

        PageHeader {
            width: parent.width
            title: "Wi-Fi"
            onBack: root.go("")

            StyledSwitch {
                checked: Net.wifiEnabled
                onToggled: Net.toggleWifi()
            }
        }

        StyledText {
            width: parent.width
            visible: !Net.wifiEnabled || Net.networks.length === 0
            height: 60
            horizontalAlignment: Text.AlignHCenter
            text: Net.wifiEnabled ? "Searching for networks…" : "Wi-Fi is off"
            color: Theme.fgDim
        }

        ListView {
            width: parent.width
            height: Math.min(contentHeight, 6 * 52)
            visible: Net.wifiEnabled && count > 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: Net.networks
            }
            delegate: WifiRow {}
        }

        TextButton {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: Icons.cog
            text: "Network settings"
            onClicked: root.run(["nm-connection-editor"])
        }
    }

    component WifiRow: Column {
        id: row

        required property var modelData
        readonly property var net: modelData
        readonly property bool secured: net.security !== WifiSecurityType.Open
        property bool askPassword: false
        property bool failed: false

        function submit() {
            if (password.text === "")
                return;
            failed = false;
            net.connectWithPsk(password.text);
            password.text = "";
            askPassword = false;
        }

        width: ListView.view.width
        spacing: 4

        ListItem {
            width: parent.width
            icon: Icons.level(Icons.wifiLevels, Net.strength(row.net))
            title: row.net.name
            subtitle: row.net.stateChanging ? (row.net.connected ? "Disconnecting…" : "Connecting…")
                    : row.net.connected ? "Connected"
                    : row.failed ? "Couldn't connect"
                    : row.net.known ? "Saved"
                    : row.secured ? "Secured" : "Open"
            highlighted: row.net.connected

            Icon {
                visible: row.secured
                text: Icons.lock
                size: 14
                color: Theme.fgMuted
            }

            onClicked: {
                row.failed = false;
                if (row.net.connected)
                    row.net.disconnect();
                else if (row.net.known || !row.secured)
                    row.net.connect();
                else
                    row.askPassword = !row.askPassword;
            }
        }

        Connections {
            target: row.net

            function onConnectionFailed(reason) {
                row.failed = true;
                if (row.secured)
                    row.askPassword = true;
            }
        }

        Rectangle {
            width: parent.width
            height: 42
            visible: row.askPassword
            radius: Theme.radius
            color: Theme.surfaceHigh

            onVisibleChanged: if (visible) password.forceActiveFocus()

            TextInput {
                id: password

                anchors.left: parent.left
                anchors.right: connectButton.left
                anchors.margins: 14
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                color: Theme.fg
                selectionColor: Theme.primary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                clip: true
                onAccepted: row.submit()

                StyledText {
                    visible: password.text === ""
                    text: "Password"
                    color: Theme.fgMuted
                }
            }

            IconButton {
                id: connectButton

                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                size: 34
                icon: Icons.check
                active: true
                onClicked: row.submit()
            }
        }
    }

    component BluetoothPage: Column {
        spacing: 10

        PageHeader {
            width: parent.width
            title: "Bluetooth"
            onBack: root.go("")

            IconButton {
                visible: Bt.enabled
                icon: Icons.refresh
                active: Bt.adapter?.discovering ?? false
                spinning: active
                onClicked: Bt.adapter.discovering = !Bt.adapter.discovering
            }

            StyledSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Bt.enabled
                onToggled: Bt.toggle()
            }
        }

        StyledText {
            width: parent.width
            visible: !Bt.enabled || Bt.devices.length === 0
            height: 60
            horizontalAlignment: Text.AlignHCenter
            text: !Bt.enabled ? "Bluetooth is off" : "No devices. Tap ⟳ to search."
            color: Theme.fgDim
        }

        PairingPrompt {
            width: parent.width
            visible: Bt.request !== null
        }

        ListView {
            width: parent.width
            height: Math.min(contentHeight, 6 * 52)
            visible: Bt.enabled && count > 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: Bt.devices
            }

            delegate: ListItem {
                id: item

                required property var modelData
                readonly property var dev: modelData
                readonly property int battery: Bt.battery(dev)
                readonly property bool connecting: dev.state === BluetoothDeviceState.Connecting
                                                || Bt.connectingPath === dev.dbusPath
                readonly property bool busy: connecting || dev.pairing
                                          || dev.state === BluetoothDeviceState.Disconnecting

                width: ListView.view.width
                icon: Icons.forDevice(dev.icon ?? "")
                title: dev.name
                subtitle: dev.pairing ? "Pairing…"
                        : connecting ? "Connecting…"
                        : dev.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                        : dev.connected ? "Connected" + (battery >= 0 ? ` · ${battery}%` : "")
                        : dev.paired ? "Paired" : "Not paired"
                highlighted: dev.connected && !busy

                // Unpaired devices get a Pair button (the row does the same).
                TextButton {
                    visible: !item.dev.paired && !item.busy
                    text: "Pair"
                    fg: Theme.accent
                    onClicked: Bt.pair(item.dev)
                }

                onClicked: {
                    if (busy)
                        return;
                    if (dev.connected)
                        dev.disconnect();
                    else if (dev.paired)
                        dev.connect();
                    else
                        Bt.pair(dev);
                }
            }
        }

        TextButton {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: Icons.cog
            text: "Bluetooth settings"
            onClicked: root.run(["blueberry"])
        }
    }

    component AudioPage: Column {
        spacing: 8

        PageHeader {
            width: parent.width
            title: "Sound"
            onBack: root.go("")
        }

        StyledText {
            text: "Output"
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 2
            leftPadding: 4
        }

        Repeater {
            model: ScriptModel {
                values: Audio.sinks
            }

            ListItem {
                required property var modelData

                width: parent.width
                icon: modelData.properties?.["device.api"] === "bluez5" ? Icons.headset : Icons.speaker
                title: Audio.nodeName(modelData)
                highlighted: modelData.id === Audio.sink?.id
                onClicked: Pipewire.preferredDefaultAudioSink = modelData

                Icon {
                    visible: parent.parent.highlighted
                    text: Icons.check
                    color: Theme.accent
                }
            }
        }

        StyledText {
            text: "Input"
            color: Theme.fgDim
            font.pixelSize: Theme.fontSize - 2
            leftPadding: 4
            topPadding: 6
        }

        Repeater {
            model: ScriptModel {
                values: Audio.sources
            }

            ListItem {
                required property var modelData

                width: parent.width
                icon: Icons.mic
                title: Audio.nodeName(modelData)
                highlighted: modelData.id === Audio.source?.id
                onClicked: Pipewire.preferredDefaultAudioSource = modelData

                Icon {
                    visible: parent.parent.highlighted
                    text: Icons.check
                    color: Theme.accent
                }
            }
        }

        TextButton {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: Icons.cog
            text: "Sound settings"
            onClicked: root.run(["pavucontrol"])
        }
    }
}
