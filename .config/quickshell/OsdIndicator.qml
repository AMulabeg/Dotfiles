import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick

// ── OSD (On-Screen Display) ──────────────────────────────────────────────────
// Shows a pill overlay when volume or brightness changes.
// Usage: OsdIndicator { id: osd }
// Call:  osd.showVolume()   or   osd.showBrightness(pct)
PanelWindow {
    id: osd

    // ── Public API ────────────────────────────────────────────────────────────
    // brightness 0.0–1.0, set by ControlCenter before calling showBrightness()
    property real brightness: 1.0

    function showVolume() {
        _mode = "volume"
        _restartTimer()
    }

    function showBrightness(pct) {
        brightness = pct
        _mode = "brightness"
        _restartTimer()
    }

    // ── Internals ─────────────────────────────────────────────────────────────
    property string _mode: "volume"   // "volume" | "brightness"
    property bool   _visible: false

    function _restartTimer() {
        _visible = true
        hideTimer.restart()
    }

    // ── Window setup ─────────────────────────────────────────────────────────
    anchors { bottom: true; left: true; right: true }
    margins { bottom: 64 }      // above the bar area
    implicitWidth:  pill.width
    implicitHeight: pill.height
    visible: _visible

    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"

    // Auto-hide after 1.8 s of inactivity
    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: osd._visible = false
    }

    // ── Pill widget ───────────────────────────────────────────────────────────
    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        width:  260
        height: 56
        radius: 28
        color:  "#1a1a1a"
        border.color: "#2a2a2a"
        border.width: 1

        // Fade in/out
        opacity: osd._visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

        // Slide up on show
        property real _yOffset: osd._visible ? 0 : 16
        transform: Translate { y: pill._yOffset }
        Behavior on _yOffset { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

        // ── Icon ──────────────────────────────────────────────────────────────
        Text {
            id: osdIcon
            anchors { left: pill.left; leftMargin: 20; verticalCenter: pill.verticalCenter }
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
            color: "#ffdd33"

            text: {
                if (osd._mode === "brightness") return "\uf185"   // sun icon
                const s = Pipewire.defaultAudioSink
                if (!s || !s.audio) return "\uf026"
                if (s.audio.muted) return "\uf6a9"
                const v = Math.round(s.audio.volume * 100)
                return v === 0 ? "\uf026" : v < 50 ? "\uf027" : "\uf028"
            }
        }

        // ── Track (background bar) ────────────────────────────────────────────
        Rectangle {
            id: track
            anchors {
                left: osdIcon.right; leftMargin: 12
                right: pctLabel.left; rightMargin: 10
                verticalCenter: pill.verticalCenter
            }
            height: 6
            radius: 3
            color: "#2a2a2a"

            // Fill
            Rectangle {
                height: parent.height
                radius: 3
                color: "#ffdd33"

                width: {
                    if (osd._mode === "brightness")
                        return parent.width * Math.min(Math.max(osd.brightness, 0), 1)
                    const s = Pipewire.defaultAudioSink
                    if (!s || !s.audio || s.audio.muted) return 0
                    return parent.width * Math.min(s.audio.volume, 1)
                }

                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }

        // ── Percentage label ──────────────────────────────────────────────────
        Text {
            id: pctLabel
            anchors { right: pill.right; rightMargin: 18; verticalCenter: pill.verticalCenter }
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: "#888888"
            width: 38
            horizontalAlignment: Text.AlignRight

            text: {
                if (osd._mode === "brightness")
                    return Math.round(osd.brightness * 100) + "%"
                const s = Pipewire.defaultAudioSink
                if (!s || !s.audio) return "--%"
                if (s.audio.muted) return "mute"
                return Math.round(s.audio.volume * 100) + "%"
            }
        }
    }
}
