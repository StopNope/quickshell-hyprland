import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import "."

Item {
    id: root

    required property var cfg
    property bool isPrimaryScreen: true
    signal unlockRequested()

    property bool wrongPass: false
    property bool isAuthenticating: false
    property string authMessage: ""
    property string lockWallpaperPath: ""

    Process {
        id: wpReader
        command: ["sh", "-c", "grep -E '^wallpaper\\s*=' ~/.config/waypaper/config.ini 2>/dev/null | head -n1 | cut -d'=' -f2 | xargs -I{} echo -n {}"]
        stdout: (data) => {
            let p = data.trim()
            if (p.startsWith('~')) p = (Quickshell.env('HOME') || '/home/stopnope') + p.slice(1)
            if (p.length > 0) root.lockWallpaperPath = 'file://' + p
            else root.lockWallpaperPath = 'file://' + (Quickshell.env('HOME') || '/home/stopnope') + '/wallpaper/default.jpg'
        }
    }

    // Размытый фон текущих обоев в стиле Pixel & Caelestia
    Item {
        anchors.fill: parent

        Image {
            id: bgWallpaper
            anchors.fill: parent
            source: root.lockWallpaperPath
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.85
                blurMax: 64
                brightness: -0.22
                saturation: 0.25
            }
        }

        // Тональный акцентный слой поверх обоев
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.cfg.bgPrimary.r, root.cfg.bgPrimary.g, root.cfg.bgPrimary.b, bgWallpaper.visible ? 0.74 : 0.92)
        }
    }

    // ================= PAM СИСТЕМНАЯ АУТЕНТИФИКАЦИЯ =================
    PamContext {
        id: pam
        config: "hyprlock"
        user: Quickshell.env("USER") || "stopnope"

        onCompleted: (result) => {
            root.isAuthenticating = false
            if (result === PamResult.Success) {
                root.wrongPass = false
                root.authMessage = ""
                pinInput.text = ""
                root.unlockRequested()
                root.cfg.isLocked = false
            } else {
                root.wrongPass = true
                root.authMessage = "Неверный пароль"
                pinInput.text = ""
                shakeTimer.restart()
                pam.start()
            }
        }

        onError: (err) => {
            root.isAuthenticating = false
            root.wrongPass = true
            root.authMessage = "Ошибка PAM: " + PamError.toString(err)
            shakeTimer.restart()
            pam.start()
        }
    }

    Process {
        id: switchLangLock
        command: ["sh", "-c", "hyprctl switchxkblayout all next"]
    }

    function grabInputFocus() {
        pinInput.forceActiveFocus()
    }

    Component.onCompleted: {
        grabInputFocus()
        wpReader.running = true
        if (root.cfg.isLocked) pam.start()
    }

    Connections {
        target: root.cfg
        function onIsLockedChanged() {
            if (root.cfg.isLocked) {
                wpReader.running = true
                pinInput.text = ""
                root.wrongPass = false
                root.isAuthenticating = false
                root.authMessage = ""
                pam.start()
                pinInput.forceActiveFocus()
            } else {
                pam.abort()
            }
        }
    }

    // Клик в любое место переводит фокус в поле ввода
    MouseArea {
        anchors.fill: parent
        onClicked: pinInput.forceActiveFocus()
    }

    // Скрытый нативный ввод
    TextInput {
        id: pinInput
        opacity: 0
        width: 1
        height: 1
        focus: true
        echoMode: TextInput.Password
        onTextChanged: {
            if (text.length > 0) {
                root.wrongPass = false
                root.authMessage = ""
            }
        }
        Keys.onReturnPressed: root.tryUnlock()
        Keys.onEnterPressed: root.tryUnlock()
        Keys.onEscapePressed: {
            pinInput.text = ""
            root.wrongPass = false
            root.authMessage = ""
        }
    }

    function tryUnlock() {
        if (pinInput.text.length === 0 || root.isAuthenticating) return

        // Запасной PIN
        if (root.cfg.lockPin && pinInput.text === root.cfg.lockPin) {
            pinInput.text = ""
            root.wrongPass = false
            root.authMessage = ""
            root.unlockRequested()
            root.cfg.isLocked = false
            return
        }

        root.isAuthenticating = true
        root.authMessage = "Проверка..."

        if (pam.responseRequired) {
            pam.respond(pinInput.text)
        } else {
            pam.start()
            pamTimer.restart()
        }
    }

    Timer {
        id: pamTimer
        interval: 150
        onTriggered: {
            if (pam.responseRequired && root.isAuthenticating) {
                pam.respond(pinInput.text)
            }
        }
    }

    Timer {
        id: shakeTimer
        interval: 1200
        onTriggered: {
            root.wrongPass = false
            root.authMessage = ""
        }
    }

    // Анимация тряски при ошибке
    property real shakeOffset: 0
    SequentialAnimation {
        id: shakeAnim
        running: root.wrongPass
        loops: 1
        NumberAnimation { target: root; property: "shakeOffset"; to: -12; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 12; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 40; easing.type: Easing.OutQuad }
    }

    // ================= 1. ВЕРХНИЙ СТАТУС БАР (Status Pill) =================
    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 28
        spacing: 12

        // Индикатор хоста/дистрибутива
        Rectangle {
            height: 32
            radius: 16
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.outlineVariant
            border.width: 1
            implicitWidth: hostRow.implicitWidth + 24

            RowLayout {
                id: hostRow
                anchors.centerIn: parent
                spacing: 8
                Text { text: "󰌽"; color: root.cfg.accent; font.pixelSize: 13 }
                Text { text: "Gentoo Linux"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
            }
        }

        Item { Layout.fillWidth: true }

        // Правые статус-чипы (Сеть, Звук, Раскладка)
        RowLayout {
            spacing: 8

            Rectangle {
                height: 32
                radius: 16
                color: root.cfg.surfaceContainerHigh
                border.color: root.cfg.outlineVariant
                border.width: 1
                implicitWidth: statusRow.implicitWidth + 24

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 10

                    Text { text: "󰤨"; color: root.cfg.accent; font.pixelSize: 13 }
                    Rectangle { width: 1; height: 14; color: root.cfg.outlineVariant }
                    Text { text: root.cfg.isMuted ? "󰝟" : "󰕾 " + root.cfg.currentVolume + "%"; color: root.cfg.textMuted; font.pixelSize: 11; font.family: root.cfg.fontFamily }
                    Rectangle { width: 1; height: 14; color: root.cfg.outlineVariant }
                    Text { text: root.cfg.currentLang; color: root.cfg.accent; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        switchLangLock.running = true
                        pinInput.forceActiveFocus()
                    }
                }
            }
        }
    }

    // ================= 2. ОСНОВНОЙ ТРЕХКОЛОНОЧНЫЙ ХОЛСТ (Pixel + Caelestia) =================
    RowLayout {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.shakeOffset
        width: Math.min(parent.width - 64, 1160)
        spacing: 36

        // ----------------- ЛЕВАЯ КОЛОНКА: МЕДИАПЛЕЕР -----------------
        Item {
            Layout.preferredWidth: 320
            Layout.preferredHeight: 380
            visible: root.isPrimaryScreen

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: root.cfg.surfaceContainer
                border.color: root.cfg.outlineVariant
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // Заголовок медиа
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "󰎈"; color: root.cfg.accent; font.pixelSize: 14 }
                        Text { text: "Сейчас играет"; color: root.cfg.onSurfaceVariant; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: root.cfg.accent
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 900 }
                                NumberAnimation { to: 1.0; duration: 900 }
                            }
                        }
                    }

                    // Обложка трека в органической форме
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 160
                        radius: 24
                        color: root.cfg.surfaceContainerHigh
                        border.color: root.cfg.outlineVariant
                        border.width: 1
                        clip: true

                        Image {
                            id: lockMediaCover
                            anchors.fill: parent
                            source: root.cfg.mediaCover || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !lockMediaCover.visible
                            text: "󰎈"
                            font.pixelSize: 54
                            color: root.cfg.primaryContainer
                        }
                    }

                    // Название и артист
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.cfg.mediaTitle || "Нет активного трека"
                            color: root.cfg.textPrimary
                            font.pixelSize: 13
                            font.bold: true
                            font.family: root.cfg.fontFamily
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.cfg.mediaArtist || "Запустите плеер"
                            color: root.cfg.textMuted
                            font.pixelSize: 11
                            font.family: root.cfg.fontFamily
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Кнопки управления плеером (Material 3 Pills)
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        // Prev
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: prevM.containsMouse ? root.cfg.surfaceContainerHighest : root.cfg.surfaceContainerHigh
                            border.color: root.cfg.outlineVariant; border.width: 1
                            Text { anchors.centerIn: parent; text: "󰒮"; color: root.cfg.textPrimary; font.pixelSize: 13 }
                            MouseArea {
                                id: prevM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.cfg.mediaPrev()
                            }
                        }

                        // Play/Pause (Акцентный Squircle / Blossom)
                        Rectangle {
                            width: 48; height: 48; radius: 24
                            color: root.cfg.accent
                            Text {
                                anchors.centerIn: parent
                                text: root.cfg.mediaPlaying ? "󰏤" : "󰐊"
                                color: root.cfg.accentText
                                font.pixelSize: 18
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.cfg.mediaToggle()
                            }
                        }

                        // Next
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: nextM.containsMouse ? root.cfg.surfaceContainerHighest : root.cfg.surfaceContainerHigh
                            border.color: root.cfg.outlineVariant; border.width: 1
                            Text { anchors.centerIn: parent; text: "󰒭"; color: root.cfg.textPrimary; font.pixelSize: 13 }
                            MouseArea {
                                id: nextM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.cfg.mediaNext()
                            }
                        }
                    }
                }
            }
        }

        // ----------------- ЦЕНТРАЛЬНАЯ КОЛОНКА: PIXEL ЧАСЫ + ПАРОЛЬ -----------------
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 380
            spacing: 20

            // Фирменные двухстрочные часы Pixel / Material You
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: -8

                Text {
                    id: hourTxt
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(new Date(), "hh")
                    color: root.cfg.textPrimary
                    font.pixelSize: 94
                    font.weight: Font.Black
                    font.family: "Fredoka"
                }

                Text {
                    id: minTxt
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(new Date(), "mm")
                    color: root.cfg.accent
                    font.pixelSize: 94
                    font.weight: Font.Black
                    font.family: "Fredoka"
                }

                Timer {
                    interval: 1000
                    running: root.cfg.isLocked
                    repeat: true
                    onTriggered: {
                        hourTxt.text = Qt.formatDateTime(new Date(), "hh")
                        minTxt.text = Qt.formatDateTime(new Date(), "mm")
                    }
                }
            }

            // Органический чип: Дата + Погода (Pixel Pill)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                height: 34
                implicitWidth: dateRow.implicitWidth + 28
                radius: 17
                color: root.cfg.surfaceContainerHigh
                border.color: root.cfg.outlineVariant
                border.width: 1

                RowLayout {
                    id: dateRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: Qt.formatDateTime(new Date(), "d MMMM, dddd")
                        color: root.cfg.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                        font.family: root.cfg.fontFamily
                    }

                    Rectangle { width: 1; height: 12; color: root.cfg.outlineVariant }

                    RowLayout {
                        spacing: 4
                        Text { text: root.cfg.weatherIcon || "󰖐"; color: root.cfg.accent; font.pixelSize: 12 }
                        Text { text: root.cfg.weatherText; color: root.cfg.accent; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                        Text { text: root.cfg.weatherCity; color: root.cfg.textMuted; font.pixelSize: 10; font.family: root.cfg.fontFamily }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cfg.refreshWeather()
                }
            }

            // Аватарка и имя пользователя
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Layout.topMargin: 6

                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: root.cfg.primaryContainer
                    border.color: root.cfg.accent
                    border.width: 1.5
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: (root.cfg.avatarPath && root.cfg.avatarPath !== "") ? ("file://" + root.cfg.avatarPath) : ""
                        fillMode: Image.PreserveAspectCrop
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰀉"
                        color: root.cfg.accentText
                        font.pixelSize: 18
                    }
                }

                Text {
                    text: Quickshell.env("USER") || "StopNope"
                    color: root.cfg.textPrimary
                    font.pixelSize: 14
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }

            // Поле ввода пароля (Вложенная капсула Android 15)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 350
                Layout.preferredHeight: 52
                radius: 26
                color: root.cfg.surfaceContainerHighest
                border.color: root.wrongPass
                              ? root.cfg.danger
                              : (root.isAuthenticating
                                 ? root.cfg.accent
                                 : (pinInput.text.length > 0 ? root.cfg.accent : root.cfg.outlineVariant))
                border.width: root.wrongPass || pinInput.text.length > 0 || root.isAuthenticating ? 2 : 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: 10

                    // Иконка замка
                    Text {
                        text: root.wrongPass ? "󰅖" : (root.isAuthenticating ? "󰑐" : "󰌾")
                        color: root.wrongPass ? root.cfg.danger : (root.isAuthenticating ? root.cfg.accent : root.cfg.textMuted)
                        font.pixelSize: 18
                    }

                    // Точки ввода или подсказка
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (root.authMessage !== "") return root.authMessage
                            if (pinInput.text.length > 0) return "● ".repeat(pinInput.text.length).trim()
                            return "Введите системный пароль..."
                        }
                        color: root.wrongPass ? root.cfg.danger : (pinInput.text.length > 0 ? root.cfg.accent : root.cfg.textMuted)
                        font.pixelSize: pinInput.text.length > 0 && root.authMessage === "" ? 15 : 12
                        font.bold: pinInput.text.length > 0
                        font.family: root.cfg.fontFamily
                        elide: Text.ElideRight
                    }

                    // Кнопка разблокировки
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 18
                        color: pinInput.text.length > 0 ? root.cfg.accent : root.cfg.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰁔"
                            color: pinInput.text.length > 0 ? root.cfg.accentText : root.cfg.textMuted
                            font.pixelSize: 16
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: pinInput.text.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.tryUnlock()
                        }
                    }
                }
            }
        }

        // ----------------- ПРАВАЯ КОЛОНКА: РЕСУРСЫ СИСТЕМЫ -----------------
        Item {
            Layout.preferredWidth: 320
            Layout.preferredHeight: 380
            visible: root.isPrimaryScreen

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: root.cfg.surfaceContainer
                border.color: root.cfg.outlineVariant
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "󰍛"; color: root.cfg.accent; font.pixelSize: 14 }
                        Text { text: "Ресурсы системы"; color: root.cfg.onSurfaceVariant; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                    }

                    // CPU Карточка
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: 18
                        color: root.cfg.surfaceContainerHigh
                        border.color: root.cfg.outlineVariant
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Процессор (CPU)"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                                Item { Layout.fillWidth: true }
                                Text { text: root.cfg.cpuVal + "%"; color: root.cfg.accent; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                            }

                            // Толстая капсула прогресса
                            Rectangle {
                                Layout.fillWidth: true
                                height: 10
                                radius: 5
                                color: root.cfg.surfaceContainerLowest

                                Rectangle {
                                    height: parent.height
                                    width: Math.max(10, parent.width * (root.cfg.cpuVal / 100))
                                    radius: 5
                                    color: root.cfg.accent
                                }
                            }
                        }
                    }

                    // RAM Карточка
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: 18
                        color: root.cfg.surfaceContainerHigh
                        border.color: root.cfg.outlineVariant
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Память (RAM)"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                                Item { Layout.fillWidth: true }
                                Text { text: root.cfg.ramVal + "%"; color: root.cfg.accent; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 10
                                radius: 5
                                color: root.cfg.surfaceContainerLowest

                                Rectangle {
                                    height: parent.height
                                    width: Math.max(10, parent.width * (root.cfg.ramVal / 100))
                                    radius: 5
                                    color: root.cfg.accent
                                }
                            }
                        }
                    }

                    // GPU Карточка
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: 18
                        color: root.cfg.surfaceContainerHigh
                        border.color: root.cfg.outlineVariant
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Видеокарта (GPU)"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                                Item { Layout.fillWidth: true }
                                Text { text: root.cfg.gpuVal + "%"; color: root.cfg.accent; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 10
                                radius: 5
                                color: root.cfg.surfaceContainerLowest

                                Rectangle {
                                    height: parent.height
                                    width: Math.max(10, parent.width * (root.cfg.gpuVal / 100))
                                    radius: 5
                                    color: root.cfg.accent
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // ================= 3. НИЖНЯЯ ПАНЕЛЬ ПИТАНИЯ (Floating Pill) =================
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 32
        height: 42
        implicitWidth: powerRow.implicitWidth + 24
        radius: 21
        color: root.cfg.surfaceContainerHigh
        border.color: root.cfg.outlineVariant
        border.width: 1

        Process { id: lockPowerProc }

        RowLayout {
            id: powerRow
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: [
                    { icon: "󰒲", label: "Сон", cmd: "systemctl suspend || loginctl suspend" },
                    { icon: "󰜉", label: "Перезагрузка", cmd: "systemctl reboot || loginctl reboot" },
                    { icon: "󰐥", label: "Выключение", cmd: "systemctl poweroff || loginctl poweroff" }
                ]

                Rectangle {
                    required property var modelData
                    height: 30
                    implicitWidth: pItemRow.implicitWidth + 16
                    radius: 15
                    color: pMouse.containsMouse ? root.cfg.surfaceContainerHighest : "transparent"

                    RowLayout {
                        id: pItemRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: modelData.icon; color: root.cfg.accent; font.pixelSize: 13 }
                        Text { text: modelData.label; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }
                    }

                    MouseArea {
                        id: pMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            lockPowerProc.command = ["sh", "-c", modelData.cmd]
                            lockPowerProc.running = true
                        }
                    }
                }
            }
        }
    }
}
