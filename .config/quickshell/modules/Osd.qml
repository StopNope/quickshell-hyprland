import QtQuick
import QtQuick.Layouts

Rectangle {
    antialiasing: true
    id: root

    required property var cfg

    property bool isShown: false
    property string osdType: "volume"
    property string osdTitle: ""
    property int osdValue: 0
    property string osdIcon: "󰕾"

    width: 240
    height: 44
    radius: 22
    color: cfg.bgSurface
    border.color: cfg.borderCol
    border.width: 1

    opacity: isShown ? 1 : 0
    scale: isShown ? 1 : 0.92
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    function trigger(type, icon, title, val) {
        osdType = type
        osdIcon = icon
        osdTitle = title
        osdValue = val
        isShown = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.isShown = false
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Rectangle {
            antialiasing: true
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 14
            color: root.cfg.accentContainer

            Text {
                anchors.centerIn: parent
                text: root.osdIcon
                color: root.cfg.accent
                font.pixelSize: 14
            }
        }

        Text {
            visible: root.osdType !== "volume"
            text: root.osdTitle
            color: root.cfg.textPrimary
            font.pixelSize: 12
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        // Полоса уровня громкости
        Rectangle {
            antialiasing: true
            visible: root.osdType === "volume"
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            radius: 4
            color: root.cfg.bgPrimary

            Rectangle {
                antialiasing: true
                width: parent.width * Math.min(1, Math.max(0, root.osdValue / 100))
                height: parent.height
                radius: 4
                color: root.cfg.accent
                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }

        Text {
            visible: root.osdType === "volume"
            text: root.osdValue + "%"
            color: root.cfg.textPrimary
            font.pixelSize: 12
            font.bold: true
        }
    }
}
