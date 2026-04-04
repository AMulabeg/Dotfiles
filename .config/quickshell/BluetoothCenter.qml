import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: btCenter

    property bool open: false

    // Device list: each entry is { name, mac, connected }
    property var devices: []

    // Selected device detail
    property string selMac:     ""
    property string selName:    ""
    property bool   selConn:    false
    property string selBattery: ""
    property string selProfile: ""

    // Adapter state
    property bool btPowered: false
    property bool scanning:  false

    // View: "devices" or "detail"
    property string view: "devices"

    anchors { top: true; right: true }
    margins { top: 45; right: 8 }
    implicitWidth: 316
    implicitHeight: open ? btCard.implicitHeight + 24 : 0
    visible: open

    WlrLayershell.namespace: "quickshell:bluetooth-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"

    // ── Refresh adapter state + paired device list ───────────────────────────
    Process {
        id: listProc
        running: false
        command: ["sh", "-c",
            "power=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}'); " +
            "echo \"POWER:$power\"; " +
            "bluetoothctl devices 2>/dev/null | while read _ mac rest; do " +
            "  echo \"DEV:$mac $rest\"; " +
            "  bluetoothctl info \"$mac\" 2>/dev/null | grep -q 'Connected: yes' && echo \"CONN:$mac\"; " +
            "done"
        ]
        property var  pending:      []
        property bool pendingPower: false

        stdout: SplitParser {
            onRead: data => {
                const t = data.trim()
                if (t.startsWith("POWER:")) {
                    listProc.pendingPower = (t.slice(6) === "yes")
                } else if (t.startsWith("DEV:")) {
                    const rest = t.slice(4)
                    const idx  = rest.indexOf(" ")
                    const mac  = idx >= 0 ? rest.slice(0, idx) : rest
                    const name = idx >= 0 ? rest.slice(idx + 1) : mac
                    listProc.pending.push({ mac: mac, name: name, connected: false })
                } else if (t.startsWith("CONN:")) {
                    const mac = t.slice(5)
                    for (let d of listProc.pending)
                        if (d.mac === mac) { d.connected = true; break }
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                btCenter.btPowered = listProc.pendingPower
                btCenter.devices   = listProc.pending.slice()
                listProc.pending   = []
                // Sync selected device connection state
                if (btCenter.selMac !== "") {
                    for (let d of btCenter.devices)
                        if (d.mac === btCenter.selMac) { btCenter.selConn = d.connected; break }
                }
            }
        }
    }

    onOpenChanged: {
        if (open) {
            btCenter.view = "devices"
            btCenter.selMac = ""
            listProc.pending = []
            listProc.running = true
        }
    }

    Timer {
        interval: 4000; running: btCenter.open; repeat: true
        onTriggered: { listProc.pending = []; listProc.running = true }
    }

    // ── Scan ─────────────────────────────────────────────────────────────────
    Process {
        id: scanProc
        running: false
        property bool startScan: true
        command: startScan ? ["bluetoothctl", "scan", "on"] : ["bluetoothctl", "scan", "off"]
        onRunningChanged: {
            if (!running && !startScan) {
                btCenter.scanning = false
                listProc.pending = []; listProc.running = true
            }
        }
    }
    Timer {
        id: scanTimer; interval: 8000; repeat: false
        onTriggered: { scanProc.startScan = false; scanProc.running = true }
    }

    // ── Power toggle ─────────────────────────────────────────────────────────
    Process {
        id: powerProc; running: false
        property bool targetOn: false
        command: ["bluetoothctl", "power", targetOn ? "on" : "off"]
        onRunningChanged: { if (!running) { listProc.pending = []; listProc.running = true } }
    }

    // ── Connect / disconnect ─────────────────────────────────────────────────
    Process {
        id: connProc; running: false
        property string targetMac: ""
        property bool   doConnect:  true
        command: doConnect ? ["bluetoothctl", "connect",    targetMac]
                           : ["bluetoothctl", "disconnect", targetMac]
        onRunningChanged: {
            if (!running) { listProc.pending = []; listProc.running = true; detailProc.running = true }
        }
    }

    // ── Fetch device detail ──────────────────────────────────────────────────
    Process {
        id: detailProc; running: false
        property string targetMac: ""
        command: ["bluetoothctl", "info", detailProc.targetMac]
        stdout: SplitParser {
            onRead: data => {
                const t = data.trim()
                if (t.startsWith("Connected:"))
                    btCenter.selConn = t.includes("yes")
                else if (t.startsWith("Battery Percentage:")) {
                    const m = t.match(/\((\d+)\)/)
                    if (m) btCenter.selBattery = m[1] + "%"
                } else if (t.startsWith("Audio Profile:")) {
                    btCenter.selProfile = t.slice(14).trim()
                }
            }
        }
    }

    // ── UI card ──────────────────────────────────────────────────────────────
    Rectangle {
        id: btCard
        anchors { top: parent.top; right: parent.right }
        width: 300
        implicitHeight: btContent.implicitHeight + 24
        radius: 12
        color: "#1a1a1a"
        border.color: "#2a2a2a"; border.width: 1
        clip: true
        focus: true
        Keys.onEscapePressed: btCenter.open = false

        Column {
            id: btContent
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 16
            spacing: 12

            // ── Header ───────────────────────────────────────────────────────
            Item {
                width: parent.width; height: 20

                // Back arrow (detail view)
                Text {
                    id: backBtn
                    visible: btCenter.view === "detail"
                    text: "\uf060"
                    color: "#ffdd33"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { btCenter.view = "devices"; btCenter.selMac = "" }
                    }
                }

                Text {
                    anchors {
                        left: btCenter.view === "detail" ? backBtn.right : parent.left
                        leftMargin: btCenter.view === "detail" ? 10 : 0
                        verticalCenter: parent.verticalCenter
                    }
                    text: btCenter.view === "detail"
                        ? "\uf293  " + (btCenter.selName.length > 16 ? btCenter.selName.slice(0,15) + "…" : btCenter.selName)
                        : "\uf293  Bluetooth"
                    color: "#e4e4ef"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true
                }
            }

            // ── Power + Scan pills (device list view only) ───────────────────
            Row {
                visible: btCenter.view === "devices"
                width: parent.width; spacing: 8

                Rectangle {
                    width: 110; height: 28; radius: 14
                    color: btCenter.btPowered ? Qt.rgba(1,0.87,0.2,0.12) : Qt.rgba(1,1,1,0.05)
                    border.color: btCenter.btPowered ? "#ffdd33" : "#333333"; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            text: "\uf011"
                            color: btCenter.btPowered ? "#ffdd33" : "#555555"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: btCenter.btPowered ? "On" : "Off"
                            color: btCenter.btPowered ? "#ffdd33" : "#555555"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { powerProc.targetOn = !btCenter.btPowered; powerProc.running = true }
                    }
                }

                Rectangle {
                    width: 120; height: 28; radius: 14
                    visible: btCenter.btPowered
                    color: btCenter.scanning ? Qt.rgba(0.37,0.69,1,0.12) : Qt.rgba(1,1,1,0.05)
                    border.color: btCenter.scanning ? "#5fafff" : "#333333"; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            text: "\uf002"
                            color: btCenter.scanning ? "#5fafff" : "#555555"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: btCenter.scanning ? "Scanning…" : "Scan"
                            color: btCenter.scanning ? "#5fafff" : "#555555"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!btCenter.scanning) {
                                btCenter.scanning = true
                                scanProc.startScan = true
                                scanProc.running   = true
                                scanTimer.restart()
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

            // ── DEVICE LIST VIEW ─────────────────────────────────────────────
            Column {
                visible: btCenter.view === "devices"
                width: parent.width
                spacing: 4

                Text {
                    visible: btCenter.devices.length === 0
                    width: parent.width
                    text: btCenter.btPowered ? "No paired devices" : "Bluetooth is off"
                    color: "#444444"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 6; bottomPadding: 6
                }

                Repeater {
                    model: btCenter.devices
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 46; radius: 8
                        color: devArea.containsMouse
                            ? Qt.rgba(1,1,1,0.06)
                            : modelData.connected ? Qt.rgba(0.37,0.69,1,0.07) : "transparent"

                        Text {
                            id: devIcon
                            text: modelData.connected ? "\uf293" : "\uf294"
                            color: modelData.connected ? "#5fafff" : "#555555"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        }
                        Column {
                            anchors { left: devIcon.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text {
                                text: modelData.name
                                color: modelData.connected ? "#e4e4ef" : "#aaaaaa"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                            }
                            Text {
                                visible: modelData.connected
                                text: "Connected"
                                color: "#5fafff"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                            }
                        }
                        Text {
                            text: "\uf054"
                            color: "#333333"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: devArea
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                btCenter.selMac     = modelData.mac
                                btCenter.selName    = modelData.name
                                btCenter.selConn    = modelData.connected
                                btCenter.selBattery = ""
                                btCenter.selProfile = ""
                                detailProc.targetMac = modelData.mac
                                detailProc.running   = true
                                btCenter.view = "detail"
                            }
                        }
                    }
                }
            }

            // ── DETAIL VIEW ──────────────────────────────────────────────────
            Column {
                visible: btCenter.view === "detail"
                width: parent.width; spacing: 10

                // Status badge
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: badgeLabel.implicitWidth + 24; height: 26; radius: 13
                    color: btCenter.selConn ? Qt.rgba(0.37,0.69,1,0.12) : Qt.rgba(1,1,1,0.05)
                    border.color: btCenter.selConn ? "#5fafff" : "#333333"; border.width: 1
                    Text {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: btCenter.selConn ? "\uf00c  Connected" : "\uf00d  Disconnected"
                        color: btCenter.selConn ? "#5fafff" : "#555555"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                    }
                }

                // Info rows
                Column {
                    width: parent.width; spacing: 8

                    // MAC
                    Row {
                        spacing: 8
                        Text { text: "\uf0c9"; color: "#444444"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "MAC Address"; color: "#444444"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                            Text { text: btCenter.selMac; color: "#888888"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
                        }
                    }

                    // Battery
                    Row {
                        visible: btCenter.selBattery !== ""
                        spacing: 8
                        Text { text: "\uf240"; color: "#444444"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "Battery"; color: "#444444"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                            Text { text: btCenter.selBattery; color: "#e4e4ef"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                        }
                    }

                    // Audio profile
                    Row {
                        spacing: 8
                        Text { text: "\uf025"; color: "#444444"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "Audio Profile"; color: "#444444"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 }
                            Text {
                                text: btCenter.selProfile !== "" ? btCenter.selProfile : "None"
                                color: btCenter.selProfile !== "" ? "#e4e4ef" : "#444444"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

                // Connect / Disconnect button
                Rectangle {
                    width: parent.width; height: 36; radius: 8
                    color: btCenter.selConn ? Qt.rgba(1,0.33,0.33,0.10) : Qt.rgba(1,0.87,0.2,0.10)
                    border.color: btCenter.selConn ? "#ff5555" : "#ffdd33"; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: btCenter.selConn ? "\uf127  Disconnect" : "\uf0c1  Connect"
                        color: btCenter.selConn ? "#ff5555" : "#ffdd33"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            connProc.targetMac = btCenter.selMac
                            connProc.doConnect  = !btCenter.selConn
                            connProc.running    = true
                        }
                    }
                }
            }

            Item { width: 1; height: 2 }
        }
    }
}
