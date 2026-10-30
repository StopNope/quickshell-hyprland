import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var cfg
    property bool isOpen: false
    property var allApps: []
    property var filteredApps: []
    property string selectedCategory: "All"
    property int selectedIndex: 0

    signal closeRequested()

    // Процесс сканирования приложений из .desktop файлов
    Process {
        id: fetchAppsProc
        command: ["/home/stopnope/.config/quickshell/get_apps.py"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0 && trimmed.startsWith("[")) {
                    try {
                        root.allApps = JSON.parse(trimmed)
                        root.applyFilter()
                    } catch (e) {
                        console.log("Error parsing apps json:", e)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        fetchAppsProc.running = true
    }

    function openLauncher() {
        isOpen = true
        searchField.text = ""
        selectedCategory = "All"
        selectedIndex = 0
        applyFilter()
        fetchAppsProc.running = true
        searchField.forceActiveFocus()
    }

    function closeLauncher() {
        if (!isOpen) return
        isOpen = false
        searchField.focus = false
        closeRequested()
    }

    function applyFilter() {
        let q = searchField.text.trim().toLowerCase()
        let cat = selectedCategory
        let res = []

        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i]
            if (cat !== "All" && app.category !== cat) {
                continue
            }
            if (q.length > 0) {
                let nameMatch = (app.name || "").toLowerCase().includes(q)
                let descMatch = (app.description || "").toLowerCase().includes(q)
                let execMatch = (app.exec || "").toLowerCase().includes(q)
                let catMatch = (app.category || "").toLowerCase().includes(q)
                if (!nameMatch && !descMatch && !execMatch && !catMatch) {
                    continue
                }
            }
            res.push(app)
        }

        filteredApps = res
        selectedIndex = 0
        if (appListView) {
            appListView.positionViewAtBeginning()
        }
    }

    function launchCurrent() {
        if (filteredApps.length > 0 && selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            let app = filteredApps[selectedIndex]
            if (app && app.exec) {
                launchProc.command = ["bash", "-c", app.exec + " &"]
                launchProc.running = true
            }
        }
        closeLauncher()
    }

    function launchApp(app) {
        if (app && app.exec) {
            launchProc.command = ["bash", "-c", app.exec + " &"]
            launchProc.running = true
        }
        closeLauncher()
    }

    Process {
        id: launchProc
    }

    function moveDown() {
        if (filteredApps.length > 0) {
            selectedIndex = Math.min(filteredApps.length - 1, selectedIndex + 1)
            appListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function moveUp() {
        if (filteredApps.length > 0) {
            selectedIndex = Math.max(0, selectedIndex - 1)
            appListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function pageDown() {
        if (filteredApps.length > 0) {
            selectedIndex = Math.min(filteredApps.length - 1, selectedIndex + 5)
            appListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function pageUp() {
        if (filteredApps.length > 0) {
            selectedIndex = Math.max(0, selectedIndex - 5)
            appListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    // Клавиатурная навигация в корневом элементе
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            moveDown()
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            moveUp()
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            pageDown()
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            pageUp()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            launchCurrent()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            closeLauncher()
            event.accepted = true
        }
    }

    // Полупрозрачный фон с затемнением (клик закрывает)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: root.isOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeLauncher()
        }
    }

    // Центрированная карточка Spotlight / Launcher (Минималистичный Material You)
    Rectangle {
        id: launcherCard
        anchors.centerIn: parent
        width: 620
        height: 500
        radius: 22
        color: root.cfg.bgSurface
        border.color: root.cfg.borderCol
        border.width: 1.5

        scale: root.isOpen ? 1.0 : 0.94
        opacity: root.isOpen ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // 1. Поисковая строка Material You
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 24
                color: root.cfg.bgPrimary
                border.color: searchField.activeFocus ? root.cfg.accent : root.cfg.borderCol
                border.width: searchField.activeFocus ? 2 : 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "󰍉"
                        font.pixelSize: 18
                        font.family: root.cfg.fontFamily
                        color: searchField.activeFocus ? root.cfg.accent : root.cfg.textMuted
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: root.cfg.textPrimary
                        font.pixelSize: 14
                        font.family: root.cfg.fontFamily
                        selectByMouse: true
                        selectionColor: root.cfg.accentContainer
                        selectedTextColor: root.cfg.accent

                        Text {
                            anchors.fill: parent
                            text: "Search apps, tools, settings..."
                            color: root.cfg.textMuted
                            font.pixelSize: 14
                            font.family: root.cfg.fontFamily
                            visible: !searchField.text && !searchField.inputMethodComposing
                        }

                        onTextChanged: root.applyFilter()

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) {
                                root.moveDown()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.moveUp()
                                event.accepted = true
                            } else if (event.key === Qt.Key_PageDown) {
                                root.pageDown()
                                event.accepted = true
                            } else if (event.key === Qt.Key_PageUp) {
                                root.pageUp()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchCurrent()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                root.closeLauncher()
                                event.accepted = true
                            }
                        }
                    }

                    // Кнопка очистки поиска
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: root.cfg.bgElevated
                        visible: searchField.text.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.pixelSize: 11
                            font.family: root.cfg.fontFamily
                            color: root.cfg.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchField.text = ""
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // 2. Компактные чипы категорий (аккуратный минимализм)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: ["All", "Internet", "Development", "Media", "System", "Games"]
                    delegate: Rectangle {
                        required property string modelData
                        required property int index

                        readonly property bool isSelected: root.selectedCategory === modelData

                        height: 24
                        width: catText.implicitWidth + 16
                        radius: 12
                        color: isSelected ? root.cfg.accentContainer : "transparent"
                        border.color: isSelected ? root.cfg.accent : root.cfg.borderCol
                        border.width: isSelected ? 1 : 0.5

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            id: catText
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 11
                            font.weight: isSelected ? Font.Bold : Font.Normal
                            font.family: root.cfg.fontFamily
                            color: isSelected ? root.cfg.accent : root.cfg.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedCategory = modelData
                                root.applyFilter()
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.filteredApps.length + " apps"
                    font.pixelSize: 10
                    font.family: root.cfg.fontFamily
                    color: root.cfg.textMuted
                }
            }

            // 3. Список найденных приложений
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Если ничего не найдено
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.filteredApps.length === 0
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰍉"
                        font.pixelSize: 32
                        color: root.cfg.textMuted
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No applications found"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.family: root.cfg.fontFamily
                        color: root.cfg.textPrimary
                    }
                }

                ListView {
                    id: appListView
                    anchors.fill: parent
                    clip: true
                    spacing: 3
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredApps
                    currentIndex: root.selectedIndex

                    delegate: Item {
                        id: appItem
                        required property var modelData
                        required property int index

                        width: appListView.width
                        height: 48

                        readonly property bool isSelected: index === root.selectedIndex

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: isSelected 
                                   ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                                   : (hoverArea.containsMouse ? root.cfg.bgElevated : "transparent")
                            border.color: isSelected ? root.cfg.accent : "transparent"
                            border.width: isSelected ? 1.5 : 0

                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 12

                                // Иконка приложения
                                Rectangle {
                                    width: 32; height: 32; radius: 8
                                    color: Qt.rgba(0, 0, 0, 0.18)

                                    Image {
                                        anchors.centerIn: parent
                                        width: 24; height: 24
                                        source: (modelData.iconPath && modelData.iconPath.length > 0) ? ("file://" + modelData.iconPath) : ""
                                        fillMode: Image.PreserveAspectFit
                                        mipmap: true
                                        visible: source != ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !modelData.iconPath || modelData.iconPath.length === 0
                                        text: "󰣆"
                                        font.pixelSize: 18
                                        font.family: root.cfg.fontFamily
                                        color: isSelected ? root.cfg.accent : root.cfg.textMuted
                                    }
                                }

                                // Название приложения и легкое описание
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || "Application"
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        font.family: root.cfg.fontFamily
                                        color: root.cfg.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.description || modelData.exec || ""
                                        font.pixelSize: 11
                                        font.family: root.cfg.fontFamily
                                        color: isSelected ? root.cfg.accent : root.cfg.textMuted
                                        elide: Text.ElideRight
                                    }
                                }

                                // Категория (когда НЕ выбрано)
                                Text {
                                    visible: !isSelected && modelData.category
                                    text: modelData.category || ""
                                    font.pixelSize: 11
                                    font.family: root.cfg.fontFamily
                                    color: root.cfg.textMuted
                                }

                                // Кнопка/индикатор Launch при выборе (ровно по центру, без съезжания)
                                Rectangle {
                                    id: launchPill
                                    visible: isSelected
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: 64
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 12
                                    color: root.cfg.accent

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 4

                                        Text {
                                            text: "Open"
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            font.family: root.cfg.fontFamily
                                            color: root.cfg.accentText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Text {
                                            text: "↵"
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: root.cfg.accentText
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = index
                                onClicked: {
                                    root.selectedIndex = index
                                    root.launchApp(modelData)
                                }
                            }
                        }
                    }
                }
            }

            // 4. Минималистичный подвал
            Item {
                Layout.fillWidth: true
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↑↓ Navigate  •  ↵ Open  •  Esc Close"
                    font.pixelSize: 11
                    font.family: root.cfg.fontFamily
                    color: root.cfg.textMuted
                }
            }
        }
    }
}
