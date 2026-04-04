import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {

    // ── Icon theme fix ───────────────────────────────────────────────────────
    // battery-good only exists as -symbolic in Adwaita; SNI requests it at
    // 100x100 causing a WARN. Symlink it into hicolor on first run.
    Process {
        id: iconFix
        running: true
        command: ["sh", "-c",
            "d=/usr/share/icons/hicolor/scalable/status; " +
            "[ -e \"$d/battery-good.svg\" ] && exit 0; " +
            "mkdir -p \"$d\" && " +
            "ln -sf /usr/share/icons/Adwaita/symbolic/legacy/battery-good-symbolic.svg " +
            "       \"$d/battery-good.svg\" && " +
            "gtk-update-icon-cache /usr/share/icons/hicolor/ -f -t 2>/dev/null; " +
            "ln -sf /usr/share/icons/Adwaita/symbolic/legacy/battery-good-charging-symbolic.svg " +
            "       \"$d/battery-good-charging.svg\" 2>/dev/null || true"
        ]
    }

    // ── Notification server ──────────────────────────────────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true

        // CRITICAL: must set tracked=true or notification is discarded
        onNotification: notif => {
            notif.tracked = true
            bellSound.command = notif.urgency === NotificationUrgency.Critical
                ? ["paplay", "/usr/share/sounds/freedesktop/stereo/bell.oga"]
                : ["paplay", "/usr/share/sounds/freedesktop/stereo/message.oga"]
            bellSound.running = true
        }
    }

    // Bell sound on notification
    Process {
        id: bellSound
        command: ["paplay", "/usr/share/sounds/freedesktop/stereo/message.oga"]
        running: false
    }

    NotificationCenter { id: notifCenter; server: notifServer }
    ControlCenter      { id: controlCenter; server: notifServer; osd: osd }
    NotificationPopups { server: notifServer }
    BluetoothCenter    { id: btCenter }

    // ── Close panels when clicking outside (Hyprland-native focus grab) ───────
    HyprlandFocusGrab {
        id: focusGrab
        active: controlCenter.open || notifCenter.open || btCenter.open
        windows: {
            const w = []
            if (controlCenter.open) w.push(controlCenter)
            if (notifCenter.open)   w.push(notifCenter)
            if (btCenter.open)      w.push(btCenter)
            return w
        }
        onCleared: {
            controlCenter.open = false
            notifCenter.open   = false
            btCenter.open      = false
        }
    }

    // ── OSD indicator (volume / brightness) ──────────────────────────────────
    OsdIndicator { id: osd }

    // Watch for volume changes from anywhere (bar scroll, control center, keybinds)
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        enabled: Pipewire.defaultAudioSink !== null
        function onVolumeChanged() { osd.showVolume() }
        function onMutedChanged()  { osd.showVolume() }
    }

    // ── Bar ───────────────────────────────────────────────────────────────────
    PanelWindow {
        id: bar

        anchors { top: true; left: true; right: true }
        implicitHeight: 48  // Increased from 39 to 48

        WlrLayershell.namespace: "quickshell:bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: implicitHeight

        color: "#181818"

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: "#303030"
        }

        PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

        // ── Polled stats ─────────────────────────────────────────────────────
        property string cpuUsage:    "--%"
        property string tempVal:     "--°C"
        property string batIcon:     "\uf240"
        property string batVal:      "--%"
        property bool   batCharging: false
        property string netIcon:     "⚠"
        property string netVal:      ""
        property string netSSID:     ""
        property string netType:     "none"
        property int    netStrength: 0
        property string btIcon:      "\uf293"   // nf-fa-bluetooth
        property string btLabel:     ""
        property bool   btOn:        false
        property bool   btConnected: false
        property string ramVal:      "--%"
        property bool   audioOnBt:   false   // true when default audio sink is a BT device

        Process {
            id: cpuProc
            command: ["sh", "-c", "top -bn1 | awk '/^%Cpu/{print int($2)}'"]
            running: false
            stdout: SplitParser { onRead: data => { if (data.trim()) bar.cpuUsage = data.trim() + "%" } }
        }
        Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: cpuProc.running = true }

        Process {
            id: tempProc
            command: ["sh", "-c", "cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null"]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    const v = parseInt(data.trim())
                    if (!isNaN(v)) bar.tempVal = Math.round(v / 1000) + "°C"
                }
            }
        }
        Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: tempProc.running = true }

        Process {
            id: batProc
            command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1"]
            running: false
            property string cap: ""
            stdout: SplitParser {
                onRead: data => {
                    const t = data.trim()
                    if (!isNaN(parseInt(t))) {
                        batProc.cap = t; bar.batVal = t + "%"
                    } else {
                        bar.batCharging = (t === "Charging")
                        const c = parseInt(batProc.cap)
                        bar.batIcon = bar.batCharging ? "\uf0e7" :
                                      c > 80 ? "\uf240" : c > 60 ? "\uf241" : c > 40 ? "\uf242" : c > 20 ? "\uf243" : "\uf244"
                    }
                }
            }
        }
        Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: batProc.running = true }

        Process {
            id: netProc
            // Outputs lines:
            //   STRENGTH:<0-100>   (if wifi connected)
            //   SSID:<name>        (if wifi connected)
            //   ETHERNET           (if only ethernet is up)
            //   DISCONNECTED       (if nothing)
            command: ["sh", "-c",
                "ssid=$(iwgetid -r 2>/dev/null); " +
                "if [ -n \"$ssid\" ]; then " +
                "  iface=$(iwgetid 2>/dev/null | awk '{print $1}'); " +
                "  dbm=$(iw dev \"$iface\" link 2>/dev/null | awk '/signal/{print $2}'); " +
                "  pct=0; " +
                "  if [ -n \"$dbm\" ]; then pct=$(( (dbm + 110) * 100 / 70 )); fi; " +
                "  [ \"$pct\" -gt 100 ] 2>/dev/null && pct=100; " +
                "  [ \"$pct\" -lt 0   ] 2>/dev/null && pct=0; " +
                "  echo \"STRENGTH:$pct\"; " +
                "  echo \"SSID:$ssid\"; " +
                "elif ip link show | grep -v lo | grep -q 'state UP'; then " +
                "  echo ETHERNET; " +
                "else " +
                "  echo DISCONNECTED; " +
                "fi"
            ]
            running: false
            property string pendingStrength: ""
            stdout: SplitParser {
                onRead: data => {
                    const t = data.trim()
                    if (t.startsWith("STRENGTH:")) {
                        const pct = parseInt(t.slice(9))
                        netProc.pendingStrength = pct + "%"
                        bar.netVal  = pct + "%"
                        bar.netType = "wifi"
                        // Tiered WiFi signal strength — store pct so display can colour-code
                        bar.netStrength = pct
                        // nf-md-wifi_strength_1/2/3/4 (󰤟 󰤢 󰤥 󰤨) — use strength bars
                        bar.netIcon = pct >= 75 ? "\udb82\udd28"   // 󰤨 full
                                    : pct >= 50 ? "\udb82\udd25"   // 󰤥 good
                                    : pct >= 25 ? "\udb82\udd22"   // 󰤢 fair
                                    :             "\udb82\udd1f"   // 󰤟 weak
                    } else if (t.startsWith("SSID:")) {
                        bar.netSSID = t.slice(5)
                    } else if (t === "ETHERNET") {
                        bar.netIcon = "󰈀"  // U+F796 nf-fa-ethernet
                        bar.netVal  = ""
                        bar.netSSID = "Ethernet"
                        bar.netType = "ethernet"
                        bar.netStrength = 0
                    } else if (t === "DISCONNECTED") {
                        bar.netIcon = "⚠"
                        bar.netVal  = ""
                        bar.netSSID = ""
                        bar.netType = "none"
                        bar.netStrength = 0
                    }
                }
            }
        }
        Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: { netProc.pendingStrength = ""; netProc.running = true } }

        // ── Bluetooth ────────────────────────────────────────────────────────
        Process {
            id: btProc
            // Outputs: ON or OFF, then optionally CONNECTED:<name>
            command: ["sh", "-c",
                "power=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}'); " +
                "if [ \"$power\" = 'yes' ]; then " +
                "  echo ON; " +
                "  dev=$(bluetoothctl info 2>/dev/null | awk '/Name:/{$1=\"\"; print substr($0,2); exit}'); " +
                "  [ -n \"$dev\" ] && echo \"CONNECTED:$dev\"; " +
                "else " +
                "  echo OFF; " +
                "fi"
            ]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    const t = data.trim()
                    if (t === "ON") {
                        bar.btOn = true
                        bar.btConnected = false
                        bar.btLabel = ""
                        bar.btIcon = "\uf294"  // nf-mdi-bluetooth — powered on, no device
                    } else if (t === "OFF") {
                        bar.btOn = false
                        bar.btConnected = false
                        bar.btLabel = ""
                        bar.btIcon = "\uf294"  // will be dimmed via color
                    } else if (t.startsWith("CONNECTED:")) {
                        bar.btConnected = true
                        bar.btLabel = t.slice(10)
                        bar.btIcon = "\uf293"  // nf-fa-bluetooth — active connection
                    }
                }
            }
        }
        Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: btProc.running = true }

        // ── RAM ──────────────────────────────────────────────────────────────
        Process {
            id: ramProc
            command: ["sh", "-c", "free -m | awk '/^Mem:/{printf \"%d%%\", int($3/$2*100)}'"]
            running: false
            stdout: SplitParser { onRead: data => { if (data.trim()) bar.ramVal = data.trim() } }
        }
        Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: ramProc.running = true }

        // ── Audio sink BT detection ──────────────────────────────────────────
        Process {
            id: audioSinkProc
            command: ["sh", "-c",
                "sink=$(pactl info 2>/dev/null | awk '/Default Sink/{print $3}'); " +
                "echo \"$sink\" | grep -qi 'bluez\\|bluetooth\\|bt_' && echo BT || echo NOBT"
            ]
            running: false
            stdout: SplitParser {
                onRead: data => {
                    bar.audioOnBt = data.trim() === "BT"
                }
            }
        }
        Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: audioSinkProc.running = true }

        SystemClock { id: clock; precision: SystemClock.Seconds }

        // ── Layout ───────────────────────────────────────────────────────────
        Item {
            anchors.fill: parent

            // LEFT: Workspaces
            Row {
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }  // Increased left margin
                spacing: 4  // Increased from 2 to 4

                Repeater {
                    model: Hyprland.workspaces.values
                    delegate: Rectangle {
                        required property var modelData
                        property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
                        width: wsLabel.implicitWidth + 20  // Increased padding
                        height: 34  // Increased from 28 to 34
                        radius: 8   // Increased from 6 to 8
                        color: isActive ? "#ffdd33" : Qt.rgba(1,1,1,0.04)
                        Text {
                            id: wsLabel
                            anchors.centerIn: parent
                            text: modelData.name
                            color: parent.isActive ? "#181818" : "#c6c6c6"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16  // Increased from 14 to 16
                            font.bold: parent.isActive
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }

            // CENTER: Clock — click opens control center
            Rectangle {
                anchors.centerIn: parent
                height: 36  // Increased from 30 to 36
                width: clockText.implicitWidth + 28  // Increased from 24 to 28
                radius: 8   // Increased from 6 to 8
                color: controlCenter.open ? Qt.rgba(1, 0.87, 0.2, 0.12) : "transparent"

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    color: "#ffdd33"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 17  // Increased from 15 to 17
                    font.bold: true
                    text: "\uf017  " + Qt.formatDateTime(clock.date, "HH:mm  \u2022  ddd dd MMM")
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        controlCenter.open = !controlCenter.open
                        if (notifCenter.open) notifCenter.open = false
                    }
                    cursorShape: Qt.PointingHandCursor
                }
            }

            // RIGHT: Stats + bell + tray
            Row {
                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                spacing: 10  // inter-module gap

                // Temp
                Row {
                    spacing: 5; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "\uf2c9"; color: "#ffdd33"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: bar.tempVal; color: "#ffdd33"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                }

                // CPU
                Row {
                    spacing: 5; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "\uf2db"; color: "#95a99f"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: bar.cpuUsage; color: "#95a99f"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                }

                // RAM
                Row {
                    spacing: 5; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "\uf233"; color: "#95a99f"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: bar.ramVal; color: "#95a99f"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                }

                // Bluetooth
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: btRow.implicitWidth
                    height: btRow.implicitHeight
                    visible: bar.btOn || true  // always show so user knows BT state

                    Row {
                        id: btRow
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: bar.btIcon
                            color: !bar.btOn      ? "#555555"  // off — greyed
                                 : bar.btConnected ? "#5fafff"  // connected — blue
                                 :                   "#95a99f"  // on, no device
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: bar.btConnected ? bar.btLabel : ""
                            visible: bar.btConnected && bar.btLabel !== ""
                            color: "#5fafff"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Bluetooth tooltip
                    Rectangle {
                        id: btTooltip
                        visible: btHover.containsMouse
                        z: 100
                        anchors { top: parent.bottom; horizontalCenter: parent.horizontalCenter; topMargin: 6 }
                        width: btTipText.implicitWidth + 16
                        height: btTipText.implicitHeight + 10
                        color: "#181818"; border.color: "#303030"; border.width: 1; radius: 6
                        Text {
                            id: btTipText
                            anchors.centerIn: parent
                            text: !bar.btOn      ? "Bluetooth: Off"
                                : bar.btConnected ? "\uf293  " + bar.btLabel
                                :                   "Bluetooth: On (no device)"
                            color: "#e4e4ef"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                        }
                    }

                    Process { id: btcProc; running: false; command: ["ghostty", "-e", "bluetui"] }
                    MouseArea {
                        id: btHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            btCenter.open = !btCenter.open
                            if (controlCenter.open) controlCenter.open = false
                            if (notifCenter.open) notifCenter.open = false
                        }
                    }
                }

                // Network
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: netRow.implicitWidth
                    height: netRow.implicitHeight

                    Row {
                        id: netRow
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: bar.netIcon
                            color: bar.netType === "none"     ? "#ff5555"
                                 : bar.netType === "ethernet" ? "#95a99f"
                                 : bar.netStrength >= 60      ? "#e4e4ef"
                                 : bar.netStrength >= 30      ? "#ffdd33"
                                 :                              "#ff5555"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: bar.netVal
                            visible: bar.netVal !== ""
                            color: "#e4e4ef"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Tooltip showing SSID / connection type on hover
                    Rectangle {
                        id: netTooltip
                        visible: netHover.containsMouse && bar.netSSID !== ""
                        z: 100
                        anchors {
                            top: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            topMargin: 6
                        }
                        width: netTipText.implicitWidth + 16
                        height: netTipText.implicitHeight + 10
                        color: "#181818"
                        border.color: "#303030"
                        border.width: 1
                        radius: 6

                        Text {
                            id: netTipText
                            anchors.centerIn: parent
                            text: bar.netType === "wifi"
                                ? bar.netIcon + "  " + bar.netSSID + "  •  " + bar.netVal
                                : "\udb82\udcf1  Ethernet"   // 󰛱 ethernet icon
                            color: "#e4e4ef"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                        }
                    }

                    Process { id: nmtuiProc; running: false; command: ["ghostty", "-e", "nmtui"] }

                    MouseArea {
                        id: netHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nmtuiProc.running = true
                    }
                }

                // Volume
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: volRow.implicitWidth
                    height: volRow.implicitHeight

                    Row {
                        id: volRow
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            property var sink: Pipewire.defaultAudioSink
                            property int vol: (!sink || !sink.audio) ? 0 : Math.round(sink.audio.volume * 100)
                            text: (!sink || !sink.audio) ? "\uf026"
                                : sink.audio.muted     ? "\uf6a9"   // nf-fa-volume_mute
                                : vol === 0            ? "\uf026"   // nf-fa-volume_off
                                : vol < 33             ? "\uf027"   // nf-fa-volume_down (low)
                                : vol < 66             ? "\uf027"   // medium
                                :                        "\uf028"   // nf-fa-volume_up (high)
                            color: (!sink || !sink.audio || sink.audio.muted) ? "#ff5555" : "#e4e4ef"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { const s = Pipewire.defaultAudioSink; if (s && s.audio) s.audio.muted = !s.audio.muted }
                            }
                        }
                        Text {
                            property var sink: Pipewire.defaultAudioSink
                            text: (!sink || !sink.audio) ? "--%"
                                : sink.audio.muted ? "muted"
                                : Math.round(sink.audio.volume * 100) + "%"
                            color: (!sink || !sink.audio || sink.audio.muted) ? "#ff5555" : "#e4e4ef"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter
                        }

                        // BT audio indicator — shown when default sink is a bluetooth device
                        Text {
                            visible: bar.audioOnBt
                            text: "\uf293"   // nf-fa-bluetooth
                            color: "#5fafff"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Volume hover tooltip showing sink name
                    Rectangle {
                        id: volTooltip
                        visible: volHover.containsMouse
                        z: 100
                        anchors { top: parent.bottom; horizontalCenter: parent.horizontalCenter; topMargin: 6 }
                        width: volTipText.implicitWidth + 16
                        height: volTipText.implicitHeight + 10
                        color: "#181818"; border.color: "#303030"; border.width: 1; radius: 6
                        Text {
                            id: volTipText
                            anchors.centerIn: parent
                            text: {
                                const s = Pipewire.defaultAudioSink
                                if (!s) return "No audio sink"
                                return (s.description || s.name || "Audio") + "  •  " +
                                       (s.audio && s.audio.muted ? "Muted" : Math.round((s.audio?.volume ?? 0) * 100) + "%")
                            }
                            color: "#e4e4ef"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                        }
                    }
                    MouseArea {
                        id: volHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        // Scroll wheel to change volume
                        onWheel: wheel => {
                            const s = Pipewire.defaultAudioSink
                            if (s && s.audio) {
                                const delta = wheel.angleDelta.y > 0 ? 0.03 : -0.03
                                s.audio.volume = Math.max(0, Math.min(1.5, s.audio.volume + delta))
                            }
                        }
                    }
                }

                // Battery
                Row {
                    spacing: 5; anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: bar.batIcon
                        color: bar.batCharging ? "#ffdd33"
                             : parseInt(bar.batVal) <= 10 ? "#ff5555"
                             : parseInt(bar.batVal) <= 20 ? "#ffaa55"
                             : "#e4e4ef"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: bar.batVal
                        color: bar.batCharging ? "#ffdd33"
                             : parseInt(bar.batVal) <= 10 ? "#ff5555"
                             : parseInt(bar.batVal) <= 20 ? "#ffaa55"
                             : "#e4e4ef"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Separator
                Rectangle { width: 1; height: 20; color: "#404040"; anchors.verticalCenter: parent.verticalCenter }

                // Bell
                Rectangle {
                    width: 22; height: 22; radius: 6
                    color: notifCenter.open ? Qt.rgba(1, 0.87, 0.2, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0f3"
                        color: notifCenter.open ? "#ffdd33" :
                               notifServer.trackedNotifications.count > 0 ? "#e4e4ef" : "#555555"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                    }
                    Rectangle {
                        visible: !notifCenter.open && notifServer.trackedNotifications.count > 0
                        width: 8; height: 8; radius: 4; color: "#ff5555"
                        anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 2 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { notifCenter.open = !notifCenter.open; if (controlCenter.open) controlCenter.open = false }
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Separator
                Rectangle { width: 1; height: 20; color: "#404040"; anchors.verticalCenter: parent.verticalCenter }

                // Tray
                Row {
                    spacing: 6; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            required property var modelData
                            width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                            Image {
                                anchors.fill: parent
                                smooth: true
                                property string rawIcon: modelData.icon || ""
                                source: {
                                    if (rawIcon === "") return ""
                                    if (rawIcon.startsWith("file://") || rawIcon.startsWith("/") || rawIcon.startsWith("image://"))
                                        return rawIcon
                                    return "image://icon/" + rawIcon
                                }
                                visible: status === Image.Ready
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => mouse.button === Qt.RightButton ? modelData.secondaryActivate() : modelData.activate()
                            }
                        }
                    }
                }
            }
        }
    }
}
