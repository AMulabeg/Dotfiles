import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

PanelWindow {
    id: notifCenter
    property bool open: false
    property var server

    anchors { top: true; right: true; bottom: true }
    implicitWidth: 380

    WlrLayershell.namespace: "quickshell:notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    color: "transparent"
    visible: open

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: notifCenter.open = false
        z: -1
    }

    Rectangle {
        id: panel
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
        width: 380
        color: "#1a1a1a"
        border.color: "#2a2a2a"
        border.width: 1

        x: notifCenter.open ? 0 : width
        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // Header
        Row {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: 16
            height: 40

            Text {
                text: "\uf0f3  Notifications"
                color: "#e4e4ef"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - clearBtn.implicitWidth - 170; height: 1 }
            Text {
                id: clearBtn
                text: "Clear all"
                color: "#ffdd33"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (server && server.trackedNotifications) {
                            // dismiss all - iterate by index since list changes
                            while (server.trackedNotifications.count > 0) {
                                server.trackedNotifications.get(0).dismiss()
                            }
                        }
                    }
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        Rectangle {
            anchors { top: header.bottom; left: parent.left; right: parent.right }
            height: 1; color: "#2a2a2a"
        }

        // Notification list
        ListView {
            anchors {
                top: header.bottom; topMargin: 8
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 10; rightMargin: 10; bottomMargin: 10
            }
            clip: true
            spacing: 6
            model: server ? server.trackedNotifications : null

            Text {
                anchors.centerIn: parent
                visible: !server || server.trackedNotifications.count === 0
                text: "\uf0f3\n\nNo notifications"
                color: "#444444"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
            }

            delegate: Rectangle {
                required property var modelData
                property var notification: modelData

                width: ListView.view.width
                height: notifCol.implicitHeight + 20
                radius: 8
                color: "#222222"
                border.color: "#333333"
                border.width: 1

                Rectangle {
                    width: 3
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    radius: 8
                    color: notification.urgency === NotificationUrgency.Critical ? "#ff5555" :
                           notification.urgency === NotificationUrgency.Normal    ? "#ffdd33" : "#444444"
                }

                Column {
                    id: notifCol
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        leftMargin: 14; rightMargin: 10; topMargin: 10; bottomMargin: 10
                    }
                    spacing: 3

                    Row {
                        width: parent.width; spacing: 6
                        Image {
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                            property string rawIcon: notification.appIcon || ""
                            source: {
                                if (rawIcon === "") return ""
                                if (rawIcon.startsWith("file://") || rawIcon.startsWith("/"))
                                    return rawIcon
                                return "image://icon/" + rawIcon
                            }
                            visible: rawIcon !== "" && status === Image.Ready
                        }
                        Text {
                            text: notification.appName || ""
                            color: "#666666"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24; elide: Text.ElideRight
                        }
                        Text {
                            text: "\u00D7"; color: "#555555"; font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                onClicked: notification.dismiss()
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    Text {
                        text: notification.summary || ""
                        color: "#e4e4ef"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
                        width: parent.width; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        visible: (notification.summary || "") !== ""
                    }

                    Text {
                        text: notification.body || ""
                        color: "#999999"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                        width: parent.width; wrapMode: Text.WordWrap
                        maximumLineCount: 4; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        visible: (notification.body || "") !== ""
                    }
                }
            }
        }
    }
}
