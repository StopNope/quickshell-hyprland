import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    required property var cfg
    property bool isOpen: false
    property int selectedIndex: 0
    property var windowsList: []

    signal closeRequested()

    // Процесс обновления списка окон и миниатюр из Hyprland
    Process {
        id: fetchWindowsProc
        command: ["/home/stopnope/.config/quickshell/get_windows.py"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0 && trimmed.startsWith("[")) {
                    try {
                        let parsed = JSON.parse(trimmed)
                        root.windowsList = parsed
                        if (root.windowsList.length > 1) {
                            if (root.selectedIndex === 0) {
                                root.selectedIndex = 1
                            } else if (root.selectedIndex >= root.windowsList.length) {
                                root.selectedIndex = 0
                            }
                        } else {
                            root.selectedIndex = 0
                        }
                    } catch (e) {
                        console.log("Error parsing windows json:", e)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        fetchWindowsProc.running = true
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (!root.isOpen) {
                fetchWindowsProc.running = true
            }
        }
    }

    function scrollTo(idx, animated) {
        if (idx < 0 || root.windowsList.length === 0) return
        let itemW = 234 + listView.spacing
        let totalW = root.windowsList.length * itemW - listView.spacing

        let targetX = 0
        if (totalW > listView.width) {
            let itemCenter = idx * itemW + (itemW / 2)
            targetX = itemCenter - (listView.width / 2)
            let maxX = totalW - listView.width
            targetX = Math.max(0, Math.min(maxX, targetX))
        }

        if (animated) {
            scrollAnim.stop()
            scrollAnim.from = listView.contentX
            scrollAnim.to = targetX
            scrollAnim.start()
        } else {
            scrollAnim.stop()
            listView.contentX = targetX
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: listView
        property: "contentX"
        duration: 180
        easing.type: Easing.OutCubic
    }

    onSelectedIndexChanged: {
        if (isOpen) {
            scrollTo(selectedIndex, true)
        }
    }

    function openSwitcher() {
        isOpen = true
        selectedIndex = (windowsList.length > 1) ? 1 : 0
        fetchWindowsProc.running = true
        root.forceActiveFocus()
        scrollTo(selectedIndex, false)
    }

    function selectNext() {
        if (!isOpen) {
            openSwitcher()
            return
        }
        if (windowsList.length > 0) {
            selectedIndex = (selectedIndex + 1) % windowsList.length
        }
    }

    function selectPrev() {
        if (!isOpen) {
            openSwitcher()
            if (windowsList.length > 0) {
                selectedIndex = windowsList.length - 1
            }
            return
        }
        if (windowsList.length > 0) {
            selectedIndex = (selectedIndex - 1 + windowsList.length) % windowsList.length
        }
    }

    function commit() {
        if (!isOpen) return
        if (windowsList.length > 0 && selectedIndex >= 0 && selectedIndex < windowsList.length) {
            let win = windowsList[selectedIndex]
            if (win && win.address) {
                focusProc.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ window = 'address:" + win.address + "' }))"]
                focusProc.running = true
            }
        }
        closeSwitcher()
    }

    function closeSwitcher() {
        isOpen = false
        closeRequested()
    }

    Process {
        id: focusProc
    }

    // Клавиатурная навигация в фокусе
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ShiftModifier) {
                selectPrev()
            } else {
                selectNext()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            selectPrev()
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            selectNext()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            commit()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            closeSwitcher()
            event.accepted = true
        }
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Alt) {
            commit()
            event.accepted = true
        }
    }

    // Полупрозрачный фон с затемнением (клик закрывает)
    Rectangle {
        antialiasing: true
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.isOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeSwitcher()
        }
    }

    // Минималистичная плавающая карточка переключателя (Windows 11 / Material You)
    Rectangle {
        antialiasing: true
        id: container
        anchors.centerIn: parent
        width: Math.min(1300, Math.max(500, (root.windowsList.length > 0 ? root.windowsList.length * 242 + 40 : 500)))
        height: 254
        radius: 22
        color: root.cfg.bgSurface
        border.color: root.cfg.borderCol
        border.width: 1.5

        scale: root.isOpen ? 1.0 : 0.94
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // Список открытых окон с ПРЕДПРОСМОТРОМ
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Если окон нет
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.windowsList.length === 0
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰄲"
                        font.pixelSize: 32
                        color: root.cfg.textMuted
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No active windows"
                        font.pixelSize: 13
                        color: root.cfg.textMuted
                    }
                }

                ListView {
                    id: listView
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    cacheBuffer: 3000
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: false
                    model: root.windowsList
                    currentIndex: root.selectedIndex

                    delegate: Item {
                        id: delegateItem
                        required property var modelData
                        required property int index

                        width: 234
                        height: listView.height

                        readonly property bool isSelected: index === root.selectedIndex

                        Rectangle {
                            antialiasing: true
                            id: cardRect
                            anchors.fill: parent
                            anchors.topMargin: 6
                            anchors.bottomMargin: 6
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            radius: 14
                            color: isSelected 
                                   ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                                   : root.cfg.bgElevated
                            border.color: isSelected ? root.cfg.accent : root.cfg.borderCol
                            border.width: isSelected ? 2 : 1

                            scale: isSelected ? 1.02 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                // 1. Верхняя панель карточки: Иконка приложения + Название + Воркспейс
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    // Мини-иконка приложения
                                    Rectangle {
                                        antialiasing: true
                                        width: 20; height: 20; radius: 5
                                        color: Qt.rgba(0, 0, 0, 0.2)

                                        Image {
                                            anchors.centerIn: parent
                                            width: 16; height: 16
                                            source: (modelData.iconPath && modelData.iconPath.length > 0) ? ("file://" + modelData.iconPath) : ""
                                            fillMode: Image.PreserveAspectFit
                                            mipmap: true
                                            visible: source != ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !modelData.iconPath || modelData.iconPath.length === 0
                                            text: "󰵆"
                                            font.pixelSize: 12
                                            color: root.cfg.accent
                                        }
                                    }

                                    // Имя приложения
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.appName || modelData.class || "App"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: root.cfg.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    // Бейдж Воркспейса
                                    Rectangle {
                                        antialiasing: true
                                        height: 16
                                        width: wsText.implicitWidth + 8
                                        radius: 4
                                        color: isSelected ? root.cfg.accentContainer : root.cfg.bgPrimary
                                        border.color: root.cfg.borderCol
                                        border.width: 0.5

                                        Text {
                                            id: wsText
                                            anchors.centerIn: parent
                                            text: "#" + (modelData.workspaceName || modelData.workspaceId || "1")
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: isSelected ? root.cfg.accent : root.cfg.textMuted
                                        }
                                    }
                                }

                                // 2. Центр: НАСТОЯЩИЙ ПРЕДПРОСМОТР ОКНА
                                Rectangle {
                                    antialiasing: true
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    clip: true
                                    color: root.cfg.bgPrimary
                                    border.color: isSelected ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.35) : root.cfg.borderCol
                                    border.width: 1

                                    // Реальный скриншот окна (если захвачен)
                                    Image {
                                        anchors.fill: parent
                                        visible: modelData.thumbPath && modelData.thumbPath.length > 0
                                        source: (modelData.thumbPath && modelData.thumbPath.length > 0) ? ("file://" + modelData.thumbPath) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(230, 130)
                                        mipmap: true
                                        smooth: true
                                    }

                                    // Макет фоллбэк, если окно еще не было в фокусе
                                    Item {
                                        anchors.fill: parent
                                        visible: !modelData.thumbPath || modelData.thumbPath.length === 0

                                        Rectangle {
                                            antialiasing: true
                                            anchors.centerIn: parent
                                            width: 44; height: 44; radius: 12
                                            color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)

                                            Image {
                                                anchors.centerIn: parent
                                                width: 32; height: 32
                                                source: (modelData.iconPath && modelData.iconPath.length > 0) ? ("file://" + modelData.iconPath) : ""
                                                fillMode: Image.PreserveAspectFit
                                                mipmap: true
                                                visible: source != ""
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: !modelData.iconPath || modelData.iconPath.length === 0
                                                text: "󰵆"
                                                font.pixelSize: 22
                                                color: root.cfg.accent
                                            }
                                        }
                                    }
                                }
                            }

                            // Клик мыши выбирает и сразу переключает окно
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = index
                                onClicked: {
                                    root.selectedIndex = index
                                    root.commit()
                                }
                            }
                        }
                    }
                }
            }

            // 3. Нижняя строка: Чистый заголовок активного окна по центру
            Item {
                Layout.fillWidth: true
                height: 20

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    text: (root.windowsList.length > 0 && root.selectedIndex < root.windowsList.length)
                          ? (root.windowsList[root.selectedIndex].title || "")
                          : ""
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.family: root.cfg.fontFamily
                    color: root.cfg.textPrimary
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
