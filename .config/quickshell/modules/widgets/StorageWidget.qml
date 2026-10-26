import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    required property var cfg
    property var widgetData: ({})

    readonly property string variant: (widgetData && widgetData.variant) ? widgetData.variant : "bars"
    readonly property string size: (widgetData && widgetData.size) ? widgetData.size : "M"

    property string totalSpace: "---"
    property string usedSpace: "---"
    property string freeSpace: "---"
    property int usedPercent: 45

    Process {
        id: dfProc
        running: true
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $2 \"|\" $3 \"|\" $4 \"|\" $5}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let parts = data.trim().split("|")
                if (parts.length >= 4) {
                    root.totalSpace = parts[0]
                    root.usedSpace = parts[1]
                    root.freeSpace = parts[2]
                    root.usedPercent = parseInt(parts[3].replace("%", "")) || 45
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: dfProc.running = true
    }

    radius: (widgetData && widgetData.radius !== undefined) ? widgetData.radius : (root.cfg.widgetRadius || 28)
    color: root.cfg.surfaceContainer
    border.color: root.cfg.outlineVariant
    border.width: 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10
        visible: root.variant === "bars"

        // Верхний ряд: Иконка + Заголовок + Бейдж типа диска
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 36
                height: 36
                radius: 12
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰋊"
                    color: root.cfg.accent
                    font.pixelSize: 18
                }
            }

            ColumnLayout {
                spacing: 1
                Text {
                    text: "Хранилище"
                    color: root.cfg.textPrimary
                    font.pixelSize: 12
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
                Text {
                    text: "Системный раздел (/)"
                    color: root.cfg.onSurfaceVariant
                    font.pixelSize: 10
                    font.family: root.cfg.fontFamily
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                height: 24
                width: typeBadgeText.implicitWidth + 16
                radius: 12
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)
                border.width: 1

                Text {
                    id: typeBadgeText
                    anchors.centerIn: parent
                    text: "NVMe SSD"
                    color: root.cfg.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // Информационная строка: занято vs свободно + процент
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                spacing: 4
                Text {
                    text: root.usedSpace
                    color: root.cfg.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
                Text {
                    text: "из " + root.totalSpace
                    color: root.cfg.onSurfaceVariant
                    font.pixelSize: 11
                    font.family: root.cfg.fontFamily
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                height: 22
                width: pctText.implicitWidth + 14
                radius: 11
                color: root.usedPercent > 85 ? root.cfg.danger : Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                border.color: root.usedPercent > 85 ? "transparent" : Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.28)
                border.width: 1

                Text {
                    id: pctText
                    anchors.centerIn: parent
                    text: root.usedPercent + "%"
                    color: root.usedPercent > 85 ? "#ffffff" : root.cfg.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // Толстая мягкая капсула прогресс-бара Android 14/15
        Rectangle {
            id: trackBar
            Layout.fillWidth: true
            height: 14
            radius: 7
            color: root.cfg.surfaceContainerLowest || "#181920"
            clip: true

            Rectangle {
                id: fillIndicator
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(14, trackBar.width * Math.min(1, Math.max(0, root.usedPercent / 100)))
                radius: 7
                color: root.usedPercent > 85 ? root.cfg.danger : root.cfg.accent

                Behavior on width {
                    NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 300 }
                }
            }
        }

        // Нижние бейджи: свободное место
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                height: 22
                width: freeRow.implicitWidth + 14
                radius: 11
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)
                border.width: 1

                RowLayout {
                    id: freeRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰏏"; color: root.cfg.accent; font.pixelSize: 10 }
                    Text {
                        text: "Свободно: " + root.freeSpace
                        color: root.cfg.textPrimary
                        font.pixelSize: 9
                        font.bold: true
                        font.family: root.cfg.fontFamily
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "ext4 / btrfs"
                color: Qt.rgba(root.cfg.onSurfaceVariant.r, root.cfg.onSurfaceVariant.g, root.cfg.onSurfaceVariant.b, 0.4)
                font.pixelSize: 9
                font.family: root.cfg.fontFamily
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 2: CIRCLES (РАДИАЛЬНЫЙ КРУГОВОЙ ИНДИКАТОР)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
        visible: root.variant === "circles"

        // Радиальный круговой индикатор
        Item {
            Layout.preferredWidth: Math.min(parent.height - 12, 90)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter

            Canvas {
                id: storageRingCanvas
                anchors.fill: parent

                property int pct: root.usedPercent
                onPctChanged: requestPaint()

                onPaint: {
                    let ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    let cx = width / 2
                    let cy = height / 2
                    let r = Math.min(cx, cy) - 6

                    // Фоновый трек
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.strokeStyle = "#333742"
                    ctx.lineWidth = 7.0
                    ctx.stroke()

                    // Активная дуга
                    let start = -Math.PI / 2
                    let end = start + (2 * Math.PI * Math.min(1, Math.max(0, pct / 100)))
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, end)
                    ctx.strokeStyle = pct > 85 ? root.cfg.danger : root.cfg.accent
                    ctx.lineWidth = 7.0
                    ctx.lineCap = "round"
                    ctx.stroke()
                }

                Connections {
                    target: root.cfg
                    function onAccentChanged() { storageRingCanvas.requestPaint() }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: -2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.usedPercent + "%"
                    color: root.cfg.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "SSD"
                    color: root.cfg.onSurfaceVariant
                    font.pixelSize: 8
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // Информационная часть
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Text {
                text: "Хранилище /"
                color: root.cfg.textPrimary
                font.pixelSize: 13
                font.bold: true
                font.family: root.cfg.fontFamily
            }

            Text {
                text: root.usedSpace + " занято из " + root.totalSpace
                color: root.cfg.onSurfaceVariant
                font.pixelSize: 10
                font.family: root.cfg.fontFamily
            }

            Rectangle {
                height: 22
                Layout.fillWidth: true
                radius: 11
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)
                border.width: 1
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰏏"; color: root.cfg.accent; font.pixelSize: 10 }
                    Text {
                        text: "Свободно: " + root.freeSpace
                        color: root.cfg.accent
                        font.pixelSize: 9
                        font.bold: true
                        font.family: root.cfg.fontFamily
                    }
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 3: COMPACT CAPSULES (ДВОЙНЫЕ МИНИ-КАПСУЛЫ)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        visible: root.variant === "compact_capsules"

        // Левая карточка: Системный раздел
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 18
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.outlineVariant
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    height: 22
                    implicitWidth: rBadgeTxt.implicitWidth + 14
                    radius: 11
                    color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                    Text { id: rBadgeTxt; anchors.centerIn: parent; text: "󰋊 Root (/)"; color: root.cfg.accent; font.pixelSize: 9; font.bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.usedSpace
                    color: root.cfg.textPrimary
                    font.pixelSize: 16
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.usedPercent + "% занято"
                    color: root.usedPercent > 85 ? root.cfg.danger : root.cfg.onSurfaceVariant
                    font.pixelSize: 9
                }
            }
        }

        // Правая карточка: Свободное место
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 18
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.outlineVariant
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    height: 22
                    implicitWidth: fBadgeTxt.implicitWidth + 14
                    radius: 11
                    color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                    Text { id: fBadgeTxt; anchors.centerIn: parent; text: "󰏏 Свободно"; color: root.cfg.accent; font.pixelSize: 9; font.bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.freeSpace
                    color: root.cfg.textPrimary
                    font.pixelSize: 16
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "из " + root.totalSpace
                    color: root.cfg.onSurfaceVariant
                    font.pixelSize: 9
                }
            }
        }
    }
}
