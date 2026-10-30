import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    antialiasing: true
    id: root

    required property var cfg
    property var widgetData: ({})

    readonly property string variant: (widgetData && widgetData.variant) ? widgetData.variant : "checklist"
    readonly property string size: (widgetData && widgetData.size) ? widgetData.size : "M"
    readonly property bool isPastel: (widgetData && widgetData.pastelTheme !== undefined) ? widgetData.pastelTheme : true

    property var tasks: [
        { text: "Собрать вещи", done: true },
        { text: "Проверить dotfiles", done: false },
        { text: "Настроить Material You", done: false }
    ]

    radius: (widgetData && widgetData.radius !== undefined) ? widgetData.radius : (root.cfg.widgetRadius || 28)
    color: isPastel ? "#faeff6" : root.cfg.surfaceContainer
    border.color: isPastel ? "transparent" : root.cfg.outlineVariant
    border.width: isPastel ? 0 : 1
    clip: true

    // ==========================================
    // ВАРИАНТ 0: GOOGLE KEEP CHECKLIST (ИЗ РЕФЕРЕНСА MATERIAL YOU 'Vacay Packing')
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10
        visible: root.variant === "checklist" || root.variant === "keep"

        // Заголовок карточки + кнопка добавления
        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 1
                Text {
                    text: (widgetData && widgetData.noteTitle) ? widgetData.noteTitle : "Задачи\nKeep"
                    color: root.isPastel ? "#3a143a" : root.cfg.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: root.cfg.fontFamily
                    lineHeight: 0.95
                }
            }

            Item { Layout.fillWidth: true }

            // Мягкая кнопка '+' (Material Squircle FAB)
            Rectangle {
                antialiasing: true
                width: 32
                height: 32
                radius: 11
                color: root.isPastel ? "#d98cd9" : root.cfg.accent

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: root.isPastel ? "#3a143a" : root.cfg.accentText
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let list = root.tasks.slice()
                        list.push({ text: "Новая задача " + (list.length + 1), done: false })
                        root.tasks = list
                    }
                }
            }
        }

        // Чек-лист интерактивный
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Repeater {
                model: root.tasks

                Rectangle {
                    antialiasing: true
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Круглый чекбокс (Material You)
                        Rectangle {
                            antialiasing: true
                            width: 22
                            height: 22
                            radius: 11
                            color: modelData.done ? "#9ab8f0" : "transparent"
                            border.color: modelData.done ? "#9ab8f0" : (root.isPastel ? "#3a143a" : root.cfg.outlineVariant)
                            border.width: modelData.done ? 0 : 2

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.done
                                text: "✓"
                                color: "#1e293b"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.text
                            color: modelData.done ? (root.isPastel ? "#886588" : root.cfg.onSurfaceVariant) : (root.isPastel ? "#3a143a" : root.cfg.textPrimary)
                            font.pixelSize: 12
                            font.weight: modelData.done ? Font.Normal : Font.DemiBold
                            font.strikeout: modelData.done
                            font.family: root.cfg.fontFamily
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let list = root.tasks.slice()
                            list[index] = { text: list[index].text, done: !list[index].done }
                            root.tasks = list
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ==========================================
    // ВАРИАНТ 1: CLASSIC (ТЕКСТОВЫЙ БЛОКНОТ)
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        visible: root.variant === "classic"

        // Верхняя строка: Иконка + Заголовок + Бейдж автосохранения
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
                    text: "󰏫"
                    color: root.cfg.accent
                    font.pixelSize: 14
                }
            }

            Text {
                text: "Заметки"
                color: root.cfg.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.cfg.fontFamily
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                antialiasing: true
                height: 22
                width: autoSaveText.implicitWidth + 14
                radius: 11
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.10)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.20)
                border.width: 1

                Text {
                    id: autoSaveText
                    anchors.centerIn: parent
                    text: "Автосохранение"
                    color: root.cfg.accent
                    font.pixelSize: 9
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // Поле для ввода заметки в мягком внутреннем контейнере
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.06)
            border.color: root.cfg.outlineVariant
            border.width: 1
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                TextArea {
                    id: noteInput
                    text: root.cfg.userNotes || ""
                    color: root.cfg.textPrimary
                    selectionColor: root.cfg.primaryContainer
                    selectedTextColor: root.cfg.onPrimaryContainer
                    placeholderText: "Напишите здесь свои заметки..."
                    placeholderTextColor: Qt.rgba(root.cfg.onSurfaceVariant.r, root.cfg.onSurfaceVariant.g, root.cfg.onSurfaceVariant.b, 0.5)
                    font.pixelSize: 11
                    font.family: root.cfg.fontFamily
                    wrapMode: TextEdit.Wrap
                    background: null
                    selectByMouse: true

                    onTextChanged: {
                        if (text !== root.cfg.userNotes) {
                            saveNoteTimer.restart()
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 2: BULLET JOURNAL (ЧЕК-ЛИСТ ЗАДАЧ)
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8
        visible: root.variant === "bullet_journal"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                antialiasing: true
                width: 26; height: 26; radius: 9
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                Text { anchors.centerIn: parent; text: "󰄲"; color: root.cfg.accent; font.pixelSize: 13 }
            }
            Text { text: "Чек-лист дня"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true; font.family: root.cfg.fontFamily }
            Item { Layout.fillWidth: true }
            Rectangle {
                antialiasing: true
                height: 20; implicitWidth: bjCnt.implicitWidth + 12; radius: 10
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                Text { id: bjCnt; anchors.centerIn: parent; text: "3 задачи"; color: root.cfg.accent; font.pixelSize: 9; font.bold: true }
            }
        }

        // Список задач с интерактивными галочками
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            property var tasks: [
                { id: 1, text: "Настроить Material You виджеты", done: true },
                { id: 2, text: "Проверить экранный редактор бара", done: true },
                { id: 3, text: "Наслаждаться рабочим столом", done: false }
            ]

            Repeater {
                model: [
                    { t: "Настроить Material You виджеты", d: true },
                    { t: "Проверить экранный редактор бара", d: true },
                    { t: "Наслаждаться идеальным сетапом", d: false }
                ]

                Rectangle {
                    antialiasing: true
                    id: taskRow
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    height: 28
                    radius: 14
                    property bool checked: modelData.d
                    color: checked ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.10) : root.cfg.surfaceContainerHigh
                    border.color: checked ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25) : root.cfg.outlineVariant
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Rectangle {
                            antialiasing: true
                            width: 16; height: 16; radius: 8
                            color: taskRow.checked ? root.cfg.accent : "transparent"
                            border.color: taskRow.checked ? root.cfg.accent : root.cfg.onSurfaceVariant
                            border.width: 1.5
                            Text {
                                anchors.centerIn: parent
                                visible: taskRow.checked
                                text: "✓"
                                color: root.cfg.accentText
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: taskRow.modelData.t
                            color: taskRow.checked ? root.cfg.onSurfaceVariant : root.cfg.textPrimary
                            font.pixelSize: 10
                            font.strikeout: taskRow.checked
                            font.family: root.cfg.fontFamily
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: taskRow.checked = !taskRow.checked
                    }
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 3: STICKY CARD (УЮТНЫЙ ПРИКОЛОТЫЙ СТИКЕР)
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8
        visible: root.variant === "sticky_card"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                antialiasing: true
                width: 24; height: 24; radius: 12
                color: Qt.rgba(root.cfg.warning.r, root.cfg.warning.g, root.cfg.warning.b, 0.2)
                Text { anchors.centerIn: parent; text: "󰤱"; color: root.cfg.warning; font.pixelSize: 12 }
            }
            Text { text: "Быстрая мысль"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
            Item { Layout.fillWidth: true }
            Text { text: "Сегодня"; color: root.cfg.onSurfaceVariant; font.pixelSize: 9; font.family: root.cfg.fontFamily }
        }

        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Qt.rgba(root.cfg.primaryContainer.r, root.cfg.primaryContainer.g, root.cfg.primaryContainer.b, 0.3)
            border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
            border.width: 1
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                TextArea {
                    text: root.cfg.userNotes || "Кликните, чтобы записать мысль..."
                    color: root.cfg.textPrimary
                    font.pixelSize: 11
                    font.italic: true
                    font.family: root.cfg.fontFamily
                    wrapMode: TextEdit.Wrap
                    background: null
                    selectByMouse: true
                    onTextChanged: {
                        if (text !== root.cfg.userNotes) {
                            root.cfg.userNotes = text
                            saveNoteTimer.restart()
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: saveNoteTimer
        interval: 600
        onTriggered: {
            root.cfg.userNotes = noteInput.text
            root.cfg.save()
        }
    }
}
