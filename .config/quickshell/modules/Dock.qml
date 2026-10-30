import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    required property var cfg
    property var currentScreen: null

    implicitHeight: 74
    implicitWidth: dockCapsule.width

    property var dockItems: []
    property bool isHovered: false
    property bool contextMenuOpen: false
    property var selectedItem: null
    property real menuX: 0
    property real menuY: 0

    property alias dockCapsuleItem: dockCapsule
    property alias triggerItem: bottomEdgeTrigger
    property alias contextMenuItem: contextMenuCard

    // Автоскрытие: отображается, если автоскрытие отключено, или курсор на доке/нижнем крае, или открыто меню
    readonly property bool dockVisible: !root.cfg.dockAutohide || isHovered || contextMenuOpen || bottomEdgeTrigger.containsMouse

    // Таймер задержки скрытия (500 мс для безупречной стабильности без ложных срабатываний)
    Timer {
        id: hideDelayTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!dockHoverHandler.hovered && !bottomEdgeTrigger.containsMouse && !contextMenuOpen) {
                root.isHovered = false
            }
        }
    }

    // Процесс получения данных для дока через dock_helper.py
    Process {
        id: fetchDockProc
        command: [
            "/home/stopnope/.config/quickshell/dock_helper.py",
            JSON.stringify(root.cfg.dockPinnedApps || ["firefox", "kitty", "thunar", "vesktop", "telegram"])
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0 && trimmed.startsWith("[")) {
                    try {
                        let parsed = JSON.parse(trimmed)
                        root.dockItems = parsed
                    } catch (e) {
                        console.log("Error parsing dock json:", e)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        fetchDockProc.running = true
    }

    // Периодический опрос и реакция на изменение фокуса в Hyprland
    Timer {
        interval: 1800
        running: true
        repeat: true
        onTriggered: {
            if (!fetchDockProc.running) fetchDockProc.running = true
        }
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (!fetchDockProc.running) fetchDockProc.running = true
        }
    }

    Connections {
        target: root.cfg
        function onDockPinnedAppsChanged() {
            if (!fetchDockProc.running) fetchDockProc.running = true
        }
    }

    // =========================================================================
    // 1. ТРИГГЕРНАЯ ЗОНА У НИЖНЕЙ ГРАНИЦЫ ЭКРАНА
    // =========================================================================
    MouseArea {
        id: bottomEdgeTrigger
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(dockCapsule.width + 60, 400)
        height: 6
        hoverEnabled: true
        z: 99

        onEntered: {
            hideDelayTimer.stop()
            root.isHovered = true
        }
    }

    // =========================================================================
    // 2. ДОК: ПЛАВНО ВЫЕЗЖАЕТ ИЗ САМОГО НИЗА («НАТЯГИВАЕТ ПЛЕНКУ НИЖНЕЙ ГРАНИЦЫ»)
    // =========================================================================
    Rectangle {
        antialiasing: true
        id: dockCapsule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.dockVisible ? 0 : -52
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        height: 58
        implicitWidth: iconsRow.implicitWidth + 28

        // Верхние углы мягко скруглены (radius: 20), нижние прилегают к краю экрана
        radius: 20
        // Прямоугольник-заглушка снизу, чтобы нижние углы были ровными и сливались с границей экрана
        Rectangle {
            antialiasing: true
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 20
            color: dockCapsule.color
            z: -1
        }

        color: root.cfg.surfaceContainer || Qt.rgba(0.09, 0.10, 0.13, 0.94)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        // Верхний декоративный язычок / мембрана (индикатор вытягивания)
        Rectangle {
            antialiasing: true
            anchors.top: parent.top
            anchors.topMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: 36
            height: 3
            radius: 1.5
            color: root.cfg.accent
            opacity: root.dockVisible ? 0.4 : 0.85
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // HoverHandler непрерывно отслеживает наведение мыши на ВСЮ область дока
        // Он НЕ теряет курсор при переходе между иконками или кнопками!
        HoverHandler {
            id: dockHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    hideDelayTimer.stop()
                    root.isHovered = true
                } else {
                    if (!root.contextMenuOpen) {
                        hideDelayTimer.restart()
                    }
                }
            }
        }

        // Клик правой кнопкой по пустому месту закрывает меню
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: root.contextMenuOpen = false
        }

        RowLayout {
            id: iconsRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: root.dockItems

                Item {
                    id: iconDelegate
                    required property var modelData
                    required property int index

                    width: root.cfg.dockIconSize + 12
                    height: 50

                    property bool isMenuTarget: root.contextMenuOpen && root.selectedItem !== null && root.selectedItem.appId === modelData.appId
                    property bool itemHovered: itemMouseArea.containsMouse || isMenuTarget

                    // Подложка при наведении (чистый Material 3 hover pill, без изменения размера и рывков)
                    Rectangle {
                        antialiasing: true
                        anchors.fill: parent
                        radius: 14
                        color: iconDelegate.itemHovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    // Иконка приложения
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 3
                        width: root.cfg.dockIconSize
                        height: root.cfg.dockIconSize

                        Image {
                            id: appImg
                            anchors.fill: parent
                            source: modelData.icon || ""
                            sourceSize: Qt.size(root.cfg.dockIconSize * 2, root.cfg.dockIconSize * 2)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            visible: source !== ""
                        }

                        // Фоллбэк, если иконка не найдена
                        Rectangle {
                            antialiasing: true
                            anchors.fill: parent
                            visible: !appImg.visible || appImg.status !== Image.Ready
                            radius: 12
                            color: root.cfg.bgElevated
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name.length > 0 ? modelData.name[0].toUpperCase() : "󰀻"
                                color: root.cfg.textPrimary
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }

                    // Индикатор запущенного приложения (Material 3 Pill / Dot)
                    Rectangle {
                        antialiasing: true
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 3
                        radius: 1.5
                        visible: modelData.running

                        // Ширина: 14px если активно/в фокусе, иначе 4px (аккуратная точка)
                        width: modelData.focused ? 14 : (modelData.count > 1 ? 8 : 4)
                        color: modelData.focused ? root.cfg.accent : Qt.rgba(255, 255, 255, 0.65)

                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    // Всплывающая подсказка с названием приложения (Tooltip)
                    Rectangle {
                        antialiasing: true
                        id: tooltipPill
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 24
                        implicitWidth: tipTxt.implicitWidth + 16
                        radius: 12
                        color: root.cfg.surfaceContainerHigh || Qt.rgba(0.14, 0.15, 0.18, 0.95)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        visible: iconDelegate.itemHovered && !root.contextMenuOpen
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        z: 50

                        Text {
                            id: tipTxt
                            anchors.centerIn: parent
                            text: iconDelegate.modelData.name
                            color: root.cfg.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                root.contextMenuOpen = false
                                if (iconDelegate.modelData.running && iconDelegate.modelData.windows.length > 0) {
                                    // Если окно уже в фокусе и окон несколько — переключаем на следующее
                                    if (iconDelegate.modelData.focused && iconDelegate.modelData.windows.length > 1) {
                                        let nextAddr = iconDelegate.modelData.windows[1].address
                                        Hyprland.dispatch("focuswindow", "address:" + nextAddr)
                                    } else {
                                        let firstAddr = iconDelegate.modelData.windows[0].address
                                        Hyprland.dispatch("focuswindow", "address:" + firstAddr)
                                    }
                                } else {
                                    // Запуск приложения
                                    Hyprland.dispatch("exec", iconDelegate.modelData.exec)
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                root.selectedItem = iconDelegate.modelData
                                let p = iconDelegate.mapToItem(root, 0, 0)
                                root.menuX = p.x + (iconDelegate.width / 2) - 100
                                root.contextMenuOpen = true
                            }
                        }
                    }
                }
            }
        }
    }

    // Фон-заглушка для закрытия контекстного меню при клике в любое место экрана
    MouseArea {
        anchors.fill: parent
        z: 95
        visible: root.contextMenuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.contextMenuOpen = false
    }

    // =========================================================================
    // 3. КОНТЕКСТНОЕ МЕНЮ (MATERIAL 3 CONTEXT CARD)
    // =========================================================================
    Rectangle {
        antialiasing: true
        id: contextMenuCard
        visible: root.contextMenuOpen && root.selectedItem !== null
        opacity: root.contextMenuOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        anchors.bottom: dockCapsule.top
        anchors.bottomMargin: 10
        x: Math.max(12, Math.min(root.width - width - 12, root.menuX))
        width: 200
        implicitHeight: menuCol.implicitHeight + 16
        radius: 16
        color: root.cfg.surfaceContainerHigh || Qt.rgba(0.14, 0.15, 0.19, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        z: 100

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            // Заголовок приложения
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 4
                spacing: 8

                Image {
                    source: root.selectedItem ? (root.selectedItem.icon || "") : ""
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    text: root.selectedItem ? root.selectedItem.name : ""
                    color: root.cfg.textPrimary
                    font.pixelSize: 12
                    font.bold: true
                    font.family: root.cfg.fontFamily
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                antialiasing: true
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // Список открытых окон (если есть)
            Repeater {
                model: (root.selectedItem && root.selectedItem.running) ? root.selectedItem.windows : []

                Rectangle {
                    antialiasing: true
                    required property var modelData
                    Layout.fillWidth: true
                    height: 28
                    radius: 8
                    color: winItemM.containsMouse ? root.cfg.surfaceContainerHighest || Qt.rgba(1, 1, 1, 0.08) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text { text: "󰖲"; color: root.cfg.accent; font.pixelSize: 11 }
                        Text {
                            text: modelData.title || "Окно"
                            color: root.cfg.textPrimary
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: winItemM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.contextMenuOpen = false
                            Hyprland.dispatch("focuswindow", "address:" + modelData.address)
                        }
                    }
                }
            }

            // Кнопка: Новое окно
            Rectangle {
                antialiasing: true
                Layout.fillWidth: true
                height: 28
                radius: 8
                color: newWinM.containsMouse ? root.cfg.surfaceContainerHighest || Qt.rgba(1, 1, 1, 0.08) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text { text: "󰐥"; color: root.cfg.textMuted; font.pixelSize: 11 }
                    Text { text: "Новое окно"; color: root.cfg.textPrimary; font.pixelSize: 11; Layout.fillWidth: true }
                }

                MouseArea {
                    id: newWinM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.contextMenuOpen = false
                        if (root.selectedItem) {
                            Hyprland.dispatch("exec", root.selectedItem.exec)
                        }
                    }
                }
            }

            // Кнопка: Закрепить / Открепить от дока
            Rectangle {
                antialiasing: true
                Layout.fillWidth: true
                height: 28
                radius: 8
                color: pinM.containsMouse ? root.cfg.surfaceContainerHighest || Qt.rgba(1, 1, 1, 0.08) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: (root.selectedItem && root.selectedItem.pinned) ? "󰤯" : "󰤱"
                        color: root.cfg.textMuted
                        font.pixelSize: 11
                    }
                    Text {
                        text: (root.selectedItem && root.selectedItem.pinned) ? "Открепить от дока" : "Закрепить в доке"
                        color: root.cfg.textPrimary
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: pinM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.selectedItem) {
                            if (root.selectedItem.pinned) {
                                root.cfg.unpinAppFromDock(root.selectedItem.appId)
                            } else {
                                root.cfg.pinAppToDock(root.selectedItem.appId)
                            }
                        }
                        root.contextMenuOpen = false
                    }
                }
            }

            // Кнопка: Закрыть (если запущено)
            Rectangle {
                antialiasing: true
                visible: root.selectedItem && root.selectedItem.running
                Layout.fillWidth: true
                height: 28
                radius: 8
                color: closeM.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.15) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text { text: "󰅖"; color: root.cfg.danger || "#ef4444"; font.pixelSize: 11 }
                    Text { text: "Закрыть все окна"; color: root.cfg.danger || "#ef4444"; font.pixelSize: 11; Layout.fillWidth: true }
                }

                MouseArea {
                    id: closeM
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.selectedItem && root.selectedItem.windows) {
                            for (let w of root.selectedItem.windows) {
                                Hyprland.dispatch("closewindow", "address:" + w.address)
                            }
                        }
                        root.contextMenuOpen = false
                    }
                }
            }
        }
    }
}
