import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    antialiasing: true
    id: root

    property real value: 50        // 0 to 100
    property string icon: "󰕾"
    property string label: "Громкость"
    property string valueText: ""
    property bool isMuted: false

    property color activeColor: (typeof Config !== "undefined" && Config.accent) ? Config.accent : "#a8c7fa"
    property color onActiveColor: (typeof Config !== "undefined" && Config.accentText) ? Config.accentText : "#062e6f"
    property color inactiveTrackColor: (typeof Config !== "undefined" && Config.surfaceContainerHighest) ? Config.surfaceContainerHighest : "#32353c"
    property color onInactiveColor: (typeof Config !== "undefined" && Config.onSurface) ? Config.onSurface : "#e2e4ec"
    property color onInactiveMuted: (typeof Config !== "undefined" && Config.onSurfaceVariant) ? Config.onSurfaceVariant : "#9ea2b2"
    property color dangerColor: (typeof Config !== "undefined" && Config.danger) ? Config.danger : "#f38ba8"

    signal valueModified(real newVal)
    signal iconClicked()

    implicitHeight: 52
    Layout.fillWidth: true
    radius: height / 2
    color: inactiveTrackColor
    clip: true

    readonly property real progressRatio: isMuted ? 0 : Math.max(0, Math.min(1, value / 100))
    readonly property string displayText: isMuted ? (valueText !== "" ? valueText : "MUTE") : (valueText !== "" ? valueText : (Math.round(value) + "%"))

    // СЛОЙ 1: Элементы на темном треке (Inactive layer)
    RowLayout {
        x: 16
        width: root.width - 32
        height: root.height
        spacing: 12

        Rectangle {
            antialiasing: true
            width: 32
            height: 32
            radius: 16
            color: "transparent"
            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.isMuted ? root.dangerColor : root.onInactiveColor
                font.pixelSize: 18
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.label
            color: root.isMuted ? root.dangerColor : root.onInactiveColor
            font.pixelSize: 13
            font.bold: true
            font.family: "Rubik, sans-serif"
            elide: Text.ElideRight
        }

        Text {
            text: root.displayText
            color: root.isMuted ? root.dangerColor : root.onInactiveMuted
            font.pixelSize: 12
            font.bold: true
            font.family: "Rubik, sans-serif"
        }
    }

    // СЛОЙ 2: Заполненная капсула (Active Fill) со Scissor-клиппингом
    Item {
        id: fillContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Math.max(0, Math.min(parent.width, parent.width * root.progressRatio))
        visible: !root.isMuted && root.value > 0
        clip: true

        Behavior on width {
            enabled: !sliderMouse.pressed
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        // Цветной фон активной части - полная ширина капсулы для сохранения гладких углов
        Rectangle {
            antialiasing: true
            width: root.width
            height: root.height
            radius: root.radius
            color: root.activeColor
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        // Дублирующие элементы на заполненном фоне с цветом onActiveColor
        RowLayout {
            x: 16
            width: root.width - 32
            height: root.height
            spacing: 12

            Rectangle {
                antialiasing: true
                width: 32
                height: 32
                radius: 16
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    color: root.onActiveColor
                    font.pixelSize: 18
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.label
                color: root.onActiveColor
                font.pixelSize: 13
                font.bold: true
                font.family: "Rubik, sans-serif"
                elide: Text.ElideRight
            }

            Text {
                text: root.displayText
                color: root.onActiveColor
                font.pixelSize: 12
                font.bold: true
                font.family: "Rubik, sans-serif"
            }
        }
    }

    // Обработка драга, клика и колеса мыши
    MouseArea {
        id: sliderMouse
        anchors.fill: parent
        anchors.leftMargin: 40 // чтобы клик по иконке слева не сбивал громкость в 0
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: mouse => {
            if (pressed) {
                let p = Math.max(0, Math.min(1, (mouse.x + 40) / width))
                root.valueModified(p * 100)
            }
        }
        onClicked: mouse => {
            let p = Math.max(0, Math.min(1, (mouse.x + 40) / width))
            root.valueModified(p * 100)
        }
        onWheel: wheel => {
            let step = wheel.angleDelta.y > 0 ? 5 : -5
            let n = Math.max(0, Math.min(100, root.value + step))
            root.valueModified(n)
        }
    }
}
