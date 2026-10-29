import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "./m3"

Rectangle {
    id: root

    required property var cfg
    signal closeRequested()
    signal requestWidgetEditor(string mode)

    width: 980
    height: 660
    radius: 28
    color: root.cfg.bgPrimary
    border.color: root.cfg.borderCol
    border.width: 1

    property string tab: "bar" // "bar", "dock", "widgets", "side", "themes", "osd", "lock", "system"
    property string navSearchText: ""
    onTabChanged: {
        if (typeof tabFlickable !== "undefined" && tabFlickable) tabFlickable.contentY = 0
    }

    function getTabTitle(tabId) {
        switch (tabId) {
            case "bar": return "Панель задач и модули"
            case "dock": return "Док-бар приложений"
            case "widgets": return "Виджеты рабочего стола"
            case "side": return "Шторка быстрых настроек"
            case "themes": return "Темы оформления и цвета"
            case "osd": return "Экранные индикаторы (OSD)"
            case "lock": return "Экран блокировки"
            case "system": return "Система и хост"
            default: return "Настройки"
        }
    }

    function getTabSubtitle(tabId) {
        switch (tabId) {
            case "bar": return "Управление положением, стилем оформления и активными модулями панели"
            case "dock": return "Парящий док приложений, автоскрытие и интерактивный запуск"
            case "widgets": return "Коллекция Material You виджетов, темы и сетка на рабочем столе"
            case "side": return "Шторка управления, плитки быстрых настроек, медиаплеер и ползунки"
            case "themes": return "Динамическая цветовая палитра Monet, обои и скругления Material 3"
            case "osd": return "Экранные оверлеи громкости, яркости и переключения языка ввода"
            case "lock": return "Парящий экран блокировки, PIN-код и параметры безопасности"
            case "system": return "Параметры окружения Hyprland, сессии и системная информация"
            default: return "Персонализация рабочей среды"
        }
    }

    Process {
        id: reloadProc
        running: false
        command: ["sh", "-c", "killall quickshell && nohup quickshell -d -p ~/.config/quickshell > /tmp/quickshell_test.log 2>&1 &"]
    }

    Process {
        id: lockActionProc
        running: false
        command: ["sh", "-c", "echo lock > $XDG_RUNTIME_DIR/qs.pipe"]
    }

    function scrollContent(y) {
        if (typeof tabFlickable !== "undefined" && tabFlickable) {
            tabFlickable.contentY = Math.max(0, Math.min(tabFlickable.contentHeight - tabFlickable.height, y))
        }
    }

    focus: true
    Keys.onEscapePressed: root.closeRequested()
    Shortcut { sequence: "Escape"; onActivated: root.closeRequested() }

    Process { id: settingsSysProc }
    property bool clampToMonitor: false

    Process {
        id: checkClampProc
        running: true
        command: ["python3", "/home/stopnope/.config/quickshell/scripts/vxwm_controller.py", "status"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    let st = JSON.parse(data.trim())
                    root.clampToMonitor = st.clampToMonitor === true
                } catch(e) {}
            }
        }
    }

    // ОСНОВНОЙ СПЛИТ-ЛЕЙАУТ: НАВИГАЦИЯ СЛЕВА + КОНТЕНТ СПРАВА (ПОЛНАЯ ВЫСОТА ОКНА БЕЗ ЛИШНИХ РАМОК)
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ЛЕВАЯ ПАНЕЛЬ НАВИГАЦИИ (Material 3 Navigation Rail)
        Rectangle {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            color: root.cfg.surfaceContainerLow || Qt.darker(root.cfg.bgElevated, 1.12)
            radius: 28

            // Прячем правые углы, чтобы была ровная вертикальная граница
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 28
                color: parent.color
            }

            // Тонкий вертикальный разделитель M3
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 1
                color: root.cfg.outlineVariant
                opacity: 0.45
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // ШАПКА RAIL: БРЕНДИНГ И ПОИСК
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    spacing: 10

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 12
                        color: root.cfg.accentContainer || Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            color: root.cfg.accent
                            font.pixelSize: 18
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Настройки"
                            color: root.cfg.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }

                        Text {
                            text: "Material You · M3"
                            color: root.cfg.textMuted
                            font.pixelSize: 10
                            font.family: root.cfg.fontFamily
                        }
                    }
                }

                    // ПОЛЕ БЫСТРОГО ПОИСКА РАЗДЕЛОВ
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 18
                        color: searchNavInput.activeFocus ? root.cfg.surfaceContainerHigh : Qt.rgba(255, 255, 255, 0.04)
                        border.color: searchNavInput.activeFocus ? root.cfg.accent : root.cfg.outlineVariant
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "󰍉"
                                color: searchNavInput.activeFocus ? root.cfg.accent : root.cfg.textMuted
                                font.pixelSize: 13
                            }

                            TextInput {
                                id: searchNavInput
                                Layout.fillWidth: true
                                clip: true
                                color: root.cfg.textPrimary
                                font.pixelSize: 11
                                font.family: root.cfg.fontFamily
                                selectByMouse: true
                                onTextChanged: root.navSearchText = text

                                Text {
                                    anchors.fill: parent
                                    visible: !searchNavInput.text && !searchNavInput.activeFocus
                                    text: "Поиск настроек..."
                                    color: root.cfg.textMuted
                                    font.pixelSize: 11
                                    font.family: root.cfg.fontFamily
                                }
                            }

                            Text {
                                visible: !!searchNavInput.text
                                text: "󰅖"
                                color: root.cfg.textMuted
                                font.pixelSize: 11
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchNavInput.text = ""
                                        root.navSearchText = ""
                                    }
                                }
                            }
                        }
                    }

                    // СПИСОК РАЗДЕЛОВ НАВИГАЦИИ (M3 GROUPED PILLS)
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: navCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: navCol
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: [
                                    { type: "section", title: "ИНТЕРФЕЙС" },
                                    { id: "bar", title: "Бар и модули", icon: "󰕮" },
                                    { id: "dock", title: "Док-бар", icon: "󰀻" },
                                    { id: "widgets", title: "Виджеты", icon: "󰕰" },
                                    { id: "side", title: "Шторка", icon: "󰍜" },
                                    { type: "section", title: "ПЕРСОНАЛИЗАЦИЯ" },
                                    { id: "themes", title: "Темы и цвета", icon: "󰏘" },
                                    { id: "osd", title: "Индикаторы OSD", icon: "󰂚" },
                                    { id: "lock", title: "Блокировка", icon: "󰌾" },
                                    { type: "section", title: "СИСТЕМА" },
                                    { id: "system", title: "Система и хост", icon: "󰒋" }
                                ]

                                Item {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: modelData.type === "section" ? 18 : (matchesSearch ? 36 : 0)
                                    visible: modelData.type === "section" ? (!root.navSearchText || root.navSearchText.length === 0) : matchesSearch

                                    readonly property bool matchesSearch: !root.navSearchText || (modelData.title && modelData.title.toLowerCase().indexOf(root.navSearchText.toLowerCase()) !== -1)
                                    readonly property bool isSelected: root.tab === modelData.id

                                    // ЗАГОЛОВОК СЕКЦИИ
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2
                                        visible: modelData.type === "section"
                                        text: modelData.title || ""
                                        color: root.cfg.textMuted
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: root.cfg.fontFamily
                                        font.letterSpacing: 0.8
                                    }

                                    // ПИЛЮЛЯ НАВИГАЦИИ (M3 NAVIGATION PILL)
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: modelData.type !== "section"
                                        radius: 18
                                        color: parent.isSelected
                                               ? (root.cfg.accentContainer || Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22))
                                               : (navMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : "transparent")

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 12
                                            spacing: 10

                                            // Иконка в мягкой круглой подложке
                                            Rectangle {
                                                Layout.preferredWidth: 26
                                                Layout.preferredHeight: 26
                                                radius: 13
                                                color: parent.parent.parent.isSelected
                                                       ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.24)
                                                       : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.icon || ""
                                                    color: parent.parent.parent.parent.isSelected
                                                           ? root.cfg.accent
                                                           : (navMouse.containsMouse ? root.cfg.textPrimary : root.cfg.textMuted)
                                                    font.pixelSize: 14
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.title || ""
                                                color: parent.parent.isSelected
                                                       ? (root.cfg.onPrimaryContainer || root.cfg.accent)
                                                       : (navMouse.containsMouse ? root.cfg.textPrimary : root.cfg.textPrimary)
                                                font.pixelSize: 12
                                                font.weight: parent.parent.isSelected ? Font.DemiBold : Font.Normal
                                                font.family: root.cfg.fontFamily
                                                elide: Text.ElideRight
                                            }

                                            // Правый микро-маркер активного состояния
                                            Rectangle {
                                                Layout.preferredWidth: 4
                                                Layout.preferredHeight: 14
                                                radius: 2
                                                color: root.cfg.accent
                                                visible: parent.parent.isSelected
                                            }
                                        }

                                        MouseArea {
                                            id: navMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.tab = modelData.id
                                                root.forceActiveFocus()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // КАРТОЧКА ПОЛЬЗОВАТЕЛЯ И СИСТЕМЫ ВНИЗУ RAIL (ЗАПОЛНЯЕТ ПУСТОТУ)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        radius: 16
                        color: Qt.rgba(255, 255, 255, 0.03)
                        border.color: root.cfg.outlineVariant
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            // Верхняя строка: Аватар + Пользователь + Хост
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: root.cfg.accent

                                    Text {
                                        anchors.centerIn: parent
                                        text: (root.cfg.userName || "S").charAt(0).toUpperCase()
                                        color: root.cfg.accentText
                                        font.pixelSize: 14
                                        font.bold: true
                                        font.family: "Fredoka"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: root.cfg.userName || "stopnope"
                                        color: root.cfg.textPrimary
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: root.cfg.fontFamily
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "Gentoo Linux · Hyprland"
                                        color: root.cfg.textMuted
                                        font.pixelSize: 10
                                        font.family: root.cfg.fontFamily
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // Нижняя строка: Быстрые действия (Перезагрузка shell, статус)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: reloadM.containsMouse ? root.cfg.surfaceContainerHigh : Qt.rgba(255, 255, 255, 0.05)
                                    border.color: root.cfg.outlineVariant
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "󰑐"; color: root.cfg.accent; font.pixelSize: 11 }
                                        Text { text: "Перезагрузить"; color: root.cfg.textPrimary; font.pixelSize: 10; font.family: root.cfg.fontFamily }
                                    }

                                    MouseArea {
                                        id: reloadM
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: reloadProc.running = true
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: lockM.containsMouse ? root.cfg.surfaceContainerHigh : Qt.rgba(255, 255, 255, 0.05)
                                    border.color: root.cfg.outlineVariant
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰌾"
                                        color: lockM.containsMouse ? root.cfg.accent : root.cfg.textMuted
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: lockM
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.cfg.save()
                                            lockActionProc.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ПРАВАЯ РАБОЧАЯ ОБЛАСТЬ
            Item {
                id: mainWorkArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8

                    // ВЕРХНЯЯ ШАПКА ПРАВОЙ ПАНЕЛИ: ТЕКУЩИЙ РАЗДЕЛ + ОПИСАНИЕ + ДЕЙСТВИЯ
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 6
                        Layout.topMargin: 2
                        Layout.bottomMargin: 8
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.getTabTitle(root.tab)
                                color: root.cfg.textPrimary
                                font.pixelSize: 20
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }

                            Text {
                                text: root.getTabSubtitle(root.tab)
                                color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                                font.pixelSize: 11
                                font.family: root.cfg.fontFamily
                            }
                        }

                        // Кнопка быстрого вызова экранного редактора
                        Rectangle {
                            visible: root.tab === "bar" || root.tab === "widgets"
                            height: 32
                            implicitWidth: topEdTxt.implicitWidth + 24
                            radius: 16
                            color: root.cfg.accent
                            scale: topEdMouse.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: "󰕮"; color: root.cfg.accentText; font.pixelSize: 12 }
                                Text {
                                    id: topEdTxt
                                    text: "Экранный редактор"
                                    color: root.cfg.accentText
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: root.cfg.fontFamily
                                }
                            }

                            MouseArea {
                                id: topEdMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    let mode = root.tab === "bar" ? "bar" : "widgets"
                                    root.closeRequested()
                                    root.requestWidgetEditor(mode)
                                }
                            }
                        }

                        // Кнопка закрытия окна
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: closeBtnMouse.containsMouse ? root.cfg.surfaceContainerHigh : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: closeBtnMouse.containsMouse ? root.cfg.textPrimary : root.cfg.textMuted
                                font.pixelSize: 15
                            }
                            MouseArea {
                                id: closeBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeRequested()
                            }
                        }
                    }

                    // РАБОЧАЯ ОБЛАСТЬ FLICKABLE
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Flickable {
                            id: tabFlickable
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: tabContentItem.implicitHeight + 30
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: wheel => {
                            let step = wheel.angleDelta.y > 0 ? -70 : 70
                            let newY = tabFlickable.contentY + step
                            tabFlickable.contentY = Math.max(0, Math.min(tabFlickable.contentHeight - tabFlickable.height, newY))
                        }
                    }

                    Item {
                        id: tabContentItem
                        width: tabFlickable.width
                        implicitHeight: {
                            if (root.tab === "bar") return barTabCol.implicitHeight
                            if (root.tab === "dock") return dockTabCol.implicitHeight
                            if (root.tab === "side") return sideTabCol.implicitHeight
                            if (root.tab === "widgets") return widgetsTabCol.implicitHeight
                            if (root.tab === "lock") return lockTabCol.implicitHeight
                            if (root.tab === "themes") return themesTabCol.implicitHeight
                            if (root.tab === "osd") return osdTabCol.implicitHeight
                            if (root.tab === "system") return systemTabCol.implicitHeight
                            return 700
                        }

                        // ================= ВКЛАДКА 1: БАР И МОДУЛИ =================
                        ColumnLayout {
                            id: barTabCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 16
                            visible: root.tab === "bar"

                            property string currentZone: "left"
                            
                            function getBarMod(id) {
                                if (!root.cfg || !root.cfg.allBarModules) return { id: id, name: id, icon: "󰍛" }
                                if (typeof id === "string" && id.indexOf("+") !== -1) {
                                    let parts = id.split("+")
                                    let names = []
                                    let icons = []
                                    for (let p of parts) {
                                        let found = root.cfg.allBarModules.find(x => x.id === p)
                                        if (found) {
                                            names.push(found.name)
                                            icons.push(found.icon)
                                        } else {
                                            names.push(p)
                                            icons.push("󰍛")
                                        }
                                    }
                                    return { id: id, name: names.join(" + "), icon: icons.join(" "), isGroup: true, parts: parts }
                                }
                                for (let i = 0; i < root.cfg.allBarModules.length; i++) {
                                    if (root.cfg.allBarModules[i].id === id) return root.cfg.allBarModules[i]
                                }
                                return { id: id, name: id, icon: "󰍛" }
                            }

                            function getUnusedBarMods() {
                                if (!root.cfg || !root.cfg.allBarModules) return []
                                let left = root.cfg.barModulesLeft || []
                                let center = root.cfg.barModulesCenter || []
                                let right = root.cfg.barModulesRight || []
                                let used = []
                                left.concat(center).concat(right).forEach(m => {
                                    if (typeof m === "string" && m.indexOf("+") !== -1) m.split("+").forEach(x => used.push(x))
                                    else used.push(m)
                                })
                                return root.cfg.allBarModules.filter(m => !used.includes(m.id))
                            }

                            // 1. КАРТОЧКА: ПРЕСЕТЫ И РАСПОЛОЖЕНИЕ (M3 Grouped Card)
                            M3GroupedCard {
                                sectionTitle: "Оформление и позиция"

                                // Пресеты оформления
                                M3SettingsRow {
                                    icon: "󰘖"
                                    title: "Режим отображения бара"
                                    subtitle: "Выбор формы бара без изменения порядка модулей"

                                    M3SegmentedButton {
                                        currentValue: (root.cfg.barStyle === "attached" || root.cfg.barStyle === "bubbles") ? root.cfg.barStyle : "monolith"
                                        model: [
                                            { id: "attached", label: "Прилипающий", icon: "󰁝" },
                                            { id: "monolith", label: "Монолит", icon: "󰛲" },
                                            { id: "bubbles", label: "Островки", icon: "󰘖" }
                                        ]
                                        onSelected: val => {
                                            root.cfg.barStyle = val
                                            root.cfg.barModuleBubbles = (val === "bubbles")
                                            root.cfg.save()
                                        }
                                    }
                                }

                                // Положение панели
                                M3SettingsRow {
                                    icon: "󰁝"
                                    title: "Положение на экране"
                                    subtitle: "Сторона монитора, к которой прикреплена панель"

                                    M3SegmentedButton {
                                        currentValue: root.cfg.barPosition
                                        model: [
                                            { id: "top", label: "Сверху", icon: "󰁝" },
                                            { id: "bottom", label: "Снизу", icon: "󰁅" },
                                            { id: "left", label: "Слева", icon: "󰁍" },
                                            { id: "right", label: "Справа", icon: "󰁔" }
                                        ]
                                        onSelected: val => {
                                            root.cfg.barPosition = val
                                            root.cfg.save()
                                        }
                                    }
                                }

                                // Капсульный фон модулей
                                M3SettingsRow {
                                    icon: "󰝤"
                                    title: "Капсульный фон модулей"
                                    subtitle: "Каждый модуль оборачивается в парящий островок-капсулу"

                                    M3Switch {
                                        checked: root.cfg.barModuleBubbles
                                        activeTrackColor: root.cfg.accent
                                        activeThumbColor: root.cfg.accentText
                                        onToggled: val => {
                                            root.cfg.barModuleBubbles = val
                                            root.cfg.save()
                                        }
                                    }
                                }

                                // Окантовка бара
                                M3SettingsRow {
                                    icon: "󰄲"
                                    title: "Окантовка бара"
                                    subtitle: "Тонкая линия границы вокруг формы бара"

                                    M3Switch {
                                        checked: root.cfg.barBorder !== false
                                        activeTrackColor: root.cfg.accent
                                        activeThumbColor: root.cfg.accentText
                                        onToggled: val => {
                                            root.cfg.barBorder = val
                                            root.cfg.save()
                                        }
                                    }
                                }

                                // Высота панели
                                M3SettingsRow {
                                    icon: "󰤻"
                                    title: "Высота панели"
                                    subtitle: "Толщина бара: " + root.cfg.barHeight + " px"
                                    showDivider: false

                                    RowLayout {
                                        spacing: 8
                                        Rectangle {
                                            height: 32; width: 32; radius: 16
                                            color: root.cfg.surfaceContainerHighest || "#353842"
                                            Text { anchors.centerIn: parent; text: "−"; color: root.cfg.textPrimary; font.bold: true; font.pixelSize: 14 }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.cfg.barHeight = Math.max(26, root.cfg.barHeight - 2); root.cfg.save() }
                                            }
                                        }
                                        Rectangle {
                                            height: 32; width: 68; radius: 16
                                            color: root.cfg.surfaceContainerLowest || "#181a20"
                                            border.color: root.cfg.outlineVariant || "#323540"; border.width: 1
                                            Text { anchors.centerIn: parent; text: root.cfg.barHeight + " px"; color: root.cfg.accent; font.bold: true; font.pixelSize: 11; font.family: "Fredoka" }
                                        }
                                        Rectangle {
                                            height: 32; width: 32; radius: 16
                                            color: root.cfg.surfaceContainerHighest || "#353842"
                                            Text { anchors.centerIn: parent; text: "+"; color: root.cfg.textPrimary; font.bold: true; font.pixelSize: 14 }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.cfg.barHeight = Math.min(54, root.cfg.barHeight + 2); root.cfg.save() }
                                            }
                                        }
                                    }
                                }
                            }

                            // 3. КАРТОЧКА: МОДУЛИ БАРА (M3 Grouped Card)
                            M3GroupedCard {
                                sectionTitle: "Активные модули бара"

                                ColumnLayout {
                                    id: zoneCol
                                    Layout.fillWidth: true
                                    Layout.margins: 12
                                    spacing: 12

                                    // Выбор зоны для редактирования (M3 Segmented Button)
                                        M3SegmentedButton {
                                            currentValue: barTabCol.currentZone
                                            model: [
                                                { id: "left", label: "Левая зона (" + root.cfg.barModulesLeft.length + ")", icon: "󰁍" },
                                                { id: "center", label: "Центр (" + root.cfg.barModulesCenter.length + ")", icon: "󰁝" },
                                                { id: "right", label: "Правая зона (" + root.cfg.barModulesRight.length + ")", icon: "󰁔" }
                                            ]
                                            onSelected: val => barTabCol.currentZone = val
                                        }

                                        // Список модулей выбранной зоны
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            readonly property var activeZoneList: barTabCol.currentZone === "left"
                                                ? root.cfg.barModulesLeft
                                                : (barTabCol.currentZone === "center" ? root.cfg.barModulesCenter : root.cfg.barModulesRight)

                                            Text {
                                                visible: !parent.activeZoneList || parent.activeZoneList.length === 0
                                                text: "В этой зоне пока нет активных модулей"
                                                color: root.cfg.textMuted
                                                font.pixelSize: 12
                                                font.family: root.cfg.fontFamily
                                                Layout.alignment: Qt.AlignHCenter
                                                Layout.topMargin: 12
                                                Layout.bottomMargin: 12
                                            }

                                            Repeater {
                                                model: barTabCol.currentZone === "left"
                                                    ? root.cfg.barModulesLeft
                                                    : (barTabCol.currentZone === "center" ? root.cfg.barModulesCenter : root.cfg.barModulesRight)
                                                    
                                                Rectangle {
                                                    required property var modelData
                                                    required property int index

                                                    Layout.fillWidth: true
                                                    implicitHeight: 48
                                                    Layout.preferredHeight: 48
                                                    radius: 18
                                                    color: root.cfg.surfaceContainerHigh || "#242730"
                                                    border.color: root.cfg.outlineVariant || "#323540"
                                                    border.width: 1

                                                    readonly property var modInfo: barTabCol.getBarMod(modelData)

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 12
                                                        anchors.rightMargin: 12
                                                        spacing: 10

                                                        // Squircle Icon Badge
                                                        Rectangle {
                                                            width: 32; height: 32; radius: 10
                                                            color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                                                            Text { anchors.centerIn: parent; text: modInfo.icon; color: root.cfg.accent; font.pixelSize: 14 }
                                                        }

                                                        // Name
                                                        Text {
                                                            text: modInfo.name
                                                            color: root.cfg.textPrimary
                                                            font.pixelSize: 12
                                                            font.bold: true
                                                            font.family: root.cfg.fontFamily
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }

                                                        // Разделение группы (если сгруппирован)
                                                        Rectangle {
                                                            visible: !!modInfo.isGroup
                                                            width: 28; height: 28; radius: 14
                                                            color: spltBtnM.containsMouse ? root.cfg.accent : (root.cfg.surfaceContainerHighest || "#353842")
                                                            Text { anchors.centerIn: parent; text: "✂"; color: spltBtnM.containsMouse ? root.cfg.accentText : root.cfg.accent; font.pixelSize: 11 }
                                                            MouseArea {
                                                                id: spltBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.cfg.splitBarModule(barTabCol.currentZone, index)
                                                            }
                                                        }

                                                        // Объединение с следующим (группировка в один остров)
                                                        Rectangle {
                                                            visible: index < currentList.length - 1
                                                            width: 28; height: 28; radius: 14
                                                            color: combBtnM.containsMouse ? root.cfg.accent : (root.cfg.surfaceContainerHighest || "#353842")
                                                            Text { anchors.centerIn: parent; text: "🔗"; color: combBtnM.containsMouse ? root.cfg.accentText : root.cfg.accent; font.pixelSize: 11 }
                                                            MouseArea {
                                                                id: combBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.cfg.combineBarModules(barTabCol.currentZone, index)
                                                            }
                                                        }

                                                        // Переместить влево / вверх
                                                        Rectangle {
                                                            width: 28; height: 28; radius: 14
                                                            color: mvUpM.containsMouse ? (root.cfg.surfaceContainerHighest || "#353842") : "transparent"
                                                            opacity: index > 0 ? 1 : 0.3
                                                            Text { anchors.centerIn: parent; text: "󰁝"; color: root.cfg.textPrimary; font.pixelSize: 13 }
                                                            MouseArea {
                                                                id: mvUpM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                onClicked: { if (index > 0) root.cfg.reorderBarModule(barTabCol.currentZone, index, -1) }
                                                            }
                                                        }

                                                        // Переместить вправо / вниз
                                                        Rectangle {
                                                            width: 28; height: 28; radius: 14
                                                            color: mvDnM.containsMouse ? (root.cfg.surfaceContainerHighest || "#353842") : "transparent"
                                                            opacity: index < currentList.length - 1 ? 1 : 0.3
                                                            Text { anchors.centerIn: parent; text: "󰁅"; color: root.cfg.textPrimary; font.pixelSize: 13 }
                                                            MouseArea {
                                                                id: mvDnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                onClicked: { if (index < currentList.length - 1) root.cfg.reorderBarModule(barTabCol.currentZone, index, 1) }
                                                            }
                                                        }

                                                        // Удалить модуль
                                                        Rectangle {
                                                            width: 28; height: 28; radius: 14
                                                            color: delBtnM.containsMouse ? Qt.rgba(root.cfg.danger.r, root.cfg.danger.g, root.cfg.danger.b, 0.20) : "transparent"
                                                            Text { anchors.centerIn: parent; text: "󰅖"; color: delBtnM.containsMouse ? root.cfg.danger : root.cfg.textMuted; font.pixelSize: 13 }
                                                            MouseArea {
                                                                id: delBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.cfg.removeBarModule(modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Разделитель
                                        Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.outlineVariant || "#323540"; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                                        // Добавление неиспользуемых модулей (Material Action Chips)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                text: "Добавить доступный модуль в эту зону:"
                                                color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                                                font.pixelSize: 11
                                                font.bold: true
                                                font.family: root.cfg.fontFamily
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Repeater {
                                                    model: barTabCol.getUnusedBarMods()

                                                    Rectangle {
                                                        required property var modelData
                                                        height: 34
                                                        implicitWidth: chipTxt.implicitWidth + 30
                                                        radius: 17
                                                        color: chipM.containsMouse ? root.cfg.accent : (root.cfg.surfaceContainerHighest || "#2d303a")
                                                        scale: chipM.pressed ? 0.94 : 1.0
                                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                                        Behavior on color { ColorAnimation { duration: 150 } }

                                                        RowLayout {
                                                            id: chipTxt
                                                            anchors.centerIn: parent
                                                            spacing: 6

                                                            Text {
                                                                text: "+ " + (modelData.icon || "󰍛")
                                                                color: chipM.containsMouse ? root.cfg.accentText : root.cfg.accent
                                                                font.pixelSize: 12
                                                            }
                                                            Text {
                                                                text: modelData.name
                                                                color: chipM.containsMouse ? root.cfg.accentText : root.cfg.textPrimary
                                                                font.pixelSize: 11
                                                                font.bold: true
                                                                font.family: root.cfg.fontFamily
                                                            }
                                                        }

                                                        MouseArea {
                                                            id: chipM
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.cfg.addBarModule(barTabCol.currentZone, modelData.id)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                            Item { Layout.fillHeight: true }
                        }

                        // ================= ВКЛАДКА 2: ДОК-БАР =================
                        ColumnLayout {
                            id: dockTabCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 14
                            visible: root.tab === "dock"

                            Text {
                                text: "Параметры дока"
                                color: root.cfg.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 14
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1
                                implicitHeight: dockSettingsCol.implicitHeight

                                ColumnLayout {
                                    id: dockSettingsCol
                                    anchors.fill: parent
                                    spacing: 0

                                    // Включить док-бар
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "󰀻"; color: root.cfg.accent; font.pixelSize: 15 }
                                            Text {
                                                text: "Отображать док-бар"
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: root.cfg.fontFamily
                                                Layout.fillWidth: true
                                            }

                                            M3Switch {
                                                checked: root.cfg.dockEnabled
                                                activeTrackColor: root.cfg.accent
                                                activeThumbColor: root.cfg.accentText
                                                onToggled: val => { root.cfg.dockEnabled = val; root.cfg.save() }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol; Layout.leftMargin: 14; Layout.rightMargin: 14 }

                                    // Автоскрытие
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "󰍜"; color: root.cfg.textMuted; font.pixelSize: 15 }
                                            Text {
                                                text: "Автоскрытие"
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: root.cfg.fontFamily
                                                Layout.fillWidth: true
                                            }

                                            M3Switch {
                                                checked: root.cfg.dockAutohide
                                                activeTrackColor: root.cfg.accent
                                                activeThumbColor: root.cfg.accentText
                                                onToggled: val => { root.cfg.dockAutohide = val; root.cfg.save() }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol; Layout.leftMargin: 14; Layout.rightMargin: 14 }

                                    // Размер иконок
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "󰏘"; color: root.cfg.textMuted; font.pixelSize: 15 }
                                            Text {
                                                text: "Размер иконок"
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: root.cfg.fontFamily
                                                Layout.fillWidth: true
                                            }

                                            RowLayout {
                                                spacing: 4
                                                Repeater {
                                                    model: [
                                                        { label: "36 px", size: 36 },
                                                        { label: "42 px", size: 42 },
                                                        { label: "48 px", size: 48 }
                                                    ]
                                                    Rectangle {
                                                        required property var modelData
                                                        height: 28
                                                        implicitWidth: szTxt.implicitWidth + 16
                                                        radius: 14
                                                        color: (root.cfg.dockIconSize === modelData.size) ? root.cfg.accent : root.cfg.bgSurface
                                                        border.color: root.cfg.borderCol
                                                        border.width: 1

                                                        Text {
                                                            id: szTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.label
                                                            color: (root.cfg.dockIconSize === modelData.size) ? root.cfg.accentText : root.cfg.textPrimary
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: { root.cfg.dockIconSize = modelData.size; root.cfg.save() }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Закрепленные приложения"
                                color: root.cfg.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                font.family: root.cfg.fontFamily
                                Layout.topMargin: 4
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 14
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1
                                implicitHeight: pinnedCardCol.implicitHeight + 24

                                ColumnLayout {
                                    id: pinnedCardCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    // Список закрепленных приложений
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: root.cfg.dockPinnedApps || []

                                            Rectangle {
                                                required property string modelData
                                                height: 30
                                                implicitWidth: chipRow.implicitWidth + 14
                                                radius: 15
                                                color: root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1

                                                RowLayout {
                                                    id: chipRow
                                                    anchors.centerIn: parent
                                                    spacing: 6

                                                    Text { text: "󰀻"; color: root.cfg.accent; font.pixelSize: 12 }
                                                    Text {
                                                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                                        color: root.cfg.textPrimary
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                    }

                                                    Rectangle {
                                                        width: 16; height: 16; radius: 8
                                                        color: delChipM.containsMouse ? root.cfg.danger : Qt.rgba(255, 255, 255, 0.08)

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "✕"
                                                            color: delChipM.containsMouse ? "#ffffff" : root.cfg.textMuted
                                                            font.pixelSize: 8
                                                        }

                                                        MouseArea {
                                                            id: delChipM
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: root.cfg.unpinAppFromDock(modelData)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol }

                                    Text { text: "Быстро добавить:"; color: root.cfg.textMuted; font.pixelSize: 11; font.bold: true }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: [
                                                { id: "firefox", name: "+ Firefox" },
                                                { id: "kitty", name: "+ Kitty" },
                                                { id: "alacritty", name: "+ Alacritty" },
                                                { id: "thunar", name: "+ Файлы" },
                                                { id: "vesktop", name: "+ Discord" },
                                                { id: "telegram", name: "+ Telegram" },
                                                { id: "steam", name: "+ Steam" }
                                            ]

                                            Rectangle {
                                                required property var modelData
                                                readonly property bool alreadyPinned: root.cfg.isAppPinned(modelData.id)
                                                visible: !alreadyPinned
                                                height: 26
                                                implicitWidth: addAppTxt.implicitWidth + 14
                                                radius: 13
                                                color: addAppM.containsMouse ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1

                                                Text {
                                                    id: addAppTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.name
                                                    color: addAppM.containsMouse ? root.cfg.accentText : root.cfg.textPrimary
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: addAppM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.cfg.pinAppToDock(modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }

                        // ================= ВКЛАДКА 3: ВИДЖЕТЫ СТОЛА =================
                        ColumnLayout {
                            id: widgetsTabCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 12
                            visible: root.tab === "widgets"

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Виджеты рабочего стола"
                                    color: root.cfg.textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: root.cfg.fontFamily
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    height: 30
                                    implicitWidth: openWEdTxt.implicitWidth + 24
                                    radius: 15
                                    color: root.cfg.accent

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰆣"; color: root.cfg.accentText; font.pixelSize: 12 }
                                        Text {
                                            id: openWEdTxt
                                            text: "Расставить на экране"
                                            color: root.cfg.accentText
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.closeRequested()
                                            root.requestWidgetEditor("widgets")
                                        }
                                    }
                                }
                            }

                            // Отображать виджеты
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 12
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 14

                                    Text { text: "Отображать виджеты на рабочем столе"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }

                                    M3Switch {
                                        checked: root.cfg.showDesktopWidgets
                                        activeTrackColor: root.cfg.accent
                                        activeThumbColor: root.cfg.accentText
                                        onToggled: val => { root.cfg.showDesktopWidgets = val; root.cfg.save() }
                                    }
                                }
                            }

                            // Общее скругление виджетов
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: 12
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 14

                                    ColumnLayout {
                                        spacing: 2
                                        Layout.fillWidth: true
                                        Text { text: "Скругление углов по умолчанию"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true }
                                        Text { text: "Индивидуально настраивается в предпросмотре у каждого виджета"; color: root.cfg.textMuted; font.pixelSize: 10 }
                                    }

                                    RowLayout {
                                        spacing: 4
                                        Repeater {
                                            model: [
                                                { label: "0", val: 0 },
                                                { label: "12", val: 12 },
                                                { label: "20", val: 20 },
                                                { label: "28", val: 28 },
                                                { label: "36", val: 36 }
                                            ]

                                            Rectangle {
                                                required property var modelData
                                                width: 30
                                                height: 26
                                                radius: 13
                                                readonly property bool isCur: (root.cfg.widgetRadius || 28) === modelData.val
                                                color: isCur ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: isCur ? root.cfg.accent : root.cfg.borderCol
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: isCur ? root.cfg.accentText : root.cfg.textPrimary
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.cfg.setAllWidgetsRadius(modelData.val)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Добавить виджет
                            Rectangle {
                                Layout.fillWidth: true
                                radius: 20
                                color: root.cfg.surfaceContainer
                                border.color: root.cfg.borderCol
                                border.width: 1
                                implicitHeight: addWCol.implicitHeight + 20

                                ColumnLayout {
                                    id: addWCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text { text: "Добавить виджет:"; color: root.cfg.textMuted; font.pixelSize: 11; font.bold: true }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: [
                                                { type: "clock", label: "󰥔 Часы" },
                                                { type: "weather", label: "󰖐 Погода" },
                                                { type: "vitals", label: "󰍛 Ресурсы" },
                                                { type: "player", label: "󰎆 Плеер" },
                                                { type: "calendar", label: "󰸗 Календарь" },
                                                { type: "notes", label: "󰏫 Заметки" },
                                                { type: "storage", label: "󰋊 Диск" }
                                            ]

                                            Rectangle {
                                                height: 30
                                                implicitWidth: qAddTxt.implicitWidth + 20
                                                radius: 15
                                                color: qAddM.containsMouse ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1

                                                Text {
                                                    id: qAddTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: qAddM.containsMouse ? root.cfg.accentText : root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: qAddM
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.cfg.addWidget(modelData.type, 140, 140)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Список активных виджетов
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Активные виджеты (" + root.cfg.desktopWidgets.length + "):"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                                Rectangle {
                                    height: 24; implicitWidth: 80; radius: 12
                                    color: root.cfg.bgElevated
                                    border.color: root.cfg.borderCol
                                    border.width: 1
                                    Text { anchors.centerIn: parent; text: "Сброс"; color: root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.cfg.desktopWidgets = [
                                                { id: "clock-1", type: "clock", x: 60, y: 70, w: 260, h: 140, visible: true },
                                                { id: "weather-1", type: "weather", x: 340, y: 70, w: 220, h: 140, visible: true },
                                                { id: "vitals-1", type: "vitals", x: 60, y: 230, w: 320, h: 120, visible: true },
                                                { id: "player-1", type: "player", x: 400, y: 230, w: 360, h: 140, visible: true }
                                            ]
                                            root.cfg.save()
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: root.cfg.desktopWidgets
                                    delegate: Rectangle {
                                        id: wCardItem
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        implicitHeight: wCardCol.implicitHeight + 16
                                        radius: 12
                                        color: root.cfg.bgElevated
                                        border.color: root.cfg.borderCol
                                        border.width: 1

                                        ColumnLayout {
                                            id: wCardCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 10
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    text: {
                                                        let t = wCardItem.modelData.type
                                                        if (t === "clock") return "󰥔"
                                                        if (t === "weather") return "󰖐"
                                                        if (t === "vitals") return "󰍛"
                                                        if (t === "player") return "󰎆"
                                                        if (t === "calendar") return "󰸗"
                                                        if (t === "notes") return "󰏫"
                                                        if (t === "storage") return "󰋊"
                                                        return "󰕰"
                                                    }
                                                    color: root.cfg.accent
                                                    font.pixelSize: 14
                                                }

                                                Text {
                                                    text: {
                                                        let t = wCardItem.modelData.type
                                                        if (t === "clock") return "Часы и дата"
                                                        if (t === "weather") return "Погода"
                                                        if (t === "vitals") return "Ресурсы"
                                                        if (t === "player") return "Медиаплеер"
                                                        if (t === "calendar") return "Календарь"
                                                        if (t === "notes") return "Заметки"
                                                        if (t === "storage") return "Диск"
                                                        return t
                                                    }
                                                    color: root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    Layout.fillWidth: true
                                                }

                                                // Кнопка смены вида
                                                Rectangle {
                                                    height: 24
                                                    implicitWidth: varBtnTxt.implicitWidth + 14
                                                    radius: 12
                                                    color: root.cfg.bgSurface
                                                    border.color: root.cfg.borderCol
                                                    border.width: 1

                                                    Text {
                                                        id: varBtnTxt
                                                        anchors.centerIn: parent
                                                        text: "Вид: " + (wCardItem.modelData.variant || "стандарт")
                                                        color: root.cfg.accent
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.cfg.cycleWidgetVariant(wCardItem.modelData.id)
                                                    }
                                                }

                                                // Кнопка удаления
                                                Rectangle {
                                                    width: 24; height: 24; radius: 12
                                                    color: delBtnM.containsMouse ? root.cfg.danger : root.cfg.bgSurface
                                                    border.color: root.cfg.borderCol
                                                    border.width: 1
                                                    Text { anchors.centerIn: parent; text: "✕"; color: delBtnM.containsMouse ? "#ffffff" : root.cfg.textMuted; font.pixelSize: 9 }
                                                    MouseArea {
                                                        id: delBtnM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.cfg.removeWidget(wCardItem.modelData.id)
                                                    }
                                                }
                                            }

                                            // Выбор цвета для часов
                                            RowLayout {
                                                visible: wCardItem.modelData.type === "clock"
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text { text: "Цвет:"; color: root.cfg.textMuted; font.pixelSize: 10 }

                                                Repeater {
                                                    model: ["theme", "#ffffff", "#a8c7fa", "#d0bcff", "#a6e3a1", "#ffb4a2", "#fabd2f", "#f38ba8"]
                                                    Rectangle {
                                                        required property string modelData
                                                        width: 18; height: 18; radius: 9
                                                        color: modelData === "theme" ? root.cfg.accent : modelData
                                                        border.color: (wCardItem.modelData.clockColor || "theme") === modelData ? "#ffffff" : "transparent"
                                                        border.width: 1.5

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.cfg.setWidgetProperty(wCardItem.modelData.id, "clockColor", modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }

                        // ================= ВКЛАДКА 4: ШТОРКА УПРАВЛЕНИЯ =================
                        ColumnLayout {
                            id: sideTabCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 16
                            visible: root.tab === "side"

                            function getSideSec(id) {
                                if (!root.cfg || !root.cfg.allSideSections) return { id: id, name: id, icon: "󰕮" }
                                for (let i = 0; i < root.cfg.allSideSections.length; i++) {
                                    if (root.cfg.allSideSections[i].id === id) return root.cfg.allSideSections[i]
                                }
                                return { id: id, name: id, icon: "󰕮" }
                            }

                            function getUnusedSideSecs() {
                                if (!root.cfg || !root.cfg.allSideSections) return []
                                let active = root.cfg.sidePanelOrder || []
                                return root.cfg.allSideSections.filter(s => !active.includes(s.id))
                            }

                            // 1. ЗАГОЛОВОК СТРАНИЦЫ
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Text {
                                        text: "Шторка быстрых настроек"
                                        color: root.cfg.textPrimary
                                        font.pixelSize: 20
                                        font.bold: true
                                        font.family: root.cfg.fontFamily
                                    }
                                    Text {
                                        text: "Управление структурой, порядком блоков и внешним видом панели управления"
                                        color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                                        font.pixelSize: 12
                                        font.family: root.cfg.fontFamily
                                    }
                                }

                                Rectangle {
                                    height: 36
                                    implicitWidth: liveSideBtnTxt.implicitWidth + 24
                                    radius: 18
                                    color: root.cfg.accent
                                    scale: liveSideBtnM.pressed ? 0.94 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰍹"; color: root.cfg.accentText; font.pixelSize: 13 }
                                        Text {
                                            id: liveSideBtnTxt
                                            text: "Открыть шторку"
                                            color: root.cfg.accentText
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: root.cfg.fontFamily
                                        }
                                    }

                                    MouseArea {
                                        id: liveSideBtnM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.closeRequested()
                                            settingsSysProc.command = ["quickshell", "ipc", "call", "shell", "toggleSide"]
                                            settingsSysProc.running = true
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 36
                                    implicitWidth: 84
                                    radius: 18
                                    color: resetSideM.containsMouse ? (root.cfg.surfaceContainerHighest || "#353842") : (root.cfg.surfaceContainer || "#22252c")
                                    border.color: root.cfg.outlineVariant || "#323540"
                                    border.width: 1
                                    scale: resetSideM.pressed ? 0.94 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰑐"; color: root.cfg.textMuted; font.pixelSize: 12 }
                                        Text {
                                            text: "Сброс"
                                            color: root.cfg.textPrimary
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: root.cfg.fontFamily
                                        }
                                    }

                                    MouseArea {
                                        id: resetSideM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.cfg.sidePanelOrder = ["tiles", "sliders", "gauges", "media", "notifications", "power"]
                                            root.cfg.sideShowHero = true
                                            root.cfg.save()
                                        }
                                    }
                                }
                            }

                            // 2. КАРТОЧКА: ВИДИМОСТЬ И СТРУКТУРА ШТОРКИ
                            M3GroupedCard {
                                sectionTitle: "Блоки и секции шторки"

                                // Шапка профиля и часы
                                M3SettingsRow {
                                    icon: "󰀉"
                                    title: "Шапка At-a-Glance"
                                    subtitle: "Крупные часы, погода, профиль и быстрые кнопки"

                                    M3Switch {
                                        checked: root.cfg.sideShowHero
                                        activeTrackColor: root.cfg.accent
                                        activeThumbColor: root.cfg.accentText
                                        onToggled: val => {
                                            root.cfg.sideShowHero = val
                                            root.cfg.save()
                                        }
                                    }
                                }

                                // Порядок активных секций
                                ColumnLayout {
                                    id: actSecCol
                                    Layout.fillWidth: true
                                    Layout.margins: 12
                                    spacing: 8

                                        Text {
                                            text: "Порядок отображения активных секций:"
                                            color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: root.cfg.fontFamily
                                        }

                                        Repeater {
                                            model: root.cfg.sidePanelOrder

                                            Rectangle {
                                                required property var modelData
                                                required property int index

                                                Layout.fillWidth: true
                                                implicitHeight: 48
                                                Layout.preferredHeight: 48
                                                radius: 18
                                                color: root.cfg.surfaceContainerHigh || "#242730"
                                                border.color: root.cfg.outlineVariant || "#323540"
                                                border.width: 1

                                                readonly property var secInfo: sideTabCol.getSideSec(modelData)

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    spacing: 10

                                                    Rectangle {
                                                        width: 32; height: 32; radius: 10
                                                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                                                        Text { anchors.centerIn: parent; text: secInfo.icon; color: root.cfg.accent; font.pixelSize: 14 }
                                                    }

                                                    Text {
                                                        text: secInfo.name
                                                        color: root.cfg.textPrimary
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        font.family: root.cfg.fontFamily
                                                        Layout.fillWidth: true
                                                    }

                                                    // Переместить вверх
                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: mvSecUpM.containsMouse ? (root.cfg.surfaceContainerHighest || "#353842") : "transparent"
                                                        opacity: index > 0 ? 1 : 0.3
                                                        Text { anchors.centerIn: parent; text: "󰁝"; color: root.cfg.textPrimary; font.pixelSize: 13 }
                                                        MouseArea {
                                                            id: mvSecUpM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (index > 0) {
                                                                    let order = root.cfg.sidePanelOrder.slice()
                                                                    let tmp = order[index]
                                                                    order[index] = order[index - 1]
                                                                    order[index - 1] = tmp
                                                                    root.cfg.sidePanelOrder = order
                                                                    root.cfg.save()
                                                                }
                                                            }
                                                        }
                                                    }

                                                    // Переместить вниз
                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: mvSecDnM.containsMouse ? (root.cfg.surfaceContainerHighest || "#353842") : "transparent"
                                                        opacity: index < root.cfg.sidePanelOrder.length - 1 ? 1 : 0.3
                                                        Text { anchors.centerIn: parent; text: "󰁅"; color: root.cfg.textPrimary; font.pixelSize: 13 }
                                                        MouseArea {
                                                            id: mvSecDnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (index < root.cfg.sidePanelOrder.length - 1) {
                                                                    let order = root.cfg.sidePanelOrder.slice()
                                                                    let tmp = order[index]
                                                                    order[index] = order[index + 1]
                                                                    order[index + 1] = tmp
                                                                    root.cfg.sidePanelOrder = order
                                                                    root.cfg.save()
                                                                }
                                                            }
                                                        }
                                                    }

                                                    // Скрыть секцию
                                                    Rectangle {
                                                        width: 28; height: 28; radius: 14
                                                        color: hideSecM.containsMouse ? Qt.rgba(root.cfg.danger.r, root.cfg.danger.g, root.cfg.danger.b, 0.20) : "transparent"
                                                        Text { anchors.centerIn: parent; text: "󰅖"; color: hideSecM.containsMouse ? root.cfg.danger : root.cfg.textMuted; font.pixelSize: 13 }
                                                        MouseArea {
                                                            id: hideSecM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                let order = root.cfg.sidePanelOrder.filter(s => s !== modelData)
                                                                root.cfg.sidePanelOrder = order
                                                                root.cfg.save()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Добавить скрытые секции
                                        ColumnLayout {
                                            visible: sideTabCol.getUnusedSideSecs().length > 0
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Layout.topMargin: 4

                                            Text {
                                                text: "Скрытые секции (нажмите, чтобы включить):"
                                                color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                                                font.pixelSize: 11
                                                font.family: root.cfg.fontFamily
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Repeater {
                                                    model: sideTabCol.getUnusedSideSecs()

                                                    Rectangle {
                                                        required property var modelData
                                                        height: 34
                                                        implicitWidth: addSecTxt.implicitWidth + 30
                                                        radius: 17
                                                        color: addSecM.containsMouse ? root.cfg.accent : (root.cfg.surfaceContainerHighest || "#2d303a")
                                                        scale: addSecM.pressed ? 0.94 : 1.0
                                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                                        Behavior on color { ColorAnimation { duration: 150 } }

                                                        RowLayout {
                                                            id: addSecTxt
                                                            anchors.centerIn: parent
                                                            spacing: 6
                                                            Text { text: "+ " + (modelData.icon || "󰕮"); color: addSecM.containsMouse ? root.cfg.accentText : root.cfg.accent; font.pixelSize: 12 }
                                                            Text { text: modelData.name; color: addSecM.containsMouse ? root.cfg.accentText : root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                                                        }

                                                        MouseArea {
                                                            id: addSecM
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                let order = root.cfg.sidePanelOrder.slice()
                                                                order.push(modelData.id)
                                                                root.cfg.sidePanelOrder = order
                                                                root.cfg.save()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                            // 3. КАРТОЧКА: ГЕОМЕТРИЯ И АНИМАЦИЯ
                            M3GroupedCard {
                                sectionTitle: "Геометрия и стиль"

                                M3SettingsRow {
                                    icon: "󰍜"
                                    title: "Ширина шторки"
                                    subtitle: "Текущая ширина: " + root.cfg.sidePanelWidth + " px"

                                    RowLayout {
                                        spacing: 8
                                        Rectangle {
                                            height: 32; width: 32; radius: 16
                                            color: root.cfg.surfaceContainerHighest || "#353842"
                                            Text { anchors.centerIn: parent; text: "−"; color: root.cfg.textPrimary; font.bold: true; font.pixelSize: 14 }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.cfg.sidePanelWidth = Math.max(340, root.cfg.sidePanelWidth - 20); root.cfg.save() }
                                            }
                                        }
                                        Rectangle {
                                            height: 32; width: 68; radius: 16
                                            color: root.cfg.surfaceContainerLowest || "#181a20"
                                            border.color: root.cfg.outlineVariant || "#323540"; border.width: 1
                                            Text { anchors.centerIn: parent; text: root.cfg.sidePanelWidth + " px"; color: root.cfg.accent; font.bold: true; font.pixelSize: 11; font.family: "Fredoka" }
                                        }
                                        Rectangle {
                                            height: 32; width: 32; radius: 16
                                            color: root.cfg.surfaceContainerHighest || "#353842"
                                            Text { anchors.centerIn: parent; text: "+"; color: root.cfg.textPrimary; font.bold: true; font.pixelSize: 14 }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.cfg.sidePanelWidth = Math.min(500, root.cfg.sidePanelWidth + 20); root.cfg.save() }
                                            }
                                        }
                                    }
                                }

                                M3SettingsRow {
                                    icon: "󰎆"
                                    title: "Стиль прогресса плеера"
                                    subtitle: "Форма линии трека в карточке мультимедиа"
                                    showDivider: false

                                    M3SegmentedButton {
                                        currentValue: root.cfg.playerProgressStyle || "squiggly"
                                        model: [
                                            { id: "squiggly", label: "Живая волна (M3)", icon: "󰐊" },
                                            { id: "flat", label: "Прямая линия", icon: "󰁅" }
                                        ]
                                        onSelected: val => {
                                            root.cfg.playerProgressStyle = val
                                            root.cfg.save()
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }

                        // ================= ВКЛАДКА 5: ТЕМЫ =================
                        ColumnLayout {
                            id: themesTabCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 16
                            visible: root.tab === "themes"

                            // 1. ГОТОВЫЕ ЦВЕТОВЫЕ ТЕМЫ (24 ПАЛИТРЫ)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Готовые темы оформления"
                                        color: root.cfg.textPrimary
                                        font.pixelSize: 13
                                        font.bold: true
                                        font.family: root.cfg.fontFamily
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: "24 палитры"
                                        color: root.cfg.textMuted
                                        font.pixelSize: 11
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 6
                                    columnSpacing: 6

                                    Repeater {
                                        model: [
                                            { id: "Monet Blue", color: "#a8c7fa" },
                                            { id: "Pixel Lavender", color: "#d0bcff" },
                                            { id: "Emerald Mint", color: "#a6e3a1" },
                                            { id: "Graphite White", color: "#c8ccd8" },
                                            { id: "AMOLED Peach", color: "#ffb4a2" },
                                            { id: "Nordic Slate", color: "#88c0d0" },
                                            { id: "Sunset Terracotta", color: "#e07a5f" },
                                            { id: "Cyberpunk Cyan", color: "#00f0ff" },
                                            { id: "Tokyo Night", color: "#7aa2f7" },
                                            { id: "Rose Gold Pine", color: "#ebbcba" },
                                            { id: "Gruvbox Amber", color: "#fabd2f" },
                                            { id: "Catppuccin Mocha", color: "#cba6f7" },
                                            { id: "Catppuccin Macchiato", color: "#8aadf4" },
                                            { id: "Dracula Purple", color: "#bd93f9" },
                                            { id: "Sakura Blossom", color: "#f5bde6" },
                                            { id: "Synthwave Neon", color: "#ff2a85" },
                                            { id: "Crimson Ruby", color: "#ff5555" },
                                            { id: "Electric Violet", color: "#a855f7" },
                                            { id: "Matcha Forest", color: "#859900" },
                                            { id: "Sunburst Gold", color: "#facc15" },
                                            { id: "Solarized Cyan", color: "#2aa198" },
                                            { id: "One Dark Pro", color: "#61afef" },
                                            { id: "Monokai Pro", color: "#ffd866" },
                                            { id: "Deep Abyss", color: "#2dd4bf" }
                                        ]

                                        Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            radius: 10
                                            color: root.cfg.currentTheme === modelData.id ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.15) : root.cfg.bgElevated
                                            border.color: root.cfg.currentTheme === modelData.id ? root.cfg.accent : root.cfg.borderCol
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 8

                                                Rectangle {
                                                    Layout.preferredWidth: 14
                                                    Layout.preferredHeight: 14
                                                    radius: 7
                                                    color: modelData.color
                                                    border.color: Qt.rgba(1, 1, 1, 0.2)
                                                    border.width: 1
                                                }

                                                Text {
                                                    text: modelData.id
                                                    color: root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    font.bold: root.cfg.currentTheme === modelData.id
                                                    font.family: root.cfg.fontFamily
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    visible: root.cfg.currentTheme === modelData.id
                                                    text: "✓"
                                                    color: root.cfg.accent
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.cfg.applyTheme(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. СОХРАНЁННЫЕ ПОЛЬЗОВАТЕЛЬСКИЕ ТЕМЫ
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: root.cfg.customThemes && root.cfg.customThemes.length > 0

                                Text {
                                    text: "Ваши собственные темы"
                                    color: root.cfg.textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: root.cfg.fontFamily
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 6
                                    columnSpacing: 6

                                    Repeater {
                                        model: root.cfg.customThemes
                                        Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            radius: 10
                                            color: root.cfg.currentTheme === modelData.name ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.15) : root.cfg.bgElevated
                                            border.color: root.cfg.currentTheme === modelData.name ? root.cfg.accent : root.cfg.borderCol
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 6
                                                spacing: 8

                                                Rectangle {
                                                    Layout.preferredWidth: 14
                                                    Layout.preferredHeight: 14
                                                    radius: 7
                                                    color: modelData.accent
                                                    border.color: Qt.rgba(1, 1, 1, 0.2)
                                                    border.width: 1
                                                }

                                                Text {
                                                    text: modelData.name
                                                    color: root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    font.bold: root.cfg.currentTheme === modelData.name
                                                    font.family: root.cfg.fontFamily
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    visible: root.cfg.currentTheme === modelData.name
                                                    text: "✓"
                                                    color: root.cfg.accent
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }

                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    radius: 12
                                                    color: delCustomM.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.25) : "transparent"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "✕"
                                                        color: delCustomM.containsMouse ? (root.cfg.danger || "#ef4444") : root.cfg.textMuted
                                                        font.pixelSize: 10
                                                    }
                                                    MouseArea {
                                                        id: delCustomM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.cfg.removeCustomTheme(modelData.name)
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.rightMargin: 30
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.cfg.applyCustomTheme(modelData.name)
                                            }
                                        }
                                    }
                                }
                            }

                            // 3. СТУДИЯ КАСТОМИЗАЦИИ С ПОЛНОЙ RGB НАСТРОЙКОЙ
                            Rectangle {
                                id: customStudioCard
                                Layout.fillWidth: true
                                radius: 14
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1
                                implicitHeight: studioCol.implicitHeight + 28

                                property int redVal: 255
                                property int greenVal: 42
                                property int blueVal: 133
                                property string currentHex: "#ff2a85"
                                property int selectedToneIdx: 1
                                property bool updatingInternally: false

                                function syncRgbToHex() {
                                    if (updatingInternally) return
                                    updatingInternally = true
                                    let rH = Math.max(0, Math.min(255, redVal)).toString(16)
                                    let gH = Math.max(0, Math.min(255, greenVal)).toString(16)
                                    let bH = Math.max(0, Math.min(255, blueVal)).toString(16)
                                    if (rH.length < 2) rH = "0" + rH
                                    if (gH.length < 2) gH = "0" + gH
                                    if (bH.length < 2) bH = "0" + bH
                                    currentHex = "#" + rH + gH + bH
                                    hexInput.text = currentHex
                                    updatingInternally = false
                                }

                                function syncHexToRgb(hText) {
                                    if (updatingInternally) return
                                    let clean = hText.replace("#", "").trim()
                                    if (clean.length === 3) {
                                        clean = clean[0] + clean[0] + clean[1] + clean[1] + clean[2] + clean[2]
                                    }
                                    if (clean.length === 6) {
                                        let r = parseInt(clean.substring(0, 2), 16)
                                        let g = parseInt(clean.substring(2, 4), 16)
                                        let b = parseInt(clean.substring(4, 6), 16)
                                        if (!isNaN(r) && !isNaN(g) && !isNaN(b)) {
                                            updatingInternally = true
                                            redVal = r
                                            greenVal = g
                                            blueVal = b
                                            currentHex = "#" + clean.toLowerCase()
                                            updatingInternally = false
                                        }
                                    }
                                }

                                ColumnLayout {
                                    id: studioCol
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Создать свою тему (RGB палитра)"
                                            color: root.cfg.textPrimary
                                            font.pixelSize: 13
                                            font.bold: true
                                            font.family: root.cfg.fontFamily
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            height: 22
                                            width: 70
                                            radius: 6
                                            color: Qt.rgba(customStudioCard.redVal/255.0, customStudioCard.greenVal/255.0, customStudioCard.blueVal/255.0, 0.2)
                                            border.color: customStudioCard.currentHex
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: customStudioCard.currentHex.toUpperCase()
                                                color: customStudioCard.currentHex
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }
                                    }

                                    // Живое превью темы
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 52
                                        radius: 10
                                        color: {
                                            if (customStudioCard.selectedToneIdx === 0) return "#0c0d10"
                                            if (customStudioCard.selectedToneIdx === 2) return "#161924"
                                            if (customStudioCard.selectedToneIdx === 3) return "#1e1a19"
                                            return "#1a1c22"
                                        }
                                        border.color: Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 10

                                            // Превью иконки
                                            Rectangle {
                                                width: 32
                                                height: 32
                                                radius: 16
                                                color: customStudioCard.currentHex
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰏘"
                                                    color: "#ffffff"
                                                    font.pixelSize: 14
                                                }
                                            }

                                            // Превью акцентного бейджа
                                            Rectangle {
                                                height: 26
                                                implicitWidth: 84
                                                radius: 13
                                                color: Qt.rgba(customStudioCard.redVal/255.0, customStudioCard.greenVal/255.0, customStudioCard.blueVal/255.0, 0.25)
                                                border.color: customStudioCard.currentHex
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Акцент"
                                                    color: customStudioCard.currentHex
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }

                                            // Превью кнопки
                                            Rectangle {
                                                height: 26
                                                implicitWidth: 90
                                                radius: 8
                                                color: customStudioCard.currentHex
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Кнопка"
                                                    color: (customStudioCard.redVal*0.299 + customStudioCard.greenVal*0.587 + customStudioCard.blueVal*0.114) > 160 ? "#111116" : "#ffffff"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: "Превью стиля"
                                                color: root.cfg.textMuted
                                                font.pixelSize: 10
                                            }
                                        }
                                    }

                                    // Поле названия темы
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: "Название:"
                                            color: root.cfg.textMuted
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 65
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 32
                                            radius: 8
                                            color: root.cfg.bgSurface
                                            border.color: root.cfg.borderCol
                                            border.width: 1

                                            TextInput {
                                                id: customNameInput
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 11
                                                font.family: root.cfg.fontFamily
                                                text: "Мой стиль"
                                            }
                                        }
                                    }

                                    // Выбор базового тона фона
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: "Тон фона:"
                                            color: root.cfg.textMuted
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 65
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: [
                                                    { id: 0, title: "AMOLED", col: "#0c0d10" },
                                                    { id: 1, title: "Material", col: "#1a1c22" },
                                                    { id: 2, title: "Индиго", col: "#161924" },
                                                    { id: 3, title: "Кофе", col: "#1e1a19" }
                                                ]

                                                Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    height: 28
                                                    radius: 8
                                                    color: customStudioCard.selectedToneIdx === modelData.id ? Qt.rgba(customStudioCard.redVal/255.0, customStudioCard.greenVal/255.0, customStudioCard.blueVal/255.0, 0.15) : root.cfg.bgSurface
                                                    border.color: customStudioCard.selectedToneIdx === modelData.id ? customStudioCard.currentHex : root.cfg.borderCol
                                                    border.width: 1

                                                    RowLayout {
                                                        anchors.centerIn: parent
                                                        spacing: 6
                                                        Rectangle {
                                                            width: 10; height: 10; radius: 5
                                                            color: modelData.col
                                                            border.color: Qt.rgba(1, 1, 1, 0.3)
                                                            border.width: 1
                                                        }
                                                        Text {
                                                            text: modelData.title
                                                            color: customStudioCard.selectedToneIdx === modelData.id ? customStudioCard.currentHex : root.cfg.textPrimary
                                                            font.pixelSize: 10
                                                            font.bold: customStudioCard.selectedToneIdx === modelData.id
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: customStudioCard.selectedToneIdx = modelData.id
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Быстрые готовые цвета
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: "Пресеты:"
                                            color: root.cfg.textMuted
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 65
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: ["#ff5555", "#ff7597", "#ff9e64", "#facc15", "#a6e3a1", "#2dd4bf", "#00f0ff", "#7aa2f7", "#a855f7", "#ffffff"]

                                                Rectangle {
                                                    required property string modelData
                                                    Layout.fillWidth: true
                                                    height: 22
                                                    radius: 6
                                                    color: modelData
                                                    border.color: customStudioCard.currentHex === modelData ? "#ffffff" : "transparent"
                                                    border.width: 2

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: customStudioCard.syncHexToRgb(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // RGB ПОЛЗУНКИ
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // Ползунок R (Red)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Text {
                                                text: "R"
                                                color: "#ff5555"
                                                font.pixelSize: 11
                                                font.bold: true
                                                Layout.preferredWidth: 16
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                height: 22

                                                Rectangle {
                                                    id: rTrack
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 8
                                                    radius: 4
                                                    color: Qt.rgba(1, 1, 1, 0.08)

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: Math.max(8, Math.min(rTrack.width, rTrack.width * (customStudioCard.redVal / 255.0)))
                                                        radius: 4
                                                        color: "#ff5555"
                                                    }
                                                }

                                                Rectangle {
                                                    x: Math.max(0, Math.min(rTrack.width - width, (rTrack.width - width) * (customStudioCard.redVal / 255.0)))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 16
                                                    height: 16
                                                    radius: 8
                                                    color: "#ffffff"
                                                    border.color: Qt.rgba(0, 0, 0, 0.4)
                                                    border.width: 1
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    function setVal(mx) {
                                                        let ratio = Math.max(0, Math.min(1.0, mx / width))
                                                        customStudioCard.redVal = Math.round(ratio * 255)
                                                        customStudioCard.syncRgbToHex()
                                                    }
                                                    onPressed: mouse => setVal(mouse.x)
                                                    onPositionChanged: mouse => { if (pressed) setVal(mouse.x) }
                                                }
                                            }

                                            Rectangle {
                                                width: 38
                                                height: 22
                                                radius: 6
                                                color: root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: customStudioCard.redVal.toString()
                                                    color: "#ff5555"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        // Ползунок G (Green)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Text {
                                                text: "G"
                                                color: "#50fa7b"
                                                font.pixelSize: 11
                                                font.bold: true
                                                Layout.preferredWidth: 16
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                height: 22

                                                Rectangle {
                                                    id: gTrack
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 8
                                                    radius: 4
                                                    color: Qt.rgba(1, 1, 1, 0.08)

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: Math.max(8, Math.min(gTrack.width, gTrack.width * (customStudioCard.greenVal / 255.0)))
                                                        radius: 4
                                                        color: "#50fa7b"
                                                    }
                                                }

                                                Rectangle {
                                                    x: Math.max(0, Math.min(gTrack.width - width, (gTrack.width - width) * (customStudioCard.greenVal / 255.0)))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 16
                                                    height: 16
                                                    radius: 8
                                                    color: "#ffffff"
                                                    border.color: Qt.rgba(0, 0, 0, 0.4)
                                                    border.width: 1
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    function setVal(mx) {
                                                        let ratio = Math.max(0, Math.min(1.0, mx / width))
                                                        customStudioCard.greenVal = Math.round(ratio * 255)
                                                        customStudioCard.syncRgbToHex()
                                                    }
                                                    onPressed: mouse => setVal(mouse.x)
                                                    onPositionChanged: mouse => { if (pressed) setVal(mouse.x) }
                                                }
                                            }

                                            Rectangle {
                                                width: 38
                                                height: 22
                                                radius: 6
                                                color: root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: customStudioCard.greenVal.toString()
                                                    color: "#50fa7b"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        // Ползунок B (Blue)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Text {
                                                text: "B"
                                                color: "#8be9fd"
                                                font.pixelSize: 11
                                                font.bold: true
                                                Layout.preferredWidth: 16
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                                height: 22

                                                Rectangle {
                                                    id: bTrack
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 8
                                                    radius: 4
                                                    color: Qt.rgba(1, 1, 1, 0.08)

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        width: Math.max(8, Math.min(bTrack.width, bTrack.width * (customStudioCard.blueVal / 255.0)))
                                                        radius: 4
                                                        color: "#8be9fd"
                                                    }
                                                }

                                                Rectangle {
                                                    x: Math.max(0, Math.min(bTrack.width - width, (bTrack.width - width) * (customStudioCard.blueVal / 255.0)))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 16
                                                    height: 16
                                                    radius: 8
                                                    color: "#ffffff"
                                                    border.color: Qt.rgba(0, 0, 0, 0.4)
                                                    border.width: 1
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    function setVal(mx) {
                                                        let ratio = Math.max(0, Math.min(1.0, mx / width))
                                                        customStudioCard.blueVal = Math.round(ratio * 255)
                                                        customStudioCard.syncRgbToHex()
                                                    }
                                                    onPressed: mouse => setVal(mouse.x)
                                                    onPositionChanged: mouse => { if (pressed) setVal(mouse.x) }
                                                }
                                            }

                                            Rectangle {
                                                width: 38
                                                height: 22
                                                radius: 6
                                                color: root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: customStudioCard.blueVal.toString()
                                                    color: "#8be9fd"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }

                                    // HEX ввод и кнопка "Сохранить и применить"
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Text {
                                            text: "HEX код:"
                                            color: root.cfg.textMuted
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 65
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            height: 32
                                            radius: 8
                                            color: root.cfg.bgSurface
                                            border.color: root.cfg.borderCol
                                            border.width: 1

                                            TextInput {
                                                id: hexInput
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 11
                                                font.bold: true
                                                font.family: root.cfg.fontFamily
                                                text: customStudioCard.currentHex
                                                onTextEdited: customStudioCard.syncHexToRgb(text)
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            height: 32
                                            implicitWidth: saveThemeBtnText.implicitWidth + 28
                                            radius: 8
                                            color: customStudioCard.currentHex

                                            Text {
                                                id: saveThemeBtnText
                                                anchors.centerIn: parent
                                                text: "Сохранить и применить"
                                                color: (customStudioCard.redVal*0.299 + customStudioCard.greenVal*0.587 + customStudioCard.blueVal*0.114) > 160 ? "#111116" : "#ffffff"
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    let n = customNameInput.text.trim()
                                                    if (!n) n = "Мой стиль"
                                                    let hex = customStudioCard.currentHex
                                                    let surf = "#1a1c22"
                                                    let prim = "#131418"
                                                    let elev = "#252730"
                                                    if (customStudioCard.selectedToneIdx === 0) {
                                                        surf = "#0c0d10"; prim = "#050608"; elev = "#16181f"
                                                    } else if (customStudioCard.selectedToneIdx === 2) {
                                                        surf = "#161924"; prim = "#0f121a"; elev = "#222738"
                                                    } else if (customStudioCard.selectedToneIdx === 3) {
                                                        surf = "#1e1a19"; prim = "#141110"; elev = "#2c2625"
                                                    }
                                                    let cont = Qt.darker(hex, 2.0).toString()
                                                    root.cfg.addCustomTheme(n, hex, surf, prim, elev, cont)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }

                        // ================= ВКЛАДКА 6: ИНДИКАТОРЫ OSD =================
                        ColumnLayout {
                            id: osdTabCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 12
                            visible: root.tab === "osd"

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "Индикатор OSD"
                                    color: root.cfg.textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: root.cfg.fontFamily
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    height: 30
                                    implicitWidth: osdLiveBtnTxt.implicitWidth + 24
                                    radius: 15
                                    color: root.cfg.accent

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text { text: "󰆣"; color: root.cfg.accentText; font.pixelSize: 12 }
                                        Text { id: osdLiveBtnTxt; text: "Настроить на экране"; color: root.cfg.accentText; font.pixelSize: 11; font.bold: true }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.closeRequested()
                                            root.requestWidgetEditor("osd")
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 12
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 10

                                    Text {
                                        text: "󰆣"
                                        color: root.cfg.accent
                                        font.pixelSize: 16
                                    }

                                    Text {
                                        text: "Положение OSD настраивается интерактивно прямо на экране (кнопка выше) или пресетами:"
                                        color: root.cfg.textPrimary
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // Пресеты положения
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 6

                                Repeater {
                                    model: [
                                        { name: "Снизу (120 px)", by: 120, lx: 840 },
                                        { name: "По центру", by: 518, lx: 840 },
                                        { name: "Слева", by: 120, lx: 40 },
                                        { name: "Справа", by: 120, lx: 1640 },
                                        { name: "Вверху", by: 960, lx: 840 }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        Layout.preferredHeight: 24
                                        Layout.preferredWidth: pText.implicitWidth + 14
                                        radius: 12
                                        color: (root.cfg.osdBottomMargin === modelData.by && Math.abs(root.cfg.osdLeftMargin - modelData.lx) < 20) ? root.cfg.accent : root.cfg.bgElevated
                                        border.color: root.cfg.borderCol
                                        border.width: 1

                                        Text {
                                            id: pText
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            color: (root.cfg.osdBottomMargin === modelData.by && Math.abs(root.cfg.osdLeftMargin - modelData.lx) < 20) ? root.cfg.accentText : root.cfg.textPrimary
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.cfg.osdBottomMargin = modelData.by
                                                root.cfg.osdLeftMargin = modelData.lx
                                                root.cfg.save()
                                            }
                                        }
                                    }
                                }
                            }

                            // Тумблеры OSD
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 6
                                columnSpacing: 6

                                Repeater {
                                    model: [
                                        { name: "Громкость", prop: "osdVolume" },
                                        { name: "Раскладка клавиатуры", prop: "osdLang" },
                                        { name: "Caps Lock", prop: "osdCaps" },
                                        { name: "Режим «Не беспокоить»", prop: "dndMode" },
                                        { name: "Ночной свет", prop: "nightLight" },
                                        { name: "Режим энергосбережения", prop: "powerSaveMode" }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        radius: 10
                                        color: root.cfg.bgElevated
                                        border.color: root.cfg.borderCol
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10

                                            Text { text: modelData.name; color: root.cfg.textPrimary; font.pixelSize: 11; Layout.fillWidth: true }

                                            Rectangle {
                                                Layout.preferredWidth: 36; Layout.preferredHeight: 20; radius: 10
                                                color: root.cfg[modelData.prop] ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: root.cfg.borderCol; border.width: 1
                                                Rectangle {
                                                    width: 14; height: 14; radius: 7; y: 2
                                                    x: root.cfg[modelData.prop] ? 18 : 2
                                                    color: root.cfg[modelData.prop] ? root.cfg.accentText : root.cfg.textMuted
                                                    Behavior on x { NumberAnimation { duration: 140 } }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.cfg[modelData.prop] = !root.cfg[modelData.prop]
                                                root.cfg.save()
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }

                        // ================= ВКЛАДКА 7: БЛОКИРОВКА =================
                        ColumnLayout {
                            id: lockTabCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 14
                            visible: root.tab === "lock"

                            Text {
                                text: "Параметры входа"
                                color: root.cfg.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 14
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1
                                implicitHeight: lockFieldsCol.implicitHeight

                                ColumnLayout {
                                    id: lockFieldsCol
                                    anchors.fill: parent
                                    spacing: 0

                                    // PIN
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 46

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "Аварийный PIN:"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 160 }

                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 6
                                                color: root.cfg.bgSurface
                                                border.color: pinInp.activeFocus ? root.cfg.accent : root.cfg.borderCol
                                                border.width: 1

                                                TextInput {
                                                    id: pinInp
                                                    anchors.fill: parent; anchors.margins: 6
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    color: root.cfg.textPrimary
                                                    font.pixelSize: 11; font.bold: true
                                                    text: root.cfg.lockPin
                                                    onTextEdited: { root.cfg.lockPin = text; root.cfg.save() }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol; Layout.leftMargin: 14; Layout.rightMargin: 14 }

                                    // Город погоды
                                    // 1. Автоопределение местоположения по IP
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 46

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: "Автоопределение города (по IP)"
                                                    color: root.cfg.textPrimary
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    font.family: root.cfg.fontFamily
                                                }
                                                Text {
                                                    text: root.cfg.weatherAutoLocation ? ("Геолокация активна: " + root.cfg.weatherCity) : "Ручной ввод города"
                                                    color: root.cfg.textMuted
                                                    font.pixelSize: 10
                                                    font.family: root.cfg.fontFamily
                                                }
                                            }

                                            // Переключатель автоопределения
                                            M3Switch {
                                                checked: root.cfg.weatherAutoLocation
                                                activeTrackColor: root.cfg.accent
                                                activeThumbColor: root.cfg.accentText
                                                onToggled: val => {
                                                    root.cfg.weatherAutoLocation = val
                                                    root.cfg.save()
                                                    root.cfg.refreshWeather()
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol; Layout.leftMargin: 14; Layout.rightMargin: 14 }

                                    // 2. Город прогноза (ручной ввод или инфо)
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 46

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text {
                                                text: root.cfg.weatherAutoLocation ? "Текущий город:" : "Город прогноза:"
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                                Layout.preferredWidth: 160
                                            }

                                            // Если автоопределение включено — показываем бейдж и кнопку обновления
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8
                                                visible: root.cfg.weatherAutoLocation

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 28
                                                    radius: 14
                                                    color: root.cfg.bgSurface
                                                    border.color: root.cfg.borderCol
                                                    border.width: 1
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 10
                                                        spacing: 6
                                                        Text { text: "📍"; font.pixelSize: 11 }
                                                        Text {
                                                            text: root.cfg.weatherCity + " (" + root.cfg.weatherText + ", " + root.cfg.weatherDesc + ")"
                                                            color: root.cfg.textPrimary
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    height: 28
                                                    implicitWidth: 32
                                                    radius: 14
                                                    color: refM.containsMouse ? root.cfg.accent : root.cfg.bgSurface
                                                    border.color: root.cfg.borderCol
                                                    border.width: 1
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰑐"
                                                        color: refM.containsMouse ? root.cfg.accentText : root.cfg.accent
                                                        font.pixelSize: 13
                                                    }
                                                    MouseArea {
                                                        id: refM
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.cfg.refreshWeather()
                                                    }
                                                }
                                            }

                                            // Если выключено — поле ручного ввода
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 6
                                                color: root.cfg.bgSurface
                                                border.color: cityInp.activeFocus ? root.cfg.accent : root.cfg.borderCol
                                                border.width: 1
                                                visible: !root.cfg.weatherAutoLocation

                                                TextInput {
                                                    id: cityInp
                                                    anchors.fill: parent; anchors.margins: 6
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    color: root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    text: root.cfg.weatherCity
                                                    onTextEdited: { root.cfg.weatherCity = text; root.cfg.save() }
                                                    onAccepted: root.cfg.refreshWeather()
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol; Layout.leftMargin: 14; Layout.rightMargin: 14 }

                                    // Путь к аватарке
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 46

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "Файл аватарки:"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 160 }

                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 6
                                                color: root.cfg.bgSurface
                                                border.color: avatarInp.activeFocus ? root.cfg.accent : root.cfg.borderCol
                                                border.width: 1

                                                TextInput {
                                                    id: avatarInp
                                                    anchors.fill: parent; anchors.margins: 6
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    color: root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    text: root.cfg.avatarPath
                                                    onTextEdited: { root.cfg.avatarPath = text; root.cfg.save() }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Элементы экрана"
                                color: root.cfg.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                font.family: root.cfg.fontFamily
                                Layout.topMargin: 4
                            }

                            GridLayout {
                                Layout.fillWidth: true; columns: 2; rowSpacing: 6; columnSpacing: 6
                                Repeater {
                                    model: [
                                        { name: "Аватарка", prop: "lockShowAvatar" },
                                        { name: "Датчики ресурсов", prop: "lockShowGauges" },
                                        { name: "Погода", prop: "lockShowWeather" },
                                        { name: "Дата", prop: "lockShowDate" }
                                    ]
                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10
                                        color: root.cfg.bgElevated; border.color: root.cfg.borderCol; border.width: 1
                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                                            Text { text: modelData.name; color: root.cfg.textPrimary; font.pixelSize: 11; Layout.fillWidth: true }
                                            Rectangle {
                                                Layout.preferredWidth: 36; Layout.preferredHeight: 20; radius: 10
                                                color: root.cfg[modelData.prop] ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: root.cfg.borderCol; border.width: 1
                                                Rectangle {
                                                    width: 14; height: 14; radius: 7; y: 2
                                                    x: root.cfg[modelData.prop] ? 18 : 2
                                                    color: root.cfg[modelData.prop] ? root.cfg.accentText : root.cfg.textMuted
                                                    Behavior on x { NumberAnimation { duration: 140 } }
                                                }
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.cfg[modelData.prop] = !root.cfg[modelData.prop]; root.cfg.save() }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 18
                                color: root.cfg.accent
                                Layout.topMargin: 4

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "󰌾"; color: root.cfg.accentText; font.pixelSize: 13 }
                                    Text { text: "Заблокировать экран"; color: root.cfg.accentText; font.pixelSize: 12; font.bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.closeRequested(); root.cfg.isLocked = true }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }

                        // ================= ВКЛАДКА 8: СИСТЕМА =================
                        ColumnLayout {
                            id: systemTabCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 16
                            spacing: 14
                            visible: root.tab === "system"

                            Text {
                                text: "Окружение"
                                color: root.cfg.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 14
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1
                                implicitHeight: envGroupCol.implicitHeight

                                ColumnLayout {
                                    id: envGroupCol
                                    anchors.fill: parent
                                    spacing: 0

                                    // Перезагрузка Hyprland
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "󰑐"; color: root.cfg.accent; font.pixelSize: 15 }
                                            Text {
                                                text: "Перезагрузить Hyprland"
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: root.cfg.fontFamily
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                height: 28
                                                implicitWidth: 100
                                                radius: 14
                                                color: rldM.containsMouse ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Перезагрузить"
                                                    color: rldM.containsMouse ? root.cfg.accentText : root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    id: rldM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        settingsSysProc.command = ["sh", "-c", "hyprctl reload"]
                                                        settingsSysProc.running = true
                                                        root.cfg.pushNotification("Hyprland", "Конфигурация перезагружена")
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol; Layout.leftMargin: 14; Layout.rightMargin: 14 }

                                    // Очистить историю уведомлений
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "󰂚"; color: root.cfg.textMuted; font.pixelSize: 15 }
                                            Text {
                                                text: "Очистить историю уведомлений"
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: root.cfg.fontFamily
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                height: 28
                                                implicitWidth: 80
                                                radius: 14
                                                color: clrNotifM.containsMouse ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Очистить"
                                                    color: clrNotifM.containsMouse ? root.cfg.accentText : root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    id: clrNotifM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.cfg.clearNotifications()
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol; Layout.leftMargin: 14; Layout.rightMargin: 14 }

                                    // Сохранить настройки
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "󰜉"; color: root.cfg.textMuted; font.pixelSize: 15 }
                                            Text {
                                                text: "Сохранить конфигурацию"
                                                color: root.cfg.textPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: root.cfg.fontFamily
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                height: 28
                                                implicitWidth: 80
                                                radius: 14
                                                color: saveCfgM.containsMouse ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Сохранить"
                                                    color: saveCfgM.containsMouse ? root.cfg.accentText : root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    id: saveCfgM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.cfg.save()
                                                        root.cfg.pushNotification("Quickshell", "Конфигурация сохранена")
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol; Layout.leftMargin: 14; Layout.rightMargin: 14 }

                                    // Автообновление конфигурации
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 48

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 14

                                            Text { text: "󰚰"; color: root.cfg.accent; font.pixelSize: 15 }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text {
                                                    text: "Обновление конфигурации"
                                                    color: root.cfg.textPrimary
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    font.family: root.cfg.fontFamily
                                                }
                                                Text {
                                                    text: "Синхронизация с GitHub (StopNope/dotfile-Hyprland)"
                                                    color: root.cfg.textMuted
                                                    font.pixelSize: 10
                                                    font.family: root.cfg.fontFamily
                                                }
                                            }

                                            Rectangle {
                                                height: 28
                                                implicitWidth: 90
                                                radius: 14
                                                color: updCfgM.containsMouse ? root.cfg.accent : root.cfg.bgSurface
                                                border.color: root.cfg.borderCol
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Обновить"
                                                    color: updCfgM.containsMouse ? root.cfg.accentText : root.cfg.textPrimary
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    id: updCfgM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        settingsSysProc.command = ["bash", "/home/stopnope/.config/quickshell/scripts/updater.sh"]
                                                        settingsSysProc.running = true
                                                        root.cfg.pushNotification("Обновление", "Запущена проверка обновлений из GitHub...")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Бесконечный рабочий стол"
                                color: root.cfg.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                font.family: root.cfg.fontFamily
                                Layout.topMargin: 4
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 14
                                color: root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1
                                Layout.preferredHeight: 50

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 14

                                    Text { text: "󰹑"; color: root.cfg.accent; font.pixelSize: 16 }
                                    Text {
                                        text: "Ограничивать окна текущим монитором"
                                        color: root.cfg.textPrimary
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: root.cfg.fontFamily
                                        Layout.fillWidth: true
                                    }

                                    M3Switch {
                                        checked: root.clampToMonitor
                                        activeTrackColor: root.cfg.accent
                                        activeThumbColor: root.cfg.accentText
                                        onToggled: val => {
                                            root.clampToMonitor = val
                                            settingsSysProc.command = ["python3", "/home/stopnope/.config/quickshell/scripts/vxwm_controller.py", "toggle_clamp"]
                                            settingsSysProc.running = true
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // Скроллбар
                Item {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    width: 4
                    visible: tabFlickable.contentHeight > tabFlickable.height

                    Rectangle {
                        id: scrollThumb
                        anchors.right: parent.right
                        width: 4
                        radius: 2
                        color: root.cfg.accent
                        opacity: 0.65
                        height: Math.max(28, (tabFlickable.height / tabFlickable.contentHeight) * tabFlickable.height)
                        y: Math.max(0, Math.min(parent.height - height, (tabFlickable.contentY / Math.max(1, tabFlickable.contentHeight - tabFlickable.height)) * (parent.height - height)))
                    }
                }
            }
        }
    }
}
}
