import QtQuick
import QtQuick.Layouts

Rectangle {
    antialiasing: true
    id: root

    property var model: []
    property string currentValue: ""
    signal selected(string val)

    property color activeColor: (typeof Config !== "undefined" && Config.accent) ? Config.accent : "#a8c7fa"
    property color activeTextColor: (typeof Config !== "undefined" && Config.accentText) ? Config.accentText : "#062e6f"
    property color inactiveTextColor: (typeof Config !== "undefined" && Config.textPrimary) ? Config.textPrimary : "#e2e4ec"
    property color containerColor: (typeof Config !== "undefined" && Config.surfaceContainerLowest) ? Config.surfaceContainerLowest : "#181a20"
    property color borderColor: (typeof Config !== "undefined" && Config.borderCol) ? Config.borderCol : "#323540"

    implicitHeight: 38
    implicitWidth: Math.max(220, (model ? model.length : 2) * 82)
    Layout.fillWidth: true
    Layout.preferredHeight: 38
    radius: 19
    color: root.containerColor
    border.color: root.borderColor
    border.width: 1
    clip: true

    RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 4

        Repeater {
            model: root.model

            Rectangle {
                antialiasing: true
                required property var modelData
                readonly property bool isSelected: root.currentValue === modelData.id

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: isSelected ? root.activeColor : (btnMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                scale: btnMouse.pressed ? 0.96 : 1.0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 100 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        visible: !!modelData.icon
                        text: modelData.icon || ""
                        color: isSelected ? root.activeTextColor : (btnMouse.containsMouse ? root.activeColor : root.inactiveTextColor)
                        font.pixelSize: 13
                    }

                    Text {
                        text: modelData.label || ""
                        color: isSelected ? root.activeTextColor : (btnMouse.containsMouse ? root.activeColor : root.inactiveTextColor)
                        font.pixelSize: 11
                        font.bold: isSelected
                        font.family: "Rubik, sans-serif"
                    }
                }

                MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentValue = modelData.id
                        root.selected(modelData.id)
                    }
                }
            }
        }
    }
}
