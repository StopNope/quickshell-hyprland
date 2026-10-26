import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "./m3"

Rectangle {
    id: root

    required property var cfg
    signal closeRequested()
    signal openNetworkMenu(string tab)
    signal openSettings()

    property bool isOpen: false
    property bool isCustomizing: false

    width: cfg.sidePanelWidth
    radius: 28
    color: root.cfg.bgSurface
    border.color: root.cfg.borderCol || "#323540"
    border.width: 1
    clip: true

    opacity: isOpen ? 1 : 0
    transform: Translate {
        x: root.isOpen ? 0 : 50
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    focus: true
    Keys.onEscapePressed: {
        if (root.isCustomizing) root.isCustomizing = false
        else root.closeRequested()
    }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.isCustomizing) root.isCustomizing = false
            else root.closeRequested()
        }
    }

    Process { id: sysCmdProc }

    function setVolume(val) {
        let v = Math.max(0, Math.min(100, val))
        cfg.currentVolume = v
        if (v === 0) {
            cfg.isMuted = true
            sysCmdProc.exec(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 1; wpctl set-volume @DEFAULT_AUDIO_SINK@ 0%"])
        } else {
            cfg.isMuted = false
            sysCmdProc.exec(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v + "%"])
        }
    }

    function toggleMute() {
        cfg.isMuted = !cfg.isMuted
        if (!cfg.isMuted && cfg.currentVolume === 0) {
            cfg.currentVolume = 25
            sysCmdProc.exec(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 25%"])
        } else {
            sysCmdProc.exec(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (cfg.isMuted ? "1" : "0")])
        }
    }

    function setBrightness(val) {
        let b = Math.max(0, Math.min(100, val))
        cfg.currentBrightness = b
    }

    function getSideSectionComponent(id) {
        if (id === "tiles") return root.cfg.sideShowTiles ? compTiles : null
        if (id === "sliders") return root.cfg.sideShowSliders ? compSliders : null
        if (id === "media") return root.cfg.sideShowMedia ? compMedia : null
        if (id === "gauges") return root.cfg.sideShowGauges ? compGauges : null
        if (id === "notifications") return root.cfg.sideShowNotifications ? compNotifications : null
        if (id === "power") return root.cfg.sideShowPower ? compPower : null
        return null
    }

    // Material 3 Monet токен акцента
    readonly property color m3Pastel: root.cfg.accent
    readonly property color m3SurfaceContainer: "#24262c"
    readonly property color m3SurfaceHighest: "#33353d"
    readonly property color m3SurfaceVariant: "#2b2d35"
    readonly property color m3OnPastel: "#1a1c22"

    // ========================================================
    // СОСТОЯНИЕ А: РЕЖИМ КАСТОМИЗАЦИИ ШТОРКИ (КАК В ТЕЛЕФОНЕ)
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        visible: root.isCustomizing

        // Заголовок кастомизации
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 32; height: 32; radius: 16
                color: root.cfg.accentContainer
                Text { anchors.centerIn: parent; text: "󰏫"; color: root.m3Pastel; font.pixelSize: 15 }
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                Text { text: "Кастомизация шторки"; color: root.cfg.textPrimary; font.pixelSize: 13; font.bold: true; font.family: root.cfg.fontFamily }
                Text { text: "Настройте видимость секций"; color: root.cfg.textMuted; font.pixelSize: 10; font.family: root.cfg.fontFamily }
            }

            Rectangle {
                height: 32; implicitWidth: doneTxt.implicitWidth + 20; radius: 16; color: root.m3Pastel
                Text { id: doneTxt; anchors.centerIn: parent; text: "✓ Готово"; color: root.m3OnPastel; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cfg.save()
                        root.isCustomizing = false
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 12

                Text { text: "Отображаемые секции:"; color: root.m3Pastel; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Чип: Hero
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 18
                        color: root.cfg.sideShowHero ? root.cfg.accentContainer : root.m3SurfaceVariant
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            Text { text: "󰥔  Hero: Часы и профиль"; color: root.cfg.sideShowHero ? root.m3Pastel : root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: root.cfg.sideShowHero ? "ВКЛ" : "ВЫКЛ"; color: root.cfg.sideShowHero ? root.m3Pastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.sideShowHero = !root.cfg.sideShowHero; root.cfg.save() } }
                    }

                    // Чип: Быстрые плитки (Wi-Fi / BT)
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 18
                        color: root.cfg.sideShowTiles ? root.cfg.accentContainer : root.m3SurfaceVariant
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            Text { text: "󰤨  Плитки сети (Wi-Fi, Bluetooth)"; color: root.cfg.sideShowTiles ? root.m3Pastel : root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: root.cfg.sideShowTiles ? "ВКЛ" : "ВЫКЛ"; color: root.cfg.sideShowTiles ? root.m3Pastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.sideShowTiles = !root.cfg.sideShowTiles; root.cfg.save() } }
                    }

                    // Чип: Слайдеры
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 18
                        color: root.cfg.sideShowSliders ? root.cfg.accentContainer : root.m3SurfaceVariant
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            Text { text: "󰕾  Слайдеры громкости и яркости"; color: root.cfg.sideShowSliders ? root.m3Pastel : root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: root.cfg.sideShowSliders ? "ВКЛ" : "ВЫКЛ"; color: root.cfg.sideShowSliders ? root.m3Pastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.sideShowSliders = !root.cfg.sideShowSliders; root.cfg.save() } }
                    }

                    // Чип: Медиаплеер
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 18
                        color: root.cfg.sideShowMedia ? root.cfg.accentContainer : root.m3SurfaceVariant
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            Text { text: "󰎆  Медиаплеер Material You"; color: root.cfg.sideShowMedia ? root.m3Pastel : root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: root.cfg.sideShowMedia ? "ВКЛ" : "ВЫКЛ"; color: root.cfg.sideShowMedia ? root.m3Pastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.sideShowMedia = !root.cfg.sideShowMedia; root.cfg.save() } }
                    }

                    // Чип: Монитор ресурсов
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 18
                        color: root.cfg.sideShowGauges ? root.cfg.accentContainer : root.m3SurfaceVariant
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            Text { text: "󰍛  Монитор ресурсов (CPU/RAM/GPU)"; color: root.cfg.sideShowGauges ? root.m3Pastel : root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: root.cfg.sideShowGauges ? "ВКЛ" : "ВЫКЛ"; color: root.cfg.sideShowGauges ? root.m3Pastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.sideShowGauges = !root.cfg.sideShowGauges; root.cfg.save() } }
                    }

                    // Чип: Уведомления
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 18
                        color: root.cfg.sideShowNotifications ? root.cfg.accentContainer : root.m3SurfaceVariant
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            Text { text: "󰂚  Центр уведомлений"; color: root.cfg.sideShowNotifications ? root.m3Pastel : root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: root.cfg.sideShowNotifications ? "ВКЛ" : "ВЫКЛ"; color: root.cfg.sideShowNotifications ? root.m3Pastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.sideShowNotifications = !root.cfg.sideShowNotifications; root.cfg.save() } }
                    }

                    // Чип: Питание
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 18
                        color: root.cfg.sideShowPower ? root.cfg.accentContainer : root.m3SurfaceVariant
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            Text { text: "󰐥  Панель питания и выхода"; color: root.cfg.sideShowPower ? root.m3Pastel : root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: root.cfg.sideShowPower ? "ВКЛ" : "ВЫКЛ"; color: root.cfg.sideShowPower ? root.m3Pastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.sideShowPower = !root.cfg.sideShowPower; root.cfg.save() } }
                    }
                }

                // 2. Стилизация компонентов
                Text { text: "Стилизация Material You:"; color: root.m3Pastel; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Полоса музыки:"; color: root.cfg.textPrimary; font.pixelSize: 11; font.family: root.cfg.fontFamily; Layout.fillWidth: true }
                        Rectangle {
                            height: 28; implicitWidth: 100; radius: 14
                            color: root.cfg.playerProgressStyle === "wavy" ? root.m3Pastel : root.m3SurfaceVariant
                            border.color: root.cfg.borderCol || "#323540"
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "󰤽 Волна M3"; color: root.cfg.playerProgressStyle === "wavy" ? root.m3OnPastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.playerProgressStyle = "wavy"; root.cfg.save() } }
                        }
                        Rectangle {
                            height: 28; implicitWidth: 70; radius: 14
                            color: root.cfg.playerProgressStyle === "flat" ? root.m3Pastel : root.m3SurfaceVariant
                            border.color: root.cfg.borderCol || "#323540"
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "󰇄 Обычная"; color: root.cfg.playerProgressStyle === "flat" ? root.m3OnPastel : root.cfg.textMuted; font.pixelSize: 10; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.cfg.playerProgressStyle = "flat"; root.cfg.save() } }
                        }
                    }
                }
            }
        }
    }

    // ========================================================
    // СОСТОЯНИЕ Б: ОСНОВНОЙ МАКЕТ ШТОРКИ (MATERIAL YOU / PIXEL)
    // ========================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        visible: !root.isCustomizing

        // ================= 1. AT-A-GLANCE SHADE HEADER (ANDROID 14 & 15 / MATERIAL YOU) =================
        ColumnLayout {
            visible: root.cfg.sideShowHero
            Layout.fillWidth: true
            spacing: 12
            Layout.topMargin: 4
            Layout.bottomMargin: 4

            // Верхняя строка: Профиль + Круглые кнопки действий
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Чип профиля пользователя
                Rectangle {
                    height: 36
                    implicitWidth: userRow.implicitWidth + 20
                    radius: 18
                    color: root.m3SurfaceVariant
                    border.color: root.cfg.borderCol || "#323540"
                    border.width: 1

                    RowLayout {
                        id: userRow
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: root.m3SurfaceHighest
                            border.color: root.m3Pastel
                            border.width: 1.5
                            clip: true

                            Image {
                                id: userAvatar
                                anchors.fill: parent
                                source: (root.cfg.avatarPath && root.cfg.avatarPath !== "" && root.cfg.avatarPath !== "/home/stopnope/.face") ? ("file://" + root.cfg.avatarPath) : ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: userAvatar.status !== Image.Ready
                                text: "󰀉"
                                color: root.m3Pastel
                                font.pixelSize: 15
                            }
                        }

                        Text {
                            text: (Quickshell.env("USER") || "пользователь").toUpperCase()
                            color: root.cfg.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Круглые кнопки FAB (36x36)
                // 1. Карандаш (редактирование шторки)
                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: editBtnM.containsMouse ? root.m3SurfaceHighest : root.m3SurfaceVariant
                    border.color: root.cfg.borderCol || "#323540"; border.width: 1
                    scale: editBtnM.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text { anchors.centerIn: parent; text: "󰏫"; color: root.m3Pastel; font.pixelSize: 15 }
                    MouseArea {
                        id: editBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.isCustomizing = true
                    }
                }

                // 2. Настройки
                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: sBtn.containsMouse ? root.m3SurfaceHighest : root.m3SurfaceVariant
                    border.color: root.cfg.borderCol || "#323540"; border.width: 1
                    scale: sBtn.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text { anchors.centerIn: parent; text: "󰒓"; color: root.cfg.textPrimary; font.pixelSize: 15 }
                    MouseArea {
                        id: sBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.closeRequested(); root.openSettings() }
                    }
                }

                // 3. Блокировка
                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: lkBtn.containsMouse ? root.m3SurfaceHighest : root.m3SurfaceVariant
                    border.color: root.cfg.borderCol || "#323540"; border.width: 1
                    scale: lkBtn.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text { anchors.centerIn: parent; text: "󰌾"; color: root.cfg.textPrimary; font.pixelSize: 15 }
                    MouseArea {
                        id: lkBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.closeRequested(); root.cfg.lock() }
                    }
                }

                // 4. Закрытие
                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: cBtn.containsMouse ? root.m3SurfaceHighest : root.m3SurfaceVariant
                    border.color: root.cfg.borderCol || "#323540"; border.width: 1
                    scale: cBtn.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text { anchors.centerIn: parent; text: "󰅖"; color: root.cfg.textMuted; font.pixelSize: 15 }
                    MouseArea {
                        id: cBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            // Нижняя строка: Крупнейшие часы Pixel Display Clock + Капсула погоды
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: Qt.formatDateTime(new Date(), "hh:mm")
                    color: root.cfg.textPrimary
                    font.pixelSize: 42
                    font.bold: true
                    font.family: "Fredoka"
                    Layout.fillWidth: true
                }

                Rectangle {
                    height: 42
                    implicitWidth: weatherBox.implicitWidth + 24
                    radius: 21
                    color: root.m3SurfaceVariant
                    border.color: root.cfg.borderCol || "#323540"
                    border.width: 1

                    RowLayout {
                        id: weatherBox
                        anchors.centerIn: parent
                        spacing: 8

                        Text { text: "󰖐"; color: root.m3Pastel; font.pixelSize: 19 }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: (root.cfg.weatherText || "+5°") + " • " + (root.cfg.weatherCity || "Тюмень")
                                color: root.cfg.textPrimary
                                font.pixelSize: 11
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }
                            Text {
                                text: Qt.formatDateTime(new Date(), "d MMMM, dddd")
                                color: root.cfg.textMuted
                                font.pixelSize: 9
                                font.family: root.cfg.fontFamily
                            }
                        }
                    }
                }
            }
        }

        // ================= ДИНАМИЧЕСКИЙ СПИСОК СЕКЦИЙ ШТОРКИ =================
        Repeater {
            model: root.cfg.sidePanelOrder
            delegate: ColumnLayout {
                required property string modelData
                Layout.fillWidth: true
                Layout.fillHeight: modelData === "power"
                spacing: 0

                // Эластичный спейсер перед блоком питания плавно докает кнопки сессии вниз без пустоты
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: modelData === "power"
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    sourceComponent: root.getSideSectionComponent(modelData)
                }
            }
        }

        // Страховочный спейсер, если блок power выключен
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.cfg.sidePanelOrder.includes("power")
        }

        // ================= МОДУЛЬНЫЕ ШАБЛОНЫ СЕКЦИЙ ШТОРКИ =================

        // ================= 2. QUICK SETTINGS TILES (WI-FI, BT, DND, NIGHT LIGHT) =================
        Component {
            id: compTiles
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Верхний ряд: Wi-Fi и Bluetooth
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    M3Tile {
                        title: "Wi-Fi"
                        subtitle: root.cfg.activeWifiSsid ? root.cfg.activeWifiSsid : "Выключено"
                        icon: "󰤨"
                        active: !!root.cfg.activeWifiSsid
                        hasDetails: true
                        primaryCol: root.m3Pastel
                        onPrimaryCol: root.m3OnPastel
                        containerCol: root.m3SurfaceVariant
                        onToggled: { root.closeRequested(); root.openNetworkMenu("wifi") }
                        onDetailsClicked: { root.closeRequested(); root.openNetworkMenu("wifi") }
                    }

                    M3Tile {
                        title: "Bluetooth"
                        subtitle: "Устройства"
                        icon: "󰂯"
                        active: false
                        hasDetails: true
                        primaryCol: root.m3Pastel
                        onPrimaryCol: root.m3OnPastel
                        containerCol: root.m3SurfaceVariant
                        onToggled: { root.closeRequested(); root.openNetworkMenu("bt") }
                        onDetailsClicked: { root.closeRequested(); root.openNetworkMenu("bt") }
                    }
                }

                // Второй ряд: DND и Ночной свет
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    M3Tile {
                        title: "Не беспокоить"
                        subtitle: root.cfg.dndMode ? "Включено" : "Выключено"
                        icon: "󰂛"
                        active: root.cfg.dndMode
                        hasDetails: false
                        primaryCol: root.m3Pastel
                        onPrimaryCol: root.m3OnPastel
                        containerCol: root.m3SurfaceVariant
                        onToggled: { root.cfg.dndMode = !root.cfg.dndMode; root.cfg.save() }
                    }

                    M3Tile {
                        title: "Ночной свет"
                        subtitle: root.cfg.nightLight ? "Включено" : "Выключено"
                        icon: "󰖔"
                        active: root.cfg.nightLight
                        hasDetails: false
                        primaryCol: root.m3Pastel
                        onPrimaryCol: root.m3OnPastel
                        containerCol: root.m3SurfaceVariant
                        onToggled: { root.cfg.nightLight = !root.cfg.nightLight; root.cfg.save() }
                    }
                }

                // Третий ряд: Энергосбережение и Снимок экрана
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    M3Tile {
                        title: "Энергосбережение"
                        subtitle: root.cfg.powerSaveMode ? "Включено" : "Выключено"
                        icon: "󰌪"
                        active: root.cfg.powerSaveMode
                        hasDetails: false
                        primaryCol: root.m3Pastel
                        onPrimaryCol: root.m3OnPastel
                        containerCol: root.m3SurfaceVariant
                        onToggled: { root.cfg.powerSaveMode = !root.cfg.powerSaveMode; root.cfg.save() }
                    }

                    M3Tile {
                        title: "Снимок экрана"
                        subtitle: "Область"
                        icon: "󰄄"
                        active: false
                        hasDetails: false
                        primaryCol: root.m3Pastel
                        onPrimaryCol: root.m3OnPastel
                        containerCol: root.m3SurfaceVariant
                        onToggled: {
                            root.closeRequested()
                            sysCmdProc.exec(["sh", "-c", "/home/stopnope/.local/bin/screenshot.sh"])
                        }
                    }
                }
            }
        }

        // ================= 3. СЛАЙДЕРЫ M3 (ГОРИЗОНТАЛЬНЫЕ КАПСУЛЫ С SCISSOR-CLIPPING) =================
        Component {
            id: compSliders
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                M3Slider {
                    value: root.cfg.currentVolume
                    isMuted: root.cfg.isMuted || root.cfg.currentVolume === 0
                    icon: (root.cfg.isMuted || root.cfg.currentVolume === 0) ? "󰝟" : (root.cfg.currentVolume > 50 ? "󰕾" : "󰖀")
                    label: "Звук"
                    activeColor: root.m3Pastel
                    onActiveColor: root.m3OnPastel
                    inactiveTrackColor: root.m3SurfaceHighest
                    onValueModified: newVal => root.setVolume(newVal)
                    onIconClicked: root.toggleMute()
                }

                M3Slider {
                    value: root.cfg.currentBrightness
                    icon: root.cfg.currentBrightness === 0 ? "󰃞" : (root.cfg.currentBrightness > 50 ? "󰃠" : "󰃟")
                    label: "Яркость"
                    activeColor: root.m3Pastel
                    onActiveColor: root.m3OnPastel
                    inactiveTrackColor: root.m3SurfaceHighest
                    onValueModified: newVal => root.setBrightness(newVal)
                    onIconClicked: root.setBrightness(root.cfg.currentBrightness > 0 ? 0 : 100)
                }
            }
        }

        // ================= 4. MATERIAL YOU МЕДИАПЛЕЕР В ШТОРКЕ =================
        Component {
            id: compMedia
            Rectangle {
                id: mediaCard
                Layout.fillWidth: true
                implicitHeight: hasMedia ? 166 : 72
                Layout.preferredHeight: implicitHeight
                radius: 24
                color: root.m3SurfaceContainer
                border.color: root.cfg.borderCol || "#323540"
                border.width: 1
                clip: true

                readonly property var players: Mpris.players.values || []
                property int selectedIndex: 0
                readonly property var player: {
                    if (!players || players.length === 0) return null
                    if (selectedIndex >= 0 && selectedIndex < players.length) {
                        let p = players[selectedIndex]
                        if (p) return p
                    }
                    for (let i = 0; i < players.length; i++) {
                        if (players[i].isPlaying) return players[i]
                    }
                    return players[0]
                }

                readonly property bool hasMedia: player !== null && (player.trackTitle !== "" || player.isPlaying)
                readonly property bool isPlaying: player !== null && player.isPlaying

                function formatTime(sec) {
                    if (!sec || isNaN(sec) || sec <= 0) return "00:00"
                    let s = Math.floor(sec)
                    let m = Math.floor(s / 60)
                    let remSec = s % 60
                    return (m < 10 ? "0" : "") + m + ":" + (remSec < 10 ? "0" : "") + remSec
                }

                readonly property var serviceInfo: {
                    if (!player) return { name: "Медиаплеер", icon: "󰎆" }
                    let idLower = (player.identity || "").toLowerCase()
                    let titleLower = (player.trackTitle || "").toLowerCase()
                    if (idLower.includes("spotify")) return { name: "Spotify", icon: "󰓇" }
                    if (idLower.includes("firefox") || idLower.includes("chrome") || idLower.includes("chromium") || idLower.includes("brave")) {
                        if (titleLower.includes("yandex") || titleLower.includes("ядекс") || titleLower.includes("яндекс")) return { name: "Яндекс Музыка", icon: "󰎆" }
                        if (titleLower.includes("soundcloud")) return { name: "SoundCloud", icon: "󰎆" }
                        if (titleLower.includes("vk") || titleLower.includes("вконтакте")) return { name: "VK Музыка", icon: "󰎆" }
                        if (titleLower.includes("youtube")) return { name: "YouTube Music", icon: "󰗃" }
                        return { name: "Браузер", icon: "󰈹" }
                    }
                    return { name: player.identity || "Медиа", icon: "󰎆" }
                }

                property real localPos: player ? player.position : 0
                property real trackLen: (player && player.length > 0) ? player.length : 0

                Connections {
                    target: mediaCard.player
                    ignoreUnknownSignals: true
                    function onPositionChanged() {
                        if (mediaCard.player) mediaCard.localPos = mediaCard.player.position
                    }
                }

                Timer {
                    interval: 1000
                    running: mediaCard.isPlaying
                    repeat: true
                    onTriggered: {
                        if (mediaCard.player && mediaCard.player.isPlaying) {
                            if (mediaCard.trackLen > 0 && mediaCard.localPos < mediaCard.trackLen) {
                                mediaCard.localPos += 1
                            } else if (mediaCard.trackLen <= 0) {
                                mediaCard.localPos += 1
                            }
                        }
                    }
                }

                // Полупрозрачный фон обложки
                Image {
                    anchors.fill: parent
                    source: mediaCard.player ? (mediaCard.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.10
                    visible: mediaCard.hasMedia && status === Image.Ready
                }

                // ================= СОСТОЯНИЕ 1: АКТИВНЫЙ ТРЕК =================
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    visible: mediaCard.hasMedia

                    // Верхний ряд: Обложка + Название + Исполнитель + Сервис
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 14
                            color: root.m3SurfaceHighest
                            clip: true

                            Image {
                                id: cardCoverArt
                                anchors.fill: parent
                                source: mediaCard.player ? (mediaCard.player.trackArtUrl || "") : ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: cardCoverArt.status !== Image.Ready
                                text: "󰎆"
                                color: root.m3Pastel
                                font.pixelSize: 20
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: (mediaCard.player && mediaCard.player.trackTitle) ? mediaCard.player.trackTitle : "Неизвестный трек"
                                color: root.cfg.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                font.family: root.cfg.fontFamily
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    if (!mediaCard.player) return "Неизвестен"
                                    if (mediaCard.player.trackArtist) return mediaCard.player.trackArtist
                                    if (mediaCard.player.trackArtists) return mediaCard.player.trackArtists
                                    return "Исполнитель"
                                }
                                color: root.cfg.textMuted
                                font.pixelSize: 11
                                font.family: root.cfg.fontFamily
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 4
                                Text { text: mediaCard.serviceInfo.icon; color: root.m3Pastel; font.pixelSize: 10 }
                                Text { text: mediaCard.serviceInfo.name; color: root.m3Pastel; font.pixelSize: 9; font.bold: true; font.family: root.cfg.fontFamily }
                            }
                        }

                        // Переключатель стиля полосы: Волна / Прямая
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: waveBtnM.containsMouse ? root.m3SurfaceHighest : "transparent"
                            border.color: root.cfg.borderCol || "#323540"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: root.cfg.playerProgressStyle === "wavy" ? "󰤽" : "󰇄"
                                color: root.m3Pastel
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: waveBtnM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.cfg.playerProgressStyle = (root.cfg.playerProgressStyle === "wavy") ? "flat" : "wavy"
                                    root.cfg.save()
                                }
                            }
                        }
                    }

                    // Волна прогресса
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Item {
                            id: cardProgBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18

                            readonly property real progressRatio: (mediaCard.trackLen > 0) ? Math.max(0, Math.min(1, mediaCard.localPos / mediaCard.trackLen)) : 0
                            property bool isSeeking: false
                            property real smoothRatio: progressRatio

                            Behavior on smoothRatio {
                                enabled: !cardProgBox.isSeeking && mediaCard.isPlaying
                                NumberAnimation { duration: 950; easing.type: Easing.Linear }
                            }

                            onProgressRatioChanged: {
                                smoothRatio = progressRatio
                            }

                            Canvas {
                                id: cardWaveCanvas
                                anchors.fill: parent
                                property real phase: 0
                                onPhaseChanged: requestPaint()

                                NumberAnimation {
                                    target: cardWaveCanvas
                                    property: "phase"
                                    from: 0
                                    to: 2 * Math.PI
                                    duration: 2200
                                    loops: Animation.Infinite
                                    running: mediaCard.isPlaying && root.cfg.playerProgressStyle === "wavy"
                                }

                                function drawDropletPill(ctx, cx, cy, w, h, col) {
                                    let r = w / 2
                                    let x = cx - r
                                    let y = cy - h / 2
                                    ctx.save()
                                    ctx.fillStyle = col
                                    ctx.beginPath()
                                    ctx.moveTo(x + r, y)
                                    ctx.arcTo(x + w, y, x + w, y + h, r)
                                    ctx.arcTo(x + w, y + h, x, y + h, r)
                                    ctx.arcTo(x, y + h, x, y, r)
                                    ctx.arcTo(x, y, x + w, y, r)
                                    ctx.closePath()
                                    ctx.fill()
                                    ctx.restore()
                                }

                                onPaint: {
                                    let ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    let cy = height / 2
                                    let playedW = Math.max(0, Math.min(width, width * cardProgBox.smoothRatio))

                                    if (root.cfg.playerProgressStyle === "wavy") {
                                        ctx.beginPath()
                                        ctx.lineWidth = 3.5
                                        ctx.lineCap = "round"
                                        ctx.lineJoin = "round"
                                        ctx.strokeStyle = root.m3Pastel

                                        // Волна плавная синусоида без изломов
                                        let amp = mediaCard.isPlaying ? 3.0 : 2.5
                                        let waveLen = 22.0

                                        ctx.moveTo(0, cy)
                                        for (let x = 0; x <= playedW; x += 1.0) {
                                            let taperL = Math.min(1.0, x / 12.0)
                                            let taperR = Math.min(1.0, (playedW - x) / 12.0)
                                            let envelope = Math.sin(taperL * Math.PI / 2) * Math.sin(taperR * Math.PI / 2)
                                            let y = cy + Math.sin((x / waveLen) * 2 * Math.PI - phase) * (amp * envelope)
                                            ctx.lineTo(x, y)
                                        }
                                        ctx.stroke()

                                        if (playedW < width) {
                                            ctx.beginPath()
                                            ctx.lineWidth = 3.5
                                            ctx.lineCap = "round"
                                            ctx.strokeStyle = root.m3SurfaceHighest
                                            ctx.moveTo(Math.min(width, playedW + 4), cy)
                                            ctx.lineTo(width, cy)
                                            ctx.stroke()
                                        }

                                        let pillW = cardProgBox.isSeeking ? 5.5 : 4.5
                                        let pillH = cardProgBox.isSeeking ? 16 : 14
                                        drawDropletPill(ctx, playedW, cy, pillW, pillH, root.m3Pastel)
                                    } else {
                                        ctx.beginPath()
                                        ctx.lineWidth = 5
                                        ctx.lineCap = "round"
                                        ctx.strokeStyle = root.m3SurfaceHighest
                                        ctx.moveTo(3, cy)
                                        ctx.lineTo(width - 3, cy)
                                        ctx.stroke()

                                        if (playedW > 0) {
                                            ctx.beginPath()
                                            ctx.lineWidth = 5
                                            ctx.lineCap = "round"
                                            ctx.strokeStyle = root.m3Pastel
                                            ctx.moveTo(3, cy)
                                            ctx.lineTo(Math.max(3, playedW), cy)
                                            ctx.stroke()

                                            let pillW = cardProgBox.isSeeking ? 6.0 : 5.0
                                            let pillH = cardProgBox.isSeeking ? 16 : 14
                                            drawDropletPill(ctx, playedW, cy, pillW, pillH, root.m3Pastel)
                                        }
                                    }
                                }

                                Connections {
                                    target: cardProgBox
                                    function onSmoothRatioChanged() { cardWaveCanvas.requestPaint() }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function seekTo(mx) {
                                    if (mediaCard.player && mediaCard.trackLen > 0) {
                                        let ratio = Math.max(0, Math.min(1, mx / width))
                                        cardProgBox.smoothRatio = ratio
                                        let targetSec = ratio * mediaCard.trackLen
                                        mediaCard.localPos = targetSec
                                        mediaCard.player.position = targetSec
                                    }
                                }
                                onPressed: m => { cardProgBox.isSeeking = true; seekTo(m.x) }
                                onPositionChanged: m => { if (pressed) seekTo(m.x) }
                                onReleased: cardProgBox.isSeeking = false
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: mediaCard.formatTime(mediaCard.localPos); color: root.cfg.textMuted; font.pixelSize: 10; font.family: root.cfg.fontFamily }
                            Item { Layout.fillWidth: true }
                            Text { text: mediaCard.trackLen > 0 ? mediaCard.formatTime(mediaCard.trackLen) : "--:--"; color: root.cfg.textMuted; font.pixelSize: 10; font.family: root.cfg.fontFamily }
                        }
                    }

                    // Кнопки управления воспроизведением (Круглая Material FAB)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        Item { Layout.fillWidth: true }

                        // Кнопка: Предыдущий трек
                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: prevBtnM.containsMouse ? root.m3SurfaceHighest : "transparent"
                            scale: prevBtnM.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text { anchors.centerIn: parent; text: "󰒮"; color: root.cfg.textPrimary; font.pixelSize: 18 }
                            MouseArea {
                                id: prevBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (mediaCard.player) mediaCard.player.previous() }
                            }
                        }

                        // Кнопка: Play / Pause - круглая Material FAB
                        Rectangle {
                            id: playFab
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 23
                            color: root.m3Pastel
                            scale: playFabM.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            // Векторная плавная иконка Плей с оптической центровкой
                            Canvas {
                                id: sidePlayCanvas
                                anchors.fill: parent
                                opacity: mediaCard.isPlaying ? 0 : 1
                                scale: mediaCard.isPlaying ? 0.4 : 1.0
                                transformOrigin: Item.Center
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                                onPaint: {
                                    let ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    let cx = width / 2
                                    let cy = height / 2
                                    let ox = cx + 1.8 // оптическая компенсация центроида треугольника
                                    let w = 16.0, h = 16.0
                                    let r = 2.8

                                    let x0 = ox - w / 2
                                    let x1 = ox + w / 2
                                    let y0 = cy - h / 2
                                    let y1 = cy + h / 2

                                    let p0 = { x: x0, y: y0 }
                                    let p1 = { x: x1, y: cy }
                                    let p2 = { x: x0, y: y1 }

                                    ctx.fillStyle = root.m3OnPastel
                                    ctx.beginPath()
                                    ctx.moveTo(p0.x, (p0.y + p2.y) / 2)
                                    ctx.arcTo(p0.x, p0.y, p1.x, p1.y, r)
                                    ctx.arcTo(p1.x, p1.y, p2.x, p2.y, r)
                                    ctx.arcTo(p2.x, p2.y, p0.x, p0.y, r)
                                    ctx.closePath()
                                    ctx.fill()
                                }

                                Connections {
                                    target: root
                                    function onM3OnPastelChanged() { sidePlayCanvas.requestPaint() }
                                }
                            }

                            // Векторная плавная иконка Паузы
                            Canvas {
                                id: sidePauseCanvas
                                anchors.fill: parent
                                opacity: mediaCard.isPlaying ? 1 : 0
                                scale: mediaCard.isPlaying ? 1.0 : 0.4
                                transformOrigin: Item.Center
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                                onPaint: {
                                    let ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    let cx = width / 2
                                    let cy = height / 2

                                    ctx.strokeStyle = root.m3OnPastel
                                    ctx.lineWidth = 4.0
                                    ctx.lineCap = "round"

                                    ctx.beginPath()
                                    ctx.moveTo(cx - 5.0, cy - 7.5)
                                    ctx.lineTo(cx - 5.0, cy + 7.5)
                                    ctx.moveTo(cx + 5.0, cy - 7.5)
                                    ctx.lineTo(cx + 5.0, cy + 7.5)
                                    ctx.stroke()
                                }

                                Connections {
                                    target: root
                                    function onM3OnPastelChanged() { sidePauseCanvas.requestPaint() }
                                }
                            }

                            MouseArea {
                                id: playFabM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (mediaCard.player) mediaCard.player.togglePlaying() }
                            }
                        }

                        // Кнопка: Следующий трек
                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 18
                            color: nextBtnM.containsMouse ? root.m3SurfaceHighest : "transparent"
                            scale: nextBtnM.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text { anchors.centerIn: parent; text: "󰒭"; color: root.cfg.textPrimary; font.pixelSize: 18 }
                            MouseArea {
                                id: nextBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (mediaCard.player) mediaCard.player.next() }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                // ================= СОСТОЯНИЕ 2: НЕТ АКТИВНОГО ТРЕКА =================
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    visible: !mediaCard.hasMedia

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: root.m3SurfaceHighest

                        Text {
                            anchors.centerIn: parent
                            text: "󰎆"
                            color: root.m3Pastel
                            font.pixelSize: 22
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Медиаплеер"
                            color: root.cfg.textPrimary
                            font.pixelSize: 13
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }

                        Text {
                            text: "Запустите трек в браузере или плеере"
                            color: root.cfg.textMuted
                            font.pixelSize: 10
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }
        }

        // ================= 5. ХАБ МОНИТОРИНГА СИСТЕМЫ (VITALS BANNER) =================
        Component {
            id: compGauges
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                Layout.preferredHeight: 44
                Layout.fillHeight: false
                radius: 20
                color: root.m3SurfaceContainer
                border.color: root.cfg.borderCol || "#323540"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // CPU
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true
                        Text { text: "󰍛"; color: root.m3Pastel; font.pixelSize: 14 }
                        Text { text: "CPU"; color: root.cfg.textMuted; font.pixelSize: 10; font.bold: true; font.family: root.cfg.fontFamily }
                        Text { text: root.cfg.cpuVal + "%"; color: root.cfg.cpuVal > 80 ? root.cfg.danger : root.cfg.textPrimary; font.pixelSize: 12; font.bold: true; font.family: root.cfg.fontFamily }
                    }

                    Rectangle { width: 1; height: 16; color: root.cfg.borderCol || "#323540" }

                    // RAM
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true
                        Text { text: "󰘚"; color: root.m3Pastel; font.pixelSize: 14 }
                        Text { text: "RAM"; color: root.cfg.textMuted; font.pixelSize: 10; font.bold: true; font.family: root.cfg.fontFamily }
                        Text { text: root.cfg.ramVal + "%"; color: root.cfg.ramVal > 80 ? root.cfg.danger : root.cfg.textPrimary; font.pixelSize: 12; font.bold: true; font.family: root.cfg.fontFamily }
                    }

                    Rectangle { width: 1; height: 16; color: root.cfg.borderCol || "#323540" }

                    // GPU
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true
                        Text { text: "󰢮"; color: root.m3Pastel; font.pixelSize: 14 }
                        Text { text: "GPU"; color: root.cfg.textMuted; font.pixelSize: 10; font.bold: true; font.family: root.cfg.fontFamily }
                        Text { text: root.cfg.gpuVal + "%"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true; font.family: root.cfg.fontFamily }
                    }
                }
            }
        }

        // ================= 6. ЦЕНТР УВЕДОМЛЕНИЙ =================
        Component {
            id: compNotifications
            ColumnLayout {
                id: notifCol
                Layout.fillWidth: true
                implicitHeight: root.cfg.notifications.length === 0 ? 46 : Math.min(420, root.cfg.notifications.length * 58 + 36)
                Layout.preferredHeight: implicitHeight
                spacing: 8

                // Если есть уведомления - показываем заголовок и кнопку очистки
                RowLayout {
                    visible: root.cfg.notifications.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    Layout.fillHeight: false

                    Text {
                        text: "Уведомления (" + root.cfg.notifications.length + ")"
                        color: root.cfg.textMuted
                        font.pixelSize: 12
                        font.bold: true
                        font.family: root.cfg.fontFamily
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 26
                        radius: 13
                        color: clearNotifM.containsMouse ? root.m3SurfaceHighest : root.m3SurfaceVariant
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        scale: clearNotifM.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Очистить"
                            color: root.m3Pastel
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }

                        MouseArea {
                            id: clearNotifM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cfg.clearNotifications()
                        }
                    }
                }

                // Список при наличии уведомлений
                ListView {
                    id: notifListView
                    visible: root.cfg.notifications.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(390, root.cfg.notifications.length * 58)
                    clip: true
                    spacing: 6
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.cfg.notifications

                    Connections {
                        target: root.cfg
                        function onNotificationsChanged() {
                            if (notifListView.count > 0) {
                                notifListView.positionViewAtBeginning()
                            }
                        }
                    }

                    delegate: Rectangle {
                        id: itemRect
                        width: ListView.view.width
                        height: 52
                        radius: 18
                        color: itemMouse.containsMouse ? root.m3SurfaceContainerHigh : root.m3SurfaceContainer
                        border.color: root.cfg.borderCol || "#323540"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 16
                                color: Qt.rgba(root.m3Pastel.r, root.m3Pastel.g, root.m3Pastel.b, 0.14)
                                border.color: Qt.rgba(root.m3Pastel.r, root.m3Pastel.g, root.m3Pastel.b, 0.25)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        let a = (modelData.app || "").toLowerCase()
                                        if (a.includes("telegram")) return "󰒱"
                                        if (a.includes("discord") || a.includes("vesktop")) return "󰙯"
                                        if (a.includes("firefox") || a.includes("chrome") || a.includes("browser")) return "󰈹"
                                        if (a.includes("spotify")) return "󰓇"
                                        if (a.includes("steam")) return "󰓓"
                                        return "󰂚"
                                    }
                                    color: root.m3Pastel
                                    font.pixelSize: 14
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: {
                                            let t = modelData.title || modelData.summary || ""
                                            let a = modelData.app || ""
                                            if (a && t) return a + " • " + t
                                            if (t) return t
                                            if (a) return a
                                            return "Уведомление"
                                        }
                                        color: root.cfg.textPrimary
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.cfg.fontFamily
                                    }
                                    Text { 
                                        text: modelData.time || ""
                                        color: root.cfg.textMuted
                                        font.pixelSize: 9
                                        font.family: root.cfg.fontFamily 
                                    }
                                }

                                Text { 
                                    text: modelData.body || ""
                                    color: root.cfg.textMuted
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.family: root.cfg.fontFamily 
                                    visible: (modelData.body && modelData.body.length > 0)
                                }
                            }

                            // Кнопка быстрого закрытия отдельного уведомления
                            Rectangle {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 11
                                color: closeItemM.containsMouse ? root.m3SurfaceVariant : "transparent"
                                visible: itemMouse.containsMouse

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: root.cfg.textMuted
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: closeItemM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cfg.removeNotification(index)
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }

                // Компактная карточка при отсутствии уведомлений (вместо пустой зоны)
                Rectangle {
                    visible: root.cfg.notifications.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 20
                    color: root.m3SurfaceContainer
                    border.color: root.cfg.borderCol || "#323540"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "󰂚"; color: root.cfg.textMuted; font.pixelSize: 15 }
                        Text { text: "Все чисто • Нет новых уведомлений"; color: root.cfg.textMuted; font.pixelSize: 11; font.family: root.cfg.fontFamily }
                    }
                }
            }
        }

        // ================= 7. M3 TONAL ПАНЕЛЬ СЕССИИ (ACTION PILLS) =================
        Component {
            id: compPower
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                Layout.preferredHeight: 44
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    // 1. Блокировка
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20
                        color: lockBtnM.pressed ? Qt.darker("#33353d", 1.1) : (lockBtnM.containsMouse ? Qt.lighter("#33353d", 1.25) : "#33353d")
                        border.color: "#424552"
                        border.width: 1
                        scale: lockBtnM.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text { text: "󰌾"; color: root.cfg.textPrimary; font.pixelSize: 14 }
                            Text { text: "Блок"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                        }

                        MouseArea {
                            id: lockBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.closeRequested()
                                root.cfg.lock()
                            }
                        }
                    }

                    // 2. Выход из системы
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20
                        color: exitBtnM.pressed ? Qt.darker("#33353d", 1.1) : (exitBtnM.containsMouse ? Qt.lighter("#33353d", 1.25) : "#33353d")
                        border.color: "#424552"
                        border.width: 1
                        scale: exitBtnM.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text { text: "󰍃"; color: root.cfg.textPrimary; font.pixelSize: 14 }
                            Text { text: "Выход"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                        }

                        MouseArea {
                            id: exitBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.closeRequested()
                                sysCmdProc.exec(["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"])
                            }
                        }
                    }

                    // 3. Перезагрузка
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20
                        color: rebootBtnM.pressed ? Qt.darker("#33353d", 1.1) : (rebootBtnM.containsMouse ? Qt.lighter("#33353d", 1.25) : "#33353d")
                        border.color: "#424552"
                        border.width: 1
                        scale: rebootBtnM.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text { text: "󰜉"; color: root.cfg.textPrimary; font.pixelSize: 14 }
                            Text { text: "Ребут"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                        }

                        MouseArea {
                            id: rebootBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.closeRequested()
                                sysCmdProc.exec(["sh", "-c", "systemctl reboot || loginctl reboot"])
                            }
                        }
                    }

                    // 4. Выключение
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 20
                        color: pwrBtnM.pressed ? "#d65d7a" : (pwrBtnM.containsMouse ? "#f38ba8" : Qt.rgba(0.95, 0.54, 0.66, 0.20))
                        border.color: Qt.rgba(0.95, 0.54, 0.66, 0.45)
                        border.width: 1
                        scale: pwrBtnM.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text { text: "󰐥"; color: pwrBtnM.containsMouse ? "#1a1c22" : "#f38ba8"; font.pixelSize: 14 }
                            Text { text: "Выкл"; color: pwrBtnM.containsMouse ? "#1a1c22" : "#f38ba8"; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                        }

                        MouseArea {
                            id: pwrBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.closeRequested()
                                sysCmdProc.exec(["sh", "-c", "systemctl poweroff || loginctl poweroff"])
                            }
                        }
                    }
                }
            }
        }
    }
}
