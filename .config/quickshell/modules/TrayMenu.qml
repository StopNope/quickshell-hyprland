import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Io

Rectangle {
    antialiasing: true
    id: root

    required property var cfg
    property var targetItem: null
    property int targetX: 0
    property int targetY: 0
    property bool isOpen: false

    signal closeRequested()

    implicitWidth: 260
    implicitHeight: Math.min(520, mainCol.implicitHeight + 20)
    width: implicitWidth
    height: implicitHeight

    radius: 18
    color: root.cfg.surfaceContainer || "#1e2025"
    border.color: root.cfg.outlineVariant || "#383b45"
    border.width: 1
    clip: true

    scale: root.isOpen ? 1.0 : 0.92
    opacity: root.isOpen ? 1.0 : 0.0

    Behavior on scale {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    MouseArea {
        anchors.fill: parent
        // Перехватываем клики по карточке меню, чтобы они не закрывали окно
    }

    function resolveIcon(icon) {
        if (!icon) return ""
        let s = icon.toString()
        if (s.startsWith("image://") || s.startsWith("file://")) return s
        if (s.startsWith("/")) return "file://" + s
        let p = Quickshell.iconPath(s)
        if (p) return "file://" + p
        return "image://icon/" + s
    }

    function cleanText(t) {
        if (!t) return ""
        return t.replace(/&/g, "").replace(/_/g, "").trim()
    }

    Process {
        id: killProc
    }

    function killApp() {
        if (!root.targetItem) return
        let name = ""
        let rawId = (root.targetItem.id || "").trim()
        let rawTitle = (root.targetItem.title || "").trim()

        if (rawTitle.length > 0) {
            name = rawTitle.toLowerCase()
        } else if (rawId.length > 0) {
            let parts = rawId.split(" ")
            name = parts[parts.length - 1].toLowerCase()
        }

        if (name.length > 0) {
            killProc.command = ["sh", "-c", "pkill -f '" + name + "' || killall '" + name + "'"]
            killProc.running = true
            root.cfg.pushNotification("Процесс завершен", "Приложение «" + name + "» завершено.", "Система", "󰅙")
        }
        root.closeRequested()
    }

    QsMenuOpener {
        id: menuOpener
        menu: (root.targetItem && root.targetItem.menu) ? root.targetItem.menu : null
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 6

        // ================= 1. ШАПКА ТРЕЯ =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                antialiasing: true
                width: 28
                height: 28
                radius: 14
                color: root.cfg.surfaceContainerHigh || "#282a32"

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    source: root.targetItem ? root.resolveIcon(root.targetItem.icon) : ""
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰍜"
                    color: root.cfg.accent || "#a8c7fa"
                    font.pixelSize: 14
                    visible: !parent.children[0].visible
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: {
                        if (!root.targetItem) return "Приложение"
                        let t = root.targetItem.title || root.targetItem.id || "Приложение"
                        // Делаем первую букву заглавной
                        return t.charAt(0).toUpperCase() + t.slice(1)
                    }
                    color: root.cfg.textPrimary || "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                    font.family: root.cfg.fontFamily || "Rubik, sans-serif"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "Системный трей"
                    color: root.cfg.textMuted || "#9ea2b2"
                    font.pixelSize: 10
                    font.family: root.cfg.fontFamily || "Rubik, sans-serif"
                }
            }

            // Кнопка закрытия
            Rectangle {
                antialiasing: true
                width: 24
                height: 24
                radius: 12
                color: closeMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    color: root.cfg.textMuted || "#9ea2b2"
                    font.pixelSize: 13
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Тонкий разделитель
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            height: 1
            color: root.cfg.outlineVariant || "#383b45"
        }

        // ================= 2. СПИСОК ПУНКТОВ МЕНЮ (DBUS MENU) =================
        ColumnLayout {
            id: menuCol
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: menuOpener.children

                delegate: Item {
                    id: itemRoot
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: (modelData && modelData.isSeparator) ? 7 : 30
                    height: implicitHeight

                    // Разделитель
                    Rectangle {
                        antialiasing: true
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 4
                        height: 1
                        color: root.cfg.outlineVariant || "#383b45"
                        visible: modelData.isSeparator
                    }

                    // Интерактивный пункт
                    Rectangle {
                        antialiasing: true
                        anchors.fill: parent
                        visible: !modelData.isSeparator
                        radius: 8
                        color: itemMouse.containsMouse ? (root.cfg.surfaceContainerHigh || "#2c2f38") : "transparent"
                        opacity: (modelData.enabled !== false) ? 1.0 : 0.4

                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // Опциональная иконка пункта меню
                            Image {
                                width: 14
                                height: 14
                                source: modelData.icon ? root.resolveIcon(modelData.icon) : ""
                                fillMode: Image.PreserveAspectFit
                                visible: modelData.icon && status === Image.Ready
                            }

                            // Название
                            Text {
                                Layout.fillWidth: true
                                text: root.cleanText(modelData.text)
                                color: itemMouse.containsMouse ? (root.cfg.accent || "#a8c7fa") : (root.cfg.textPrimary || "#e2e4ec")
                                font.pixelSize: 12
                                font.family: root.cfg.fontFamily || "Rubik, sans-serif"
                                elide: Text.ElideRight
                            }

                            // Индикатор галочки (check / radio)
                            Text {
                                visible: modelData.checkState !== undefined && modelData.checkState === Qt.Checked
                                text: "󰄬"
                                color: root.cfg.accent || "#a8c7fa"
                                font.pixelSize: 12
                            }

                            // Стрелка подменю
                            Text {
                                visible: modelData.hasChildren === true
                                text: "󰅂"
                                color: root.cfg.textMuted || "#9ea2b2"
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (modelData.enabled !== false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.enabled !== false) {
                                    modelData.triggered()
                                    root.closeRequested()
                                }
                            }
                        }
                    }
                }
            }

            // Заглушка, если меню пустое
            Item {
                Layout.fillWidth: true
                implicitHeight: 28
                visible: {
                    if (!menuOpener.children) return true
                    if (menuOpener.children.count !== undefined) return menuOpener.children.count === 0
                    if (menuOpener.children.values) return menuOpener.children.values.length === 0
                    if (menuOpener.children.length !== undefined) return menuOpener.children.length === 0
                    return false
                }

                Text {
                    anchors.centerIn: parent
                    text: "Нет контекстных действий"
                    color: root.cfg.textMuted || "#9ea2b2"
                    font.pixelSize: 11
                    font.italic: true
                }
            }
        }

        // Тонкий разделитель перед завершением
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            height: 1
            color: root.cfg.outlineVariant || "#383b45"
        }

        // ================= 3. КНОПКА ЗАВЕРШЕНИЯ ПРИЛОЖЕНИЯ (KILL) =================
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            implicitHeight: 32
            radius: 8
            color: killMouse.containsMouse ? Qt.rgba(0.95, 0.35, 0.35, 0.18) : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: "󰅙"
                    color: "#ff897d"
                    font.pixelSize: 14
                }

                Text {
                    text: "Завершить процесс (Kill)"
                    color: "#ff897d"
                    font.pixelSize: 12
                    font.bold: true
                    font.family: root.cfg.fontFamily || "Rubik, sans-serif"
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                id: killMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.killApp()
            }
        }
    }
}
