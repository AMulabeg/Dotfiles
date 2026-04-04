import QtQuick

Rectangle {
    property string label: ""
    property string icon: ""
    property bool active: false
    signal toggled()

    width: 90
    height: 56
    radius: 8
    color: active ? Qt.rgba(1, 0.87, 0.2, 0.15) : Qt.rgba(1, 1, 1, 0.04)
    border.color: active ? "#ffdd33" : "transparent"
    border.width: 1

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: icon
            color: active ? "#ffdd33" : "#888888"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: label
            color: active ? "#ffdd33" : "#888888"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: parent.toggled()
        cursorShape: Qt.PointingHandCursor
    }
}
