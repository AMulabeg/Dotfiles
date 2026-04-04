import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

PanelWindow {
    id: controlCenter

    property bool open: false
    property bool dnd: false
    property var server
    property var osd: null       // OsdIndicator; injected from shell.qml
    property real brightness: 1.0

    // Which monitor is focused and whether it's internal
    property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    property bool isInternalMonitor: focusedMonitorName.startsWith("eDP") || focusedMonitorName.startsWith("LVDS")

    anchors { top: true; left: true; right: true }
    margins { top: 45; right: 0 }
    implicitWidth: 0
    implicitHeight: open ? ccContent.implicitHeight + 24 : 0
    visible: open

    WlrLayershell.namespace: "quickshell:control-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Read brightness when focused monitor changes
    Process {
        id: brightnessRead
        running: false
        property real cur: -1
        command: controlCenter.isInternalMonitor
            ? ["sh", "-c", "cat /sys/class/backlight/*/brightness 2>/dev/null | head -1; cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1"]
            : ["sh", "-c", "ddcutil getvcp 10 --display 1 --brief 2>/dev/null | awk '{print $4, $5}'"]
        stdout: SplitParser {
            onRead: data => {
                const t = data.trim()
                if (controlCenter.isInternalMonitor) {
                    const v = parseFloat(t)
                    if (!isNaN(v)) {
                        if (brightnessRead.cur < 0) { brightnessRead.cur = v }
                        else { controlCenter.brightness = brightnessRead.cur / v; brightnessRead.cur = -1 }
                    }
                } else {
                    // ddcutil returns "current max" e.g. "75 100"
                    const parts = t.split(" ")
                    if (parts.length >= 2) {
                        const cur = parseInt(parts[0]), max = parseInt(parts[1])
                        if (!isNaN(cur) && !isNaN(max) && max > 0)
                            controlCenter.brightness = cur / max
                    }
                }
            }
        }
    }

    // Re-read brightness whenever the focused monitor changes or panel opens
    onFocusedMonitorNameChanged: brightnessRead.running = true
    onOpenChanged: { if (open) { brightnessRead.running = true; btRead.running = true; ppRead.running = true } }
    Component.onCompleted: brightnessRead.running = true

    // Write brightness to the correct monitor
    Process {
        id: brightnessWrite
        running: false
        property real targetPct: 1.0
        command: controlCenter.isInternalMonitor
            ? ["brightnessctl", "set", Math.round(targetPct * 100) + "%"]
            : ["ddcutil", "setvcp", "10", String(Math.round(targetPct * 100)), "--display", "1"]
    }

    // For external monitors, map Hyprland monitor name to ddcutil display index
    // ddcutil uses --display 1, 2 etc. We detect by listing and matching
    Process {
        id: ddcutilDetect
        running: false
        property string output: ""
        command: ["sh", "-c", "ddcutil detect --brief 2>/dev/null | grep -E 'Display|Model' | paste - -"]
        stdout: SplitParser {
            onRead: data => ddcutilDetect.output += data + "\n"
        }
        onRunningChanged: {
            if (!running && ddcutilDetect.output !== "") {
                // Try to match monitor name from Hyprland to ddcutil display number
                const lines = ddcutilDetect.output.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/Display\s+(\d+)/)
                    if (m) {
                        // Update brightnessWrite with correct display index
                        brightnessWrite.command = [
                            "ddcutil", "setvcp", "10",
                            String(Math.round(brightnessWrite.targetPct * 100)),
                            "--display", m[1]
                        ]
                        break
                    }
                }
                ddcutilDetect.output = ""
            }
        }
    }

    Process { id: lockProc;  running: false; command: ["loginctl", "lock-session"] }
    Process { id: sleepProc; running: false; command: ["systemctl", "suspend"] }

    // ── Bluetooth ────────────────────────────────────────────────────────────
    property bool bluetoothEnabled: false

    Process {
        id: btRead
        running: true
        command: ["bluetoothctl", "show"]
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("Powered: yes"))     controlCenter.bluetoothEnabled = true
                else if (data.includes("Powered: no")) controlCenter.bluetoothEnabled = false
            }
        }
    }

    Process {
        id: btToggle
        running: false
        property bool targetState: false
        command: ["bluetoothctl", "power", targetState ? "on" : "off"]
        onRunningChanged: { if (!running) btRead.running = true }
    }

    // ── Power profiles ───────────────────────────────────────────────────────
    property string powerProfile: "balanced"

    Process {
        id: ppRead
        running: true
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser {
            onRead: data => {
                const t = data.trim()
                if (t !== "") controlCenter.powerProfile = t
            }
        }
    }

    Process {
        id: ppWrite
        running: false
        property string target: "balanced"
        command: ["powerprofilesctl", "set", target]
        onRunningChanged: { if (!running) ppRead.running = true }
    }

    Rectangle {
        id: card
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width: 320
        implicitHeight: ccContent.implicitHeight + 24
        radius: 12
        color: "#1a1a1a"
        border.color: "#2a2a2a"
        border.width: 1
        clip: true
        opacity: 1

        Column {
            id: ccContent
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 16
            spacing: 14

            // Header with monitor name
            Row {
                width: parent.width
                Text {
                    text: "\uf013  Control Center"
                    color: "#e4e4ef"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: parent.width - monitorLabel.implicitWidth - 160; height: 1 }
                Text {
                    id: monitorLabel
                    text: controlCenter.focusedMonitorName
                    color: "#555555"
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

            // Volume
            Column {
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width; spacing: 8

                    Text {
                        property var sink: Pipewire.defaultAudioSink
                        text: (!sink || !sink.audio) ? "\uf028" : sink.audio.muted ? "\uf075f" : "\uf028"
                        color: "#ffdd33"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { const s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.muted = !s.audio.muted }
                        }
                    }
                    Text { text: "Volume"; color: "#e4e4ef"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: parent.width - 145; height: 1 }
                    Text {
                        property var sink: Pipewire.defaultAudioSink
                        text: (!sink || !sink.audio) ? "--%"  : sink.audio.muted ? "Muted" : Math.round(sink.audio.volume * 100) + "%"
                        color: "#888888"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: parent.width; height: 6; radius: 3; color: "#2a2a2a"
                    Rectangle {
                        property var sink: Pipewire.defaultAudioSink
                        width: parent.width * Math.min((!sink || !sink.audio || sink.audio.muted) ? 0 : sink.audio.volume, 1.5)
                        height: parent.height; radius: 3; color: "#ffdd33"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked:         mouse => setVol(mouse.x / width)
                        onPositionChanged: mouse => { if (pressed) setVol(mouse.x / width) }
                        function setVol(pct) {
                            const s = Pipewire.defaultAudioSink
                            if (s && s.audio) s.audio.volume = Math.max(0, Math.min(1.5, pct))
                        }
                    }
                }
            }

            // Brightness
            Column {
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width; spacing: 8

                    Text {
                        text: "\uf185"
                        color: "#ffdd33"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Brightness"
                        color: "#e4e4ef"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    // Show (DDC) label for external monitors
                    Text {
                        text: controlCenter.isInternalMonitor ? "" : "(DDC)"
                        color: "#444444"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !controlCenter.isInternalMonitor
                    }
                    Item { width: parent.width - (controlCenter.isInternalMonitor ? 165 : 205); height: 1 }
                    Text {
                        text: Math.round(controlCenter.brightness * 100) + "%"
                        color: "#888888"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: parent.width; height: 6; radius: 3; color: "#2a2a2a"
                    Rectangle {
                        width: parent.width * controlCenter.brightness
                        height: parent.height; radius: 3; color: "#ffdd33"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked:         mouse => setBright(mouse.x / width)
                        onPositionChanged: mouse => { if (pressed) setBright(mouse.x / width) }
                        function setBright(pct) {
                            controlCenter.brightness = Math.max(0.01, Math.min(1, pct))
                            brightnessWrite.targetPct = controlCenter.brightness
                            brightnessWrite.running = true
                            if (controlCenter.osd) controlCenter.osd.showBrightness(controlCenter.brightness)
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

            // Power Profiles
            Column {
                width: parent.width
                spacing: 6

                Row {
                    width: parent.width; spacing: 8
                    Text {
                        text: controlCenter.powerProfile === "power-saver" ? "\uf06c"
                            : controlCenter.powerProfile === "performance"  ? "\uf135"
                            :                                                 "\uf0e7"
                        color: controlCenter.powerProfile === "power-saver" ? "#88cc66"
                             : controlCenter.powerProfile === "performance"  ? "#ff6666"
                             :                                                 "#ffdd33"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Power Profile"
                        color: "#e4e4ef"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Item { width: parent.width - 200; height: 1 }
                    Text {
                        text: controlCenter.powerProfile === "power-saver" ? "Saver"
                            : controlCenter.powerProfile === "performance"  ? "Perf"
                            :                                                 "Balanced"
                        color: "#888888"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Three profile pills
                Row {
                    width: parent.width; spacing: 6

                    Repeater {
                        model: [
                            { id: "power-saver",  label: "\uf06c  Saver",    activeColor: "#88cc66" },
                            { id: "balanced",     label: "\uf0e7  Balanced", activeColor: "#ffdd33" },
                            { id: "performance",  label: "\uf135  Perf",     activeColor: "#ff6666" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            property bool isActive: controlCenter.powerProfile === modelData.id
                            width: (parent.width - 12) / 3; height: 28; radius: 6
                            color: isActive ? Qt.rgba(
                                parseInt(modelData.activeColor.slice(1,3), 16) / 255,
                                parseInt(modelData.activeColor.slice(3,5), 16) / 255,
                                parseInt(modelData.activeColor.slice(5,7), 16) / 255,
                                0.15) : Qt.rgba(1,1,1,0.04)
                            border.color: isActive ? modelData.activeColor : "#2a2a2a"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: isActive ? modelData.activeColor : "#555555"
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { ppWrite.target = modelData.id; ppWrite.running = true }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#2a2a2a" }

            Text { text: "Quick Actions"; color: "#666666"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }

            Flow {
                spacing: 8; width: parent.width

                QuickToggle {
                    label: "DnD"; icon: "\uf1f6"
                    active: controlCenter.dnd
                    onToggled: { controlCenter.dnd = !controlCenter.dnd; if (controlCenter.server) controlCenter.server.inhibited = controlCenter.dnd }
                }
                QuickToggle {
                    label: "BT"; icon: "\uf294"
                    active: controlCenter.bluetoothEnabled
                    onToggled: { btToggle.targetState = !controlCenter.bluetoothEnabled; btToggle.running = true }
                }
                QuickToggle {
                    label: "Lock"; icon: "\uf023"
                    active: false
                    onToggled: lockProc.running = true
                }
                QuickToggle {
                    label: "Sleep"; icon: "\uf186"
                    active: false
                    onToggled: sleepProc.running = true
                }
            }

            Item { width: 1; height: 4 }
        }
    }
}
