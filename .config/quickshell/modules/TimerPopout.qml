import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell

Item {
    id: root

    required property var cfg
    required property var timerState
    property bool isOpen: false

    signal closeRequested()

    readonly property color barColor: root.cfg.surfaceContainer || "#1e2025"
    readonly property color borderColor: root.cfg.outlineVariant || "#383b45"
    readonly property bool isAttached: root.cfg.barStyle === "attached" && root.cfg.barPosition === "top"

    readonly property real cardW: 340
    readonly property real fR: 24
    readonly property real bR: 28
    readonly property real targetH: 330
    readonly property real totalW: isAttached ? (cardW + 2 * fR) : cardW

    implicitWidth: totalW
    width: totalW
    implicitHeight: targetH
    height: targetH
    clip: true

    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Item {
        id: slidingDrawer
        width: root.totalW
        height: root.targetH

        y: root.isOpen ? 0 : -root.targetH
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        // Монолитная геометрия для attached бара
        Shape {
            visible: root.isAttached
            width: root.totalW
            height: root.targetH

            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, root.cfg.barOpacity || 1.0)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                startX: 0
                startY: 0

                PathArc { x: root.fR; y: root.fR; radiusX: root.fR; radiusY: root.fR; direction: PathArc.Clockwise; useLargeArc: false }
                PathLine { x: root.fR; y: root.targetH - root.bR }
                PathArc { x: root.fR + root.bR; y: root.targetH; radiusX: root.bR; radiusY: root.bR; direction: PathArc.Counterclockwise; useLargeArc: false }
                PathLine { x: root.fR + root.cardW - root.bR; y: root.targetH }
                PathArc { x: root.fR + root.cardW; y: root.targetH - root.bR; radiusX: root.bR; radiusY: root.bR; direction: PathArc.Counterclockwise; useLargeArc: false }
                PathLine { x: root.fR + root.cardW; y: root.fR }
                PathArc { x: root.totalW; y: 0; radiusX: root.fR; radiusY: root.fR; direction: PathArc.Clockwise; useLargeArc: false }
                PathLine { x: 0; y: 0 }
            }

            ShapePath {
                strokeColor: (root.cfg.barBorder === false) ? "transparent" : Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.cfg.barOpacity || 1.0)
                strokeWidth: (root.cfg.barBorder === false) ? 0 : 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                startX: 0
                startY: 0

                PathArc { x: root.fR; y: root.fR; radiusX: root.fR; radiusY: root.fR; direction: PathArc.Clockwise; useLargeArc: false }
                PathLine { x: root.fR; y: root.targetH - root.bR }
                PathArc { x: root.fR + root.bR; y: root.targetH; radiusX: root.bR; radiusY: root.bR; direction: PathArc.Counterclockwise; useLargeArc: false }
                PathLine { x: root.fR + root.cardW - root.bR; y: root.targetH }
                PathArc { x: root.fR + root.cardW; y: root.targetH - root.bR; radiusX: root.bR; radiusY: root.bR; direction: PathArc.Counterclockwise; useLargeArc: false }
                PathLine { x: root.fR + root.cardW; y: root.fR }
                PathArc { x: root.totalW; y: 0; radiusX: root.fR; radiusY: root.fR; direction: PathArc.Clockwise; useLargeArc: false }
                PathLine { x: 0; y: 0 }
            }
        }

        Rectangle {
            visible: !root.isAttached
            width: root.cardW
            height: root.targetH
            radius: root.bR
            color: Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, root.cfg.barOpacity || 1.0)
            border.color: (root.cfg.barBorder === false) ? "transparent" : Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.cfg.barOpacity || 1.0)
            border.width: (root.cfg.barBorder === false) ? 0 : 1
        }

        Item {
            id: contentBody
            x: root.isAttached ? root.fR : 0
            width: root.cardW
            height: root.targetH

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Шапка
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        height: 24
                        implicitWidth: titleRow.implicitWidth + 14
                        radius: 12
                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                        border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.30)
                        border.width: 1

                        Row {
                            id: titleRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: root.timerState.modeIcon
                                color: root.cfg.accent
                                font.pixelSize: 12
                            }
                            Text {
                                text: "Помодоро Таймер"
                                color: root.cfg.textPrimary
                                font.pixelSize: 10
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: closeM.containsMouse ? (root.cfg.surfaceContainerHighest || "#303440") : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: closeM.containsMouse ? root.cfg.textPrimary : root.cfg.textMuted
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: closeM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.closeRequested()
                        }
                    }
                }

                // Пресеты режимов (Фокус, Перерыв, Отдых)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { id: 0, label: "25м Фокус", icon: "󰄉" },
                            { id: 1, label: "5м Перерыв", icon: "󰾪" },
                            { id: 2, label: "15м Отдых", icon: "󰒲" }
                        ]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 14
                            readonly property bool isCur: root.timerState.currentMode === modelData.id
                            color: isCur ? root.cfg.accent : (pM.containsMouse ? (root.cfg.surfaceContainerHighest || "#2a2d36") : "transparent")
                            border.color: isCur ? "transparent" : (root.cfg.outlineVariant || "#383b45")
                            border.width: isCur ? 0 : 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: modelData.icon
                                    color: isCur ? (root.cfg.accentText || "#ffffff") : root.cfg.textMuted
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: modelData.label
                                    color: isCur ? (root.cfg.accentText || "#ffffff") : root.cfg.textPrimary
                                    font.pixelSize: 10
                                    font.bold: isCur
                                    font.family: root.cfg.fontFamily
                                }
                            }

                            MouseArea {
                                id: pM
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.timerState.setMode(modelData.id)
                            }
                        }
                    }
                }

                // Круговой индикатор таймера
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140

                    Canvas {
                        id: progressCanvas
                        anchors.fill: parent

                        onPaint: {
                            let ctx = getContext("2d")
                            ctx.reset()
                            let cx = width / 2
                            let cy = height / 2
                            let r = Math.min(cx, cy) - 10
                            let strokeW = 7

                            // 1. Фоновая окружность
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI, false)
                            ctx.lineWidth = strokeW
                            ctx.strokeStyle = root.cfg.surfaceContainerHighest || "#282c36"
                            ctx.stroke()

                            // 2. Активная дуга прогресса
                            let ratio = root.timerState.progressRatio
                            if (ratio > 0.001) {
                                ctx.beginPath()
                                let startAngle = -0.5 * Math.PI
                                let endAngle = startAngle + ratio * (2 * Math.PI)
                                ctx.arc(cx, cy, r, startAngle, endAngle, false)
                                ctx.lineWidth = strokeW
                                ctx.lineCap = "round"
                                ctx.strokeStyle = root.cfg.accent
                                ctx.stroke()
                            }
                        }

                        Connections {
                            target: root.timerState
                            function onRemainingSecChanged() { progressCanvas.requestPaint() }
                            function onProgressRatioChanged() { progressCanvas.requestPaint() }
                            function onCurrentModeChanged() { progressCanvas.requestPaint() }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.timerState.formatTime(root.timerState.remainingSec)
                            color: root.cfg.textPrimary
                            font.pixelSize: 32
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.timerState.modeName.toUpperCase()
                            color: root.cfg.accent
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                            font.letterSpacing: 1.5
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Сессия " + (root.timerState.completedSessions + 1)
                            color: root.cfg.textMuted
                            font.pixelSize: 9
                            font.family: root.cfg.fontFamily
                        }
                    }
                }

                // Нижняя строка управления
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Сброс
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: resetM.containsMouse ? (root.cfg.surfaceContainerHighest || "#333744") : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: root.cfg.textPrimary
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: resetM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.timerState.reset()
                        }
                    }

                    // Главная Hero-кнопка Старт/Пауза
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 21
                        color: root.cfg.accent
                        scale: playM.pressed ? 0.94 : (playM.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutBack } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: root.timerState.isRunning ? "󰏤" : "󰐊"
                                color: root.cfg.accentText || "#ffffff"
                                font.pixelSize: 18
                            }
                            Text {
                                text: root.timerState.isRunning ? "Пауза" : "Старт"
                                color: root.cfg.accentText || "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }
                        }

                        MouseArea {
                            id: playM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.timerState.toggle()
                        }
                    }

                    // Следующий этап / Пропуск
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: nextM.containsMouse ? (root.cfg.surfaceContainerHighest || "#333744") : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            color: root.cfg.textPrimary
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: nextM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.timerState.nextCycle()
                        }
                    }
                }
            }
        }
    }
}
