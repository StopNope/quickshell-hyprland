import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property bool active: false
    property string icon: "󰤨"
    property string title: "Wi-Fi"
    property string subtitle: "Подключено"
    property bool hasDetails: false

    property color primaryCol: (typeof Config !== "undefined" && Config.accent) ? Config.accent : "#a8c7fa"
    property color onPrimaryCol: (typeof Config !== "undefined" && Config.accentText) ? Config.accentText : "#062e6f"
    property color containerCol: (typeof Config !== "undefined" && Config.surfaceContainerHigh) ? Config.surfaceContainerHigh : "#272930"
    property color onSurfaceCol: (typeof Config !== "undefined" && Config.onSurface) ? Config.onSurface : "#e2e4ec"
    property color onSurfaceMuted: (typeof Config !== "undefined" && Config.onSurfaceVariant) ? Config.onSurfaceVariant : "#9ea2b2"

    signal toggled()
    signal detailsClicked()

    Layout.fillWidth: true
    implicitHeight: 60
    radius: 22
    color: active ? primaryCol : (tileMouse.containsMouse ? Qt.lighter(containerCol, 1.1) : containerCol)
    border.color: active ? "transparent" : ((typeof Config !== "undefined" && Config.outlineVariant) ? Config.outlineVariant : "#383b45")
    border.width: active ? 0 : 1

    scale: tileMouse.pressed ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: 100 } }
    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Круглый / сквиркл контейнер иконки
        Rectangle {
            width: 38
            height: 38
            radius: 19
            color: root.active ? Qt.rgba(0, 0, 0, 0.14) : ((typeof Config !== "undefined" && Config.surfaceContainerHighest) ? Config.surfaceContainerHighest : "#32353c")
            Behavior on color { ColorAnimation { duration: 180 } }

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.active ? root.onPrimaryCol : root.primaryCol
                font.pixelSize: 18
            }
        }

        // Текстовый блок (2 строки)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: root.title
                color: root.active ? root.onPrimaryCol : root.onSurfaceCol
                font.pixelSize: root.title.length > 14 ? 11.5 : 13
                font.bold: true
                font.family: "Rubik, sans-serif"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.subtitle
                color: root.active ? Qt.rgba(root.onPrimaryCol.r, root.onPrimaryCol.g, root.onPrimaryCol.b, 0.8) : root.onSurfaceMuted
                font.pixelSize: 11
                font.family: "Rubik, sans-serif"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Кнопка перехода к списку / деталям (Chevron)
        Rectangle {
            visible: root.hasDetails
            width: 28
            height: 28
            radius: 14
            color: detailsMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰅂"
                color: root.active ? root.onPrimaryCol : root.onSurfaceMuted
                font.pixelSize: 15
            }

            MouseArea {
                id: detailsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.detailsClicked()
            }
        }
    }

    // Клик по основной части плитки переключает состояние
    MouseArea {
        id: tileMouse
        anchors.fill: parent
        anchors.rightMargin: root.hasDetails ? 34 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
