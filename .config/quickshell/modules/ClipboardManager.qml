import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var cfg
    property bool isOpen: false
    property var allItems: []
    property var filteredItems: []
    property string selectedCategory: "All" // "All", "Screenshots", "Text"
    property int selectedIndex: 0

    signal closeRequested()

    // Процесс чтения истории из cliphist
    Process {
        id: fetchClipboardProc
        command: ["/home/stopnope/.config/quickshell/get_clipboard.py"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed.length > 0 && trimmed.startsWith("[")) {
                    try {
                        root.allItems = JSON.parse(trimmed)
                        root.applyFilter()
                    } catch (e) {
                        console.log("Error parsing clipboard json:", e)
                    }
                }
            }
        }
    }

    // Процесс выполнения действий (copy, delete, clear)
    Process {
        id: actionProc
        onExited: {
            fetchClipboardProc.running = true
        }
    }

    Component.onCompleted: {
        fetchClipboardProc.running = true
    }

    function openClipboard() {
        isOpen = true
        searchField.text = ""
        selectedCategory = "All"
        selectedIndex = 0
        fetchClipboardProc.running = true
        searchField.forceActiveFocus()
    }

    function closeClipboard() {
        if (!isOpen) return
        isOpen = false
        searchField.focus = false
        closeRequested()
    }

    function applyFilter() {
        let q = searchField.text.trim().toLowerCase()
        let cat = selectedCategory
        let res = []

        for (let i = 0; i < allItems.length; i++) {
            let item = allItems[i]
            if (cat === "Screenshots" && item.type !== "image") continue
            if (cat === "Text" && item.type !== "text") continue

            if (q.length > 0) {
                let previewMatch = (item.preview || "").toLowerCase().includes(q)
                let dimsMatch = (item.dims || "").toLowerCase().includes(q)
                let sizeMatch = (item.size || "").toLowerCase().includes(q)
                let typeMatch = false
                if (item.type === "image" && ("screenshot".includes(q) || "image".includes(q) || "png".includes(q) || "скрин".includes(q))) {
                    typeMatch = true
                }
                if (!previewMatch && !dimsMatch && !sizeMatch && !typeMatch) {
                    continue
                }
            }
            res.push(item)
        }

        filteredItems = res
        if (selectedIndex >= filteredItems.length) {
            selectedIndex = Math.max(0, filteredItems.length - 1)
        }
        if (clipListView) {
            clipListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function copyCurrent() {
        if (filteredItems.length > 0 && selectedIndex >= 0 && selectedIndex < filteredItems.length) {
            copyItem(filteredItems[selectedIndex])
        }
    }

    function copyItem(item) {
        if (!item) return
        actionProc.command = ["/home/stopnope/.config/quickshell/get_clipboard.py", "--copy", item.id]
        actionProc.running = true
        closeClipboard()
    }

    function deleteCurrent() {
        if (filteredItems.length > 0 && selectedIndex >= 0 && selectedIndex < filteredItems.length) {
            deleteItem(filteredItems[selectedIndex])
        }
    }

    function deleteItem(item) {
        if (!item) return
        // Оптимистичное мгновенное удаление из локального списка
        let newAll = []
        for (let i = 0; i < allItems.length; i++) {
            if (allItems[i].id !== item.id) newAll.push(allItems[i])
        }
        allItems = newAll
        applyFilter()

        // Запуск удаления в cliphist
        actionProc.command = ["/home/stopnope/.config/quickshell/get_clipboard.py", "--delete", item.id]
        actionProc.running = true
    }

    function clearHistory() {
        allItems = []
        filteredItems = []
        actionProc.command = ["/home/stopnope/.config/quickshell/get_clipboard.py", "--clear"]
        actionProc.running = true
    }

    function moveDown() {
        if (filteredItems.length > 0) {
            selectedIndex = Math.min(filteredItems.length - 1, selectedIndex + 1)
            clipListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function moveUp() {
        if (filteredItems.length > 0) {
            selectedIndex = Math.max(0, selectedIndex - 1)
            clipListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function pageDown() {
        if (filteredItems.length > 0) {
            selectedIndex = Math.min(filteredItems.length - 1, selectedIndex + 5)
            clipListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function pageUp() {
        if (filteredItems.length > 0) {
            selectedIndex = Math.max(0, selectedIndex - 5)
            clipListView.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    readonly property int imageCount: {
        let count = 0
        for (let i = 0; i < allItems.length; i++) {
            if (allItems[i].type === "image") count++
        }
        return count
    }

    readonly property int textCount: {
        let count = 0
        for (let i = 0; i < allItems.length; i++) {
            if (allItems[i].type === "text") count++
        }
        return count
    }

    // Обработка клавиш в корневом элементе
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
            copyCurrent()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete) {
            deleteCurrent()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            closeClipboard()
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
            onClicked: root.closeClipboard()
        }
    }

    // Центрированная карточка буфера обмена (Минималистичный Material You)
    Rectangle {
        antialiasing: true
        id: clipboardCard
        anchors.centerIn: parent
        width: 640
        height: 520
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
                antialiasing: true
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
                        text: "󰅍"
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
                            text: "Search clipboard history, screenshots, text..."
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
                                root.copyCurrent()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Delete) {
                                if (searchField.text.length === 0 || (event.modifiers & Qt.ShiftModifier)) {
                                    root.deleteCurrent()
                                    event.accepted = true
                                }
                            } else if (event.key === Qt.Key_Escape) {
                                root.closeClipboard()
                                event.accepted = true
                            }
                        }
                    }

                    // Кнопка очистки поиска
                    Rectangle {
                        antialiasing: true
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

                // Кнопка "All"
                Rectangle {
                    antialiasing: true
                    height: 24
                    width: allText.implicitWidth + 16
                    radius: 12
                    color: root.selectedCategory === "All" ? root.cfg.accentContainer : "transparent"
                    border.color: root.selectedCategory === "All" ? root.cfg.accent : root.cfg.borderCol
                    border.width: root.selectedCategory === "All" ? 1 : 0.5

                    Text {
                        id: allText
                        anchors.centerIn: parent
                        text: "All (" + root.allItems.length + ")"
                        font.pixelSize: 11
                        font.weight: root.selectedCategory === "All" ? Font.Bold : Font.Normal
                        font.family: root.cfg.fontFamily
                        color: root.selectedCategory === "All" ? root.cfg.accent : root.cfg.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedCategory = "All"
                            root.applyFilter()
                        }
                    }
                }

                // Кнопка "Screenshots"
                Rectangle {
                    antialiasing: true
                    height: 24
                    width: screensText.implicitWidth + 18
                    radius: 12
                    color: root.selectedCategory === "Screenshots" ? root.cfg.accentContainer : "transparent"
                    border.color: root.selectedCategory === "Screenshots" ? root.cfg.accent : root.cfg.borderCol
                    border.width: root.selectedCategory === "Screenshots" ? 1 : 0.5

                    Row {
                        id: screensText
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰹑"
                            font.pixelSize: 12
                            font.family: root.cfg.fontFamily
                            color: root.selectedCategory === "Screenshots" ? root.cfg.accent : root.cfg.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Screenshots (" + root.imageCount + ")"
                            font.pixelSize: 11
                            font.weight: root.selectedCategory === "Screenshots" ? Font.Bold : Font.Normal
                            font.family: root.cfg.fontFamily
                            color: root.selectedCategory === "Screenshots" ? root.cfg.accent : root.cfg.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedCategory = "Screenshots"
                            root.applyFilter()
                        }
                    }
                }

                // Кнопка "Text"
                Rectangle {
                    antialiasing: true
                    height: 24
                    width: textCatText.implicitWidth + 18
                    radius: 12
                    color: root.selectedCategory === "Text" ? root.cfg.accentContainer : "transparent"
                    border.color: root.selectedCategory === "Text" ? root.cfg.accent : root.cfg.borderCol
                    border.width: root.selectedCategory === "Text" ? 1 : 0.5

                    Row {
                        id: textCatText
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰦨"
                            font.pixelSize: 12
                            font.family: root.cfg.fontFamily
                            color: root.selectedCategory === "Text" ? root.cfg.accent : root.cfg.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Text (" + root.textCount + ")"
                            font.pixelSize: 11
                            font.weight: root.selectedCategory === "Text" ? Font.Bold : Font.Normal
                            font.family: root.cfg.fontFamily
                            color: root.selectedCategory === "Text" ? root.cfg.accent : root.cfg.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedCategory = "Text"
                            root.applyFilter()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Кнопка очистки всей истории
                Rectangle {
                    antialiasing: true
                    height: 24
                    width: clearText.implicitWidth + 16
                    radius: 12
                    color: "transparent"

                    Row {
                        id: clearText
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰃢"
                            font.pixelSize: 12
                            font.family: root.cfg.fontFamily
                            color: root.cfg.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Clear all"
                            font.pixelSize: 11
                            font.family: root.cfg.fontFamily
                            color: root.cfg.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearHistory()
                    }
                }
            }

            // 3. Список элементов буфера
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Заглушка, если ничего не найдено
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.filteredItems.length === 0
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰅍"
                        font.pixelSize: 32
                        font.family: root.cfg.fontFamily
                        color: root.cfg.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.allItems.length === 0 ? "Clipboard is empty" : "No matching items found"
                        font.pixelSize: 13
                        font.family: root.cfg.fontFamily
                        color: root.cfg.textMuted
                    }
                }

                ListView {
                    id: clipListView
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredItems
                    currentIndex: root.selectedIndex

                    delegate: Item {
                        id: clipDelegate
                        required property var modelData
                        required property int index

                        width: clipListView.width
                        height: modelData.type === "image" ? 94 : 54

                        readonly property bool isSelected: index === root.selectedIndex

                        Rectangle {
                            antialiasing: true
                            anchors.fill: parent
                            radius: 12
                            color: isSelected 
                                   ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                                   : (cardMouseArea.containsMouse ? root.cfg.bgElevated : "transparent")
                            border.color: isSelected ? root.cfg.accent : "transparent"
                            border.width: isSelected ? 1.5 : 0

                            Behavior on color { ColorAnimation { duration: 80 } }

                            // 1. ДЛЯ ИЗОБРАЖЕНИЙ / СКРИНШОТОВ (Аккуратный вид)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 12
                                visible: modelData.type === "image"

                                // Превью скриншота
                                Rectangle {
                                    antialiasing: true
                                    width: 136
                                    Layout.fillHeight: true
                                    Layout.topMargin: 6
                                    Layout.bottomMargin: 6
                                    radius: 8
                                    color: root.cfg.bgPrimary
                                    border.color: isSelected ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.3) : root.cfg.borderCol
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: (modelData.imagePath && modelData.imagePath.length > 0) ? ("file://" + modelData.imagePath) : ""
                                        fillMode: Image.PreserveAspectFit
                                        mipmap: true
                                        smooth: true
                                    }
                                }

                                // Описание скриншота
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    RowLayout {
                                        spacing: 6

                                        Text {
                                            text: "󰹑 Screenshot"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            font.family: root.cfg.fontFamily
                                            color: isSelected ? root.cfg.accent : root.cfg.textPrimary
                                        }

                                        Text {
                                            visible: modelData.dims && modelData.dims.length > 0
                                            text: "•  " + modelData.dims
                                            font.pixelSize: 11
                                            font.family: root.cfg.fontFamily
                                            color: root.cfg.textMuted
                                        }

                                        Text {
                                            visible: modelData.size && modelData.size.length > 0
                                            text: "•  " + modelData.size
                                            font.pixelSize: 11
                                            font.family: root.cfg.fontFamily
                                            color: root.cfg.textMuted
                                        }
                                    }

                                    Text {
                                        text: isSelected ? "↵ Press Enter or click to paste" : "PNG image"
                                        font.pixelSize: 11
                                        font.family: root.cfg.fontFamily
                                        color: isSelected ? root.cfg.accent : root.cfg.textMuted
                                    }
                                }

                                // Кнопка удалить (появляется при выборе или наведении)
                                Rectangle {
                                    antialiasing: true
                                    z: 10
                                    width: 28; height: 28; radius: 14
                                    visible: isSelected || cardMouseArea.containsMouse
                                    color: "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        font.pixelSize: 14
                                        color: delMouseArea.containsMouse ? "#ff5f56" : root.cfg.textMuted
                                    }

                                    MouseArea {
                                        id: delMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteItem(modelData)
                                    }
                                }
                            }

                            // 2. ДЛЯ ТЕКСТОВЫХ ЭЛЕМЕНТОВ (Аккуратный вид)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 12
                                visible: modelData.type === "text"

                                // Иконка текста
                                Rectangle {
                                    antialiasing: true
                                    width: 32; height: 32; radius: 8
                                    color: isSelected ? root.cfg.accentContainer : root.cfg.bgElevated

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰦨"
                                        font.pixelSize: 15
                                        color: isSelected ? root.cfg.accent : root.cfg.textMuted
                                    }
                                }

                                // Текст сниппета
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.preview || ""
                                        font.pixelSize: 13
                                        font.family: root.cfg.fontFamily
                                        font.weight: isSelected ? Font.Medium : Font.Normal
                                        color: root.cfg.textPrimary
                                        maximumLineCount: 1
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.size || ""
                                        font.pixelSize: 10
                                        font.family: root.cfg.fontFamily
                                        color: root.cfg.textMuted
                                    }
                                }

                                // Кнопка удалить (появляется при выборе или наведении)
                                Rectangle {
                                    antialiasing: true
                                    z: 10
                                    width: 28; height: 28; radius: 14
                                    visible: isSelected || cardMouseArea.containsMouse
                                    color: "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        font.pixelSize: 14
                                        color: delTxtMouseArea.containsMouse ? "#ff5f56" : root.cfg.textMuted
                                    }

                                    MouseArea {
                                        id: delTxtMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteItem(modelData)
                                    }
                                }
                            }

                            // Клик по всей карточке выбирает и копирует
                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                z: 1
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = index
                                onClicked: root.copyItem(modelData)
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
                    text: "↑↓ Navigate  •  ↵ Paste  •  Del Remove  •  Esc Close"
                    font.pixelSize: 11
                    font.family: root.cfg.fontFamily
                    color: root.cfg.textMuted
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.filteredItems.length > 0) ? ((root.selectedIndex + 1) + " of " + root.filteredItems.length) : "0 items"
                    font.pixelSize: 11
                    font.family: root.cfg.fontFamily
                    color: root.cfg.textMuted
                }
            }
        }
    }
}
