import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── AppLauncher ──────────────────────────────────────────────────────────────
// Rofi-style application launcher for Quickshell / Hyprland.
//
// Usage from shell.qml:
//   AppLauncher { id: appLauncher }
//
// Toggle open/close via IPC:
//   quickshell ipc call launcher toggle
//
// Bind a key in Hyprland (hyprland.conf):
//   bind = SUPER, D, exec, quickshell ipc call launcher toggle
// ─────────────────────────────────────────────────────────────────────────────

PanelWindow {
    id: root

    // ── Public API ───────────────────────────────────────────────────────────
    property bool open: false

    // ── Window config ────────────────────────────────────────────────────────
    visible: open
    anchors { top: true; left: true; right: true; bottom: true }

    WlrLayershell.namespace:   "quickshell:launcher"
    WlrLayershell.layer:       WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"

    // ── Focus grab — close on outside click ─────────────────────────────────
    HyprlandFocusGrab {
        id: grab
        active: root.open
        windows: [root]
        onCleared: root.open = false
    }

    // ── IPC Handler for keybindings ─────────────────────────────────────────
    IpcHandler {
        target: "launcher"
        
        function toggle(): void {
            root.open = !root.open
        }
        
        function open(): void {
            root.open = true
        }
        
        function close(): void {
            root.open = false
        }
        
        function isOpen(): bool {
            return root.open
        }
    }

    // ── App list — populated by scanning .desktop files ──────────────────────
    ListModel { id: allApps }
    ListModel { id: filteredApps }

    Process {
        id: desktopScanner
        command: [
            "python3", "-c",
            "import os, re, glob\n" +
            "dirs = []\n" +
            "xdg = os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share')\n" +
            "for b in xdg.split(':'):\n" +
            "    dirs.append(os.path.join(b, 'applications'))\n" +
            "dirs.append(os.path.expanduser('~/.local/share/applications'))\n" +
            "seen = set()\n" +
            "results = []\n" +
            "for d in dirs:\n" +
            "    if not os.path.isdir(d): continue\n" +
            "    for path in glob.glob(os.path.join(d, '*.desktop')):\n" +
            "        try:\n" +
            "            txt = open(path, encoding='utf-8', errors='ignore').read()\n" +
            "        except: continue\n" +
            "        def g(k, t=txt): m=re.search(r'^'+k+r'=(.+)', t, re.M); return m.group(1).strip() if m else ''\n" +
            "        if g('NoDisplay')=='true' or g('Hidden')=='true': continue\n" +
            "        name=g('Name'); cmd=g('Exec'); icon=g('Icon')\n" +
            "        if not name or not cmd: continue\n" +
            "        cmd=re.sub(r' ?%[uUfFdDnNickvm]', '', cmd).strip()\n" +
            "        key=name.lower()\n" +
            "        if key in seen: continue\n" +
            "        seen.add(key)\n" +
            "        results.append((name, cmd, icon))\n" +
            "for r in sorted(results, key=lambda x: x[0].lower()):\n" +
            "    print(r[0]+'|'+r[1]+'|'+r[2])\n"
        ]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split("|")
                if (parts.length >= 2 && parts[0].trim()) {
                    allApps.append({
                        name:    parts[0].trim(),
                        appExec: parts[1].trim(),
                        icon:    parts.length > 2 ? parts[2].trim() : ""
                    })
                }
            }
        }

        onRunningChanged: {
            if (!running) applyFilter()
        }
    }

    // ── Filter logic ─────────────────────────────────────────────────────────
    function applyFilter() {
        filteredApps.clear()
        const q = searchField.text.toLowerCase().trim()
        
        if (q === "") {
            grid.currentIndex = -1
            return
        }
        
        for (let i = 0; i < allApps.count; i++) {
            const app = allApps.get(i)
            if (app.name.toLowerCase().includes(q)) {
                filteredApps.append({ name: app.name, appExec: app.appExec, icon: app.icon })
            }
        }
        grid.currentIndex = filteredApps.count > 0 ? 0 : -1
    }

    // ── Reload app list when launcher opens ──────────────────────────────────
    onOpenChanged: {
        if (open) {
            searchField.text = ""
            searchField.forceActiveFocus()
            if (allApps.count === 0) {
                desktopScanner.running = true
            } else {
                applyFilter()
            }
        }
    }

    // ── Launch helper ────────────────────────────────────────────────────────
    Process {
        id: launcher
        running: false
    }

    function launchApp(cmd) {
        launcher.command = ["sh", "-c", cmd + " &"]
        launcher.running = true
        root.open = false
    }

    // ── Dim backdrop ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#CC0d0d0d"

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }
    }

    // ── Centre dialog ────────────────────────────────────────────────────────
    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width:  540
        height: Math.min(dialogColumn.implicitHeight + 32, parent.height * 0.70)
        radius: 14
        color:  "#181818"
        border.color: "#303030"
        border.width: 1

        layer.enabled: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: dialogColumn
            anchors {
                top:    parent.top
                left:   parent.left
                right:  parent.right
                margins: 14
            }
            spacing: 10

            // ── Header ──────────────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "\uf422"
                    color: "#ffdd33"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Launch"
                    color: "#e4e4ef"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { Layout.fillWidth: true; width: 1 }

                Text {
                    text: filteredApps.count + " apps"
                    color: "#555555"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // ── Search box ──────────────────────────────────────────────────
            Rectangle {
                width:  parent.width
                height: 36
                radius: 8
                color:  "#111111"
                border.color: searchField.activeFocus ? "#ffdd33" : "#303030"
                border.width: 1

                Row {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                    spacing: 6

                    Text {
                        visible: false
                        text: "\uf002"
                        color: searchField.activeFocus ? "#ffdd33" : "#555555"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchField
                        width: dialog.width - 70
                        color: "#e4e4ef"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        selectByMouse: true
                        cursorVisible: activeFocus

                        onTextChanged: applyFilter()

                        Keys.onEscapePressed:   root.open = false
                        Keys.onReturnPressed:   {
                            if (filteredApps.count > 0 && grid.currentIndex >= 0)
                                launchApp(filteredApps.get(grid.currentIndex).appExec)
                        }
                        Keys.onTabPressed:      if (filteredApps.count > 0) grid.moveCurrentIndexRight()
                        Keys.onBacktabPressed:  if (filteredApps.count > 0) grid.moveCurrentIndexLeft()
                        Keys.onUpPressed:       if (filteredApps.count > 0) grid.moveCurrentIndexUp()
                        Keys.onDownPressed:     if (filteredApps.count > 0) grid.moveCurrentIndexDown()
                        Keys.onLeftPressed:     if (filteredApps.count > 0) grid.moveCurrentIndexLeft()
                        Keys.onRightPressed:    if (filteredApps.count > 0) grid.moveCurrentIndexRight()
                    }
                }
            }

            // ── App grid ────────────────────────────────────────────────────
            GridView {
                id: grid
                width:         parent.width
                height:        Math.min(contentHeight, dialog.height - 120)
                clip:          true
                cellWidth:     126
                cellHeight:    76
                currentIndex:  -1
                keyNavigationEnabled: true
                model: filteredApps
                focus: false

                delegate: Item {
                    width:  grid.cellWidth
                    height: grid.cellHeight
                    required property int   index
                    required property string name
                    required property string appExec
                    required property string icon

                    Rectangle {
                        anchors {
                            fill:    parent
                            margins: 3
                        }
                        radius: 8
                        color: grid.currentIndex === index
                               ? Qt.rgba(1, 0.87, 0.2, 0.12)
                               : hov.containsMouse ? Qt.rgba(1,1,1,0.06) : Qt.rgba(1,1,1,0.03)
                        border.color: grid.currentIndex === index ? "#ffdd33" : "transparent"
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Image {
                                id: appIcon
                                anchors.horizontalCenter: parent.horizontalCenter
                                width:  28
                                height: 28
                                smooth: true
                                fillMode: Image.PreserveAspectFit
                                property string rawIcon: icon
                                source: {
                                    if (rawIcon === "") return ""
                                    if (rawIcon.startsWith("/") || rawIcon.startsWith("file://"))
                                        return rawIcon
                                    return "image://icon/" + rawIcon
                                }
                                visible: status === Image.Ready
                            }

                            Text {
                                visible: appIcon.status !== Image.Ready
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "\uf17a"
                                color: grid.currentIndex === index ? "#ffdd33" : "#666666"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 22
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: grid.cellWidth - 12
                                text: name
                                color: grid.currentIndex === index ? "#ffdd33" : "#cccccc"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: hov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    {
                                grid.currentIndex = index
                                launchApp(appExec)
                            }
                            onEntered:    grid.currentIndex = index
                        }
                    }
                }

                Text {
                    visible: filteredApps.count === 0 && searchField.text === "" && !desktopScanner.running
                    anchors.centerIn: parent
                    text: "\uf002\n\nType to search apps"
                    color: "#444444"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: filteredApps.count === 0 && searchField.text !== "" && !desktopScanner.running
                    anchors.centerIn: parent
                    text: "No apps found for \"" + searchField.text + "\""
                    color: "#444444"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: desktopScanner.running
                    anchors.centerIn: parent
                    text: "\uf110  Scanning…"
                    color: "#555555"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
            }

            // ── Footer hint ─────────────────────────────────────────────────
            Row {
                spacing: 12
                opacity: 0.45

                Repeater {
                    model: [
                        { key: "↵",   hint: "launch"    },
                        { key: "⎋",   hint: "close"     },
                        { key: "↑↓←→",hint: "navigate"  },
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: 3

                        Rectangle {
                            height: 16
                            width: keyLbl.implicitWidth + 6
                            radius: 3
                            color: "#252525"
                            Text {
                                id: keyLbl
                                anchors.centerIn: parent
                                text: modelData.key
                                color: "#aaaaaa"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            text: modelData.hint
                            color: "#888888"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
