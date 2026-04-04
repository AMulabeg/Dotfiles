import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

PanelWindow {
    id: popupWindow
    property var server

    anchors { top: true; right: true }
    margins { top: 50; right: 8 }
    implicitWidth: 370
    implicitHeight: popupCol.implicitHeight + 8

    WlrLayershell.namespace: "quickshell:notification-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"

    Column {
        id: popupCol
        anchors { top: parent.top; right: parent.right }
        spacing: 6
        width: 360

        Repeater {
            model: server ? server.trackedNotifications : null

            delegate: Rectangle {
                required property var modelData
                property var notification: modelData

                width: 360
                height: toastCol.implicitHeight + 20
                radius: 10
                color: "#222222"
                border.color: "#333333"
                border.width: 1

                // Slide in
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 200 } }

                // Urgency accent
                Rectangle {
                    width: 4
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    radius: 10
                    color: notification.urgency === NotificationUrgency.Critical ? "#ff5555" :
                           notification.urgency === NotificationUrgency.Normal    ? "#ffdd33" : "#444444"
                }

                // Auto-dismiss
                Timer {
                    interval: (notification.expireTimeout > 0 && notification.expireTimeout < 30000)
                              ? notification.expireTimeout : 5000
                    running: true
                    onTriggered: notification.expire()
                }

                Column {
                    id: toastCol
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        leftMargin: 16; rightMargin: 12; topMargin: 10; bottomMargin: 10
                    }
                    spacing: 4

                    // App name + close
                    Row {
                        width: parent.width
                        spacing: 6

                        Image {
                            id: appIconImg
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                            // appIcon may be a bare theme name ("battery-good", "solaar"),
                            // a full path, or a file:// URI. Resolve theme names via
                            // Quickshell.iconPath(); hide if nothing resolves.
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
                            text: notification.appName || "Notification"
                            color: "#777777"
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24; elide: Text.ElideRight
                        }
                        Text {
                            text: "\u00D7"; color: "#666666"; font.pixelSize: 15
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                onClicked: notification.dismiss()
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    // Summary
                    Text {
                        text: notification.summary || ""
                        color: "#e4e4ef"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true
                        width: parent.width; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        visible: (notification.summary || "") !== ""
                    }

                    // Body
                    Text {
                        text: notification.body || ""
                        color: "#aaaaaa"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        width: parent.width; wrapMode: Text.WordWrap
                        maximumLineCount: 3; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        visible: (notification.body || "") !== ""
                    }

                    // Actions
                    Row {
                        spacing: 6
                        visible: notification.actions && notification.actions.length > 0
                        Repeater {
                            model: notification.actions
                            delegate: Rectangle {
                                required property var modelData
                                property var action: modelData
                                height: 22; width: actionLbl.implicitWidth + 14
                                radius: 5; color: Qt.rgba(1, 1, 1, 0.07)
                                Text {
                                    id: actionLbl
                                    anchors.centerIn: parent
                                    text: action.text || ""
                                    color: "#ffdd33"
                                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { action.invoke(); notification.dismiss() }
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
