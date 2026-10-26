import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool checked: false
    property color activeTrackColor: "#a8c7fa"
    property color inactiveTrackColor: "#32353c"
    property color activeThumbColor: "#062e6f"
    property color inactiveThumbColor: "#8e919a"
    property color outlineColor: "#8e919a"

    signal toggled(bool value)

    implicitWidth: 52
    implicitHeight: 32

    Rectangle {
        id: track
        anchors.fill: parent
        radius: 16
        color: root.checked ? root.activeTrackColor : root.inactiveTrackColor
        border.color: root.checked ? "transparent" : root.outlineColor
        border.width: root.checked ? 0 : 2

        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on border.width { NumberAnimation { duration: 150 } }

        // Ползунок (Thumb): 16dp в покое -> 24dp во включенном состоянии
        Rectangle {
            id: thumb
            width: root.checked ? 24 : 16
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? (parent.width - width - 4) : 6
            color: root.checked ? root.activeThumbColor : root.inactiveThumbColor

            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }

            // Микро-иконка внутри ползунка (✓ / ✕)
            Text {
                anchors.centerIn: parent
                text: root.checked ? "✓" : "✕"
                color: root.checked ? root.activeTrackColor : root.inactiveTrackColor
                font.pixelSize: root.checked ? 11 : 9
                font.bold: true
                opacity: root.checked ? 1.0 : 0.6
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
