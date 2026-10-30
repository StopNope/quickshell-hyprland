import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    antialiasing: true
    id: root

    required property var cfg
    property var widgetData: ({})

    readonly property string variant: (widgetData && widgetData.variant) ? widgetData.variant : "bars"
    readonly property string size: (widgetData && widgetData.size) ? widgetData.size : "M"

    radius: (widgetData && widgetData.radius !== undefined) ? widgetData.radius : (root.cfg.widgetRadius || 28)
    color: root.cfg.surfaceContainer
    border.color: root.cfg.outlineVariant
    border.width: 1
    clip: true

    // ==========================================
    // ВАРИАНТ 1: ПОЛОСЫ (BARS) С МЯГКИМИ КАПСУЛАМИ ANDROID 14/15
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.size === "S" ? 12 : 16
        spacing: root.size === "S" ? 6 : 10
        visible: root.variant === "bars"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                antialiasing: true
                width: 28
                height: 28
                radius: 10
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰍛"
                    color: root.cfg.accent
                    font.pixelSize: 14
                }
            }

            Text {
                text: "Системные ресурсы"
                color: root.cfg.textPrimary
                font.pixelSize: root.size === "S" ? 11 : 12
                font.bold: true
                font.family: root.cfg.fontFamily
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                antialiasing: true
                height: 22
                width: hostBadgeText.implicitWidth + 14
                radius: 11
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)
                border.width: 1

                Text {
                    id: hostBadgeText
                    anchors.centerIn: parent
                    text: "Gentoo • Hyprland"
                    color: root.cfg.accent
                    font.pixelSize: 9
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // CPU
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                antialiasing: true
                width: 24
                height: 24
                radius: 8
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                border.width: 1
                Text { anchors.centerIn: parent; text: "󰍛"; color: root.cfg.accent; font.pixelSize: 12 }
            }

            Text {
                text: "CPU"
                color: root.cfg.textPrimary
                font.pixelSize: 11
                font.bold: true
                Layout.preferredWidth: 28
            }

            Rectangle {
                antialiasing: true
                id: cpuTrack
                Layout.fillWidth: true
                height: 10
                radius: 5
                color: "#333742"
                clip: true

                Rectangle {
                    antialiasing: true
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(10, cpuTrack.width * Math.min(1, Math.max(0, root.cfg.cpuVal / 100)))
                    radius: 5
                    color: root.cfg.cpuVal > 80 ? root.cfg.danger : root.cfg.accent

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: root.cfg.cpuVal + "%"
                color: root.cfg.textPrimary
                font.pixelSize: 10
                font.bold: true
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }

        // RAM
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                antialiasing: true
                width: 24
                height: 24
                radius: 8
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                border.width: 1
                Text { anchors.centerIn: parent; text: "󰘚"; color: root.cfg.accent; font.pixelSize: 12 }
            }

            Text {
                text: "RAM"
                color: root.cfg.textPrimary
                font.pixelSize: 11
                font.bold: true
                Layout.preferredWidth: 28
            }

            Rectangle {
                antialiasing: true
                id: ramTrack
                Layout.fillWidth: true
                height: 10
                radius: 5
                color: "#333742"
                clip: true

                Rectangle {
                    antialiasing: true
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(10, ramTrack.width * Math.min(1, Math.max(0, root.cfg.ramVal / 100)))
                    radius: 5
                    color: root.cfg.ramVal > 85 ? root.cfg.danger : root.cfg.accent

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: root.cfg.ramVal + "%"
                color: root.cfg.textPrimary
                font.pixelSize: 10
                font.bold: true
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }

        // GPU
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.size !== "S"

            Rectangle {
                antialiasing: true
                width: 24
                height: 24
                radius: 8
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                border.width: 1
                Text { anchors.centerIn: parent; text: "󰢮"; color: root.cfg.accent; font.pixelSize: 12 }
            }

            Text {
                text: "GPU"
                color: root.cfg.textPrimary
                font.pixelSize: 11
                font.bold: true
                Layout.preferredWidth: 28
            }

            Rectangle {
                antialiasing: true
                id: gpuTrack
                Layout.fillWidth: true
                height: 10
                radius: 5
                color: "#333742"
                clip: true

                Rectangle {
                    antialiasing: true
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(10, gpuTrack.width * Math.min(1, Math.max(0, root.cfg.gpuVal / 100)))
                    radius: 5
                    color: root.cfg.gpuVal > 80 ? root.cfg.danger : root.cfg.accent

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: root.cfg.gpuVal + "%"
                color: root.cfg.textPrimary
                font.pixelSize: 10
                font.bold: true
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 2: ИНДИКАТОРЫ-ПЛИТКИ (GAUGES) В СТИЛЕ M3
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        visible: root.variant === "gauges"

        // Карточка CPU
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.08)
            border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.20)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Rectangle {
                    antialiasing: true
                    Layout.alignment: Qt.AlignHCenter
                    height: 22
                    width: cpuBadge.implicitWidth + 12
                    radius: 11
                    color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                    border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.28)
                    border.width: 1

                    RowLayout {
                        id: cpuBadge
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "󰍛"; color: root.cfg.accent; font.pixelSize: 11 }
                        Text { text: "CPU"; color: root.cfg.accent; font.pixelSize: 10; font.bold: true }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.cfg.cpuVal + "%"
                    color: root.cfg.cpuVal > 80 ? root.cfg.danger : root.cfg.textPrimary
                    font.pixelSize: root.size === "S" ? 22 : 28
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // Карточка RAM
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 20
            color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.08)
            border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.20)
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Rectangle {
                    antialiasing: true
                    Layout.alignment: Qt.AlignHCenter
                    height: 22
                    width: ramBadge.implicitWidth + 12
                    radius: 11
                    color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                    border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.28)
                    border.width: 1

                    RowLayout {
                        id: ramBadge
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "󰘚"; color: root.cfg.accent; font.pixelSize: 11 }
                        Text { text: "RAM"; color: root.cfg.accent; font.pixelSize: 10; font.bold: true }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.cfg.ramVal + "%"
                    color: root.cfg.ramVal > 85 ? root.cfg.danger : root.cfg.textPrimary
                    font.pixelSize: root.size === "S" ? 22 : 28
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 3: PILLS GRID (ТРИО КАПСУЛ CPU, RAM, GPU)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        visible: root.variant === "pills_grid"

        // 1. CPU Card
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 24
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.outlineVariant
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        antialiasing: true
                        width: 26; height: 26; radius: 13
                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                        Text { anchors.centerIn: parent; text: "󰍛"; color: root.cfg.accent; font.pixelSize: 13 }
                    }
                    Text { text: "CPU"; color: root.cfg.onSurfaceVariant; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.cfg.cpuVal + "%"
                    color: root.cfg.cpuVal > 80 ? root.cfg.danger : root.cfg.textPrimary
                    font.pixelSize: root.size === "S" ? 18 : 24
                    font.bold: true
                    font.family: "Fredoka"
                }

                Rectangle {
                    antialiasing: true
                    Layout.fillWidth: true
                    height: 12
                    radius: 6
                    color: root.cfg.surfaceContainerLowest || "#181920"
                    clip: true

                    Rectangle {
                        antialiasing: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: Math.max(12, parent.width * Math.min(1, Math.max(0, root.cfg.cpuVal / 100)))
                        radius: 6
                        color: root.cfg.cpuVal > 80 ? root.cfg.danger : root.cfg.accent
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // 2. RAM Card
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 24
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.outlineVariant
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        antialiasing: true
                        width: 26; height: 26; radius: 13
                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                        Text { anchors.centerIn: parent; text: "󰘚"; color: root.cfg.accent; font.pixelSize: 13 }
                    }
                    Text { text: "RAM"; color: root.cfg.onSurfaceVariant; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.cfg.ramVal + "%"
                    color: root.cfg.ramVal > 85 ? root.cfg.danger : root.cfg.textPrimary
                    font.pixelSize: root.size === "S" ? 18 : 24
                    font.bold: true
                    font.family: "Fredoka"
                }

                Rectangle {
                    antialiasing: true
                    Layout.fillWidth: true
                    height: 12
                    radius: 6
                    color: root.cfg.surfaceContainerLowest || "#181920"
                    clip: true

                    Rectangle {
                        antialiasing: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: Math.max(12, parent.width * Math.min(1, Math.max(0, root.cfg.ramVal / 100)))
                        radius: 6
                        color: root.cfg.ramVal > 85 ? root.cfg.danger : root.cfg.accent
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // 3. GPU Card
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 24
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.outlineVariant
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        antialiasing: true
                        width: 26; height: 26; radius: 13
                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                        Text { anchors.centerIn: parent; text: "󰢮"; color: root.cfg.accent; font.pixelSize: 13 }
                    }
                    Text { text: "GPU"; color: root.cfg.onSurfaceVariant; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.cfg.gpuVal + "%"
                    color: root.cfg.gpuVal > 80 ? root.cfg.danger : root.cfg.textPrimary
                    font.pixelSize: root.size === "S" ? 18 : 24
                    font.bold: true
                    font.family: "Fredoka"
                }

                Rectangle {
                    antialiasing: true
                    Layout.fillWidth: true
                    height: 12
                    radius: 6
                    color: root.cfg.surfaceContainerLowest || "#181920"
                    clip: true

                    Rectangle {
                        antialiasing: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: Math.max(12, parent.width * Math.min(1, Math.max(0, root.cfg.gpuVal / 100)))
                        radius: 6
                        color: root.cfg.gpuVal > 80 ? root.cfg.danger : root.cfg.accent
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
