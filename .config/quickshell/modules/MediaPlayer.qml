import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Rectangle {
    antialiasing: true
    id: root

    required property var cfg

    // Доступные плееры через MPRIS
    readonly property var players: Mpris.players.values || []
    property int selectedIndex: 0

    // Текущий активный плеер (предпочитаем тот, который воспроизводит)
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

    // Форматирование секунд в mm:ss
    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec <= 0) return "00:00"
        let s = Math.floor(sec)
        let m = Math.floor(s / 60)
        let remSec = s % 60
        let mStr = (m < 10 ? "0" : "") + m
        let sStr = (remSec < 10 ? "0" : "") + remSec
        return mStr + ":" + sStr
    }

    // Определение сервиса (Яндекс Музыка, Spotify, SoundCloud, Браузер)
    readonly property var serviceInfo: {
        if (!player) return { name: "Медиаплеер", icon: "󰎆" }
        let idLower = (player.identity || "").toLowerCase()
        let titleLower = (player.trackTitle || "").toLowerCase()

        if (idLower.includes("spotify")) {
            return { name: "Spotify", icon: "󰓇" }
        } else if (idLower.includes("firefox") || idLower.includes("chrome") || idLower.includes("chromium") || idLower.includes("brave")) {
            if (titleLower.includes("yandex") || titleLower.includes("ядекс") || titleLower.includes("яндекс")) {
                return { name: "Яндекс Музыка", icon: "󰎆" }
            } else if (titleLower.includes("soundcloud")) {
                return { name: "SoundCloud", icon: "󰎆" }
            } else if (titleLower.includes("vk") || titleLower.includes("вконтакте")) {
                return { name: "VK Музыка", icon: "󰎆" }
            } else if (titleLower.includes("youtube")) {
                return { name: "YouTube Music", icon: "󰗃" }
            }
            return { name: "Браузер (Яндекс / SC)", icon: "󰈹" }
        }
        return { name: player.identity || "Медиа", icon: "󰎆" }
    }

    // Локальное время для плавной анимации прогресс-бара
    property real localPos: player ? player.position : 0
    property real trackLen: (player && player.length > 0) ? player.length : 0

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            if (root.player) root.localPos = root.player.position
        }
    }

    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.player && root.player.isPlaying) {
                if (root.trackLen > 0 && root.localPos < root.trackLen) {
                    root.localPos += 1
                } else if (root.trackLen <= 0) {
                    root.localPos += 1
                }
            }
        }
    }

    Layout.fillWidth: true
    Layout.preferredHeight: root.hasMedia ? 168 : 74
    Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    implicitHeight: root.hasMedia ? 168 : 74
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    radius: 28
    gradient: Gradient {
        GradientStop {
            position: 0.0
            color: root.cfg.surfaceContainerHigh || root.cfg.bgElevated
        }
        GradientStop {
            position: 1.0
            color: root.cfg.surfaceContainer || root.cfg.bgPrimary
        }
    }
    border.color: root.cfg.outlineVariant || root.cfg.borderCol || "#323540"
    border.width: 1
    clip: true

    // ================= СОСТОЯНИЕ 1: АКТИВНЫЙ ТРЕК =================
    Item {
        anchors.fill: parent
        visible: root.hasMedia

        // Фоновый мягкий оттенок обложки
        Image {
            id: bgCoverArt
            anchors.fill: parent
            source: root.player ? (root.player.trackArtUrl || "") : ""
            fillMode: Image.PreserveAspectCrop
            opacity: 0.12
            visible: status === Image.Ready
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // 1. Верхний ряд: Обложка трека + Название + Исполнитель + Кнопка стиля волны
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Квадратная обложка альбома со скруглением
                Rectangle {
                    antialiasing: true
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: 16
                    color: root.cfg.bgElevated
                    clip: true

                    Image {
                        id: coverArt
                        anchors.fill: parent
                        source: root.player ? (root.player.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: coverArt.status !== Image.Ready
                        text: "󰎆"
                        color: root.cfg.accent
                        font.pixelSize: 22
                    }
                }

                // Метаданные трека
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: (root.player && root.player.trackTitle) ? root.player.trackTitle : "Неизвестный трек"
                        color: root.cfg.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                        font.family: root.cfg.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            if (!root.player) return "Неизвестен"
                            if (root.player.trackArtist) return root.player.trackArtist
                            if (root.player.trackArtists) return root.player.trackArtists
                            return "Исполнитель"
                        }
                        color: root.cfg.textMuted
                        font.pixelSize: 11
                        font.family: root.cfg.fontFamily
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Чип источника
                    RowLayout {
                        spacing: 4
                        Text {
                            text: root.serviceInfo.icon
                            color: root.cfg.accent
                            font.pixelSize: 11
                        }
                        Text {
                            text: root.serviceInfo.name
                            color: root.cfg.accent
                            font.pixelSize: 9
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }
                }

                // Кнопка быстрого переключения стиля полосы: Волна / Обычная
                Rectangle {
                    antialiasing: true
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: waveToggleM.containsMouse ? root.cfg.bgElevated : "transparent"
                    border.color: root.cfg.borderCol
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.cfg.playerProgressStyle === "wavy" ? "󰤽" : "󰇄"
                        color: root.cfg.accent
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: waveToggleM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cfg.playerProgressStyle = (root.cfg.playerProgressStyle === "wavy") ? "flat" : "wavy"
                            root.cfg.save()
                        }
                    }
                }

                // Кнопка переключения плееров (если их > 1)
                Rectangle {
                    antialiasing: true
                    visible: root.players.length > 1
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: pSwitchM.containsMouse ? root.cfg.bgElevated : "transparent"
                    border.color: root.cfg.borderCol
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        color: root.cfg.textMuted
                        font.pixelSize: 11
                        rotation: 90
                    }

                    MouseArea {
                        id: pSwitchM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = (root.selectedIndex + 1) % root.players.length
                        }
                    }
                }
            }

            // 2. Интерактивная полоса прогресса (Wavy Sine Wave или Classic Flat Pill)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Item {
                    id: progressContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18

                    readonly property real progressRatio: (root.trackLen > 0) ? Math.max(0, Math.min(1, root.localPos / root.trackLen)) : 0
                    property bool isSeeking: false
                    property real smoothRatio: progressRatio

                    Behavior on smoothRatio {
                        enabled: !progressContainer.isSeeking && root.isPlaying
                        NumberAnimation {
                            duration: 950
                            easing.type: Easing.Linear
                        }
                    }

                    onProgressRatioChanged: {
                        if (progressContainer.isSeeking || Math.abs(smoothRatio - progressRatio) > 0.04) {
                            smoothRatio = progressRatio
                        } else {
                            smoothRatio = progressRatio
                        }
                    }

                    Canvas {
                        antialiasing: true
                        id: waveCanvas
                        anchors.fill: parent
                        property real phase: 0
                        onPhaseChanged: requestPaint()

                        NumberAnimation {
                            target: waveCanvas
                            property: "phase"
                            from: 0
                            to: 2 * Math.PI
                            duration: 1800
                            loops: Animation.Infinite
                            running: root.isPlaying && root.cfg.playerProgressStyle === "wavy"
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
                            let playedW = Math.max(0, Math.min(width, width * progressContainer.smoothRatio))

                            if (root.cfg.playerProgressStyle === "wavy") {
                                // 1. Волнообразная воспроизведенная часть (Material You Squiggly Wave)
                                ctx.beginPath()
                                ctx.lineWidth = 3.5
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.strokeStyle = root.cfg.accent

                                let amp = root.isPlaying ? 3.0 : 0.0
                                let waveLen = 14.0

                                ctx.moveTo(0, cy)
                                for (let x = 0; x <= playedW; x += 1.5) {
                                    // Плавное затухание амплитуды у краев (Envelope Tapering)
                                    let taperL = Math.min(1.0, x / 14.0)
                                    let taperR = Math.min(1.0, (playedW - x) / 14.0)
                                    let envelope = Math.sin(taperL * Math.PI / 2) * Math.sin(taperR * Math.PI / 2)
                                    let y = cy + Math.sin((x / waveLen) * 2 * Math.PI - phase) * (amp * envelope)
                                    ctx.lineTo(x, y)
                                }
                                ctx.stroke()

                                // 2. Невоспроизведенная часть (прямая спокойная линия)
                                if (playedW < width) {
                                    ctx.beginPath()
                                    ctx.lineWidth = 3.5
                                    ctx.lineCap = "round"
                                    ctx.strokeStyle = root.cfg.bgElevated
                                    ctx.moveTo(Math.min(width, playedW + 4), cy)
                                    ctx.lineTo(width, cy)
                                    ctx.stroke()
                                }

                                // 3. Бегунок (Капелька - вертикальная закругленная полосочка)
                                if (playedW >= 0 && playedW <= width) {
                                    let pillW = progressContainer.isSeeking ? 5.5 : 4.5
                                    let pillH = progressContainer.isSeeking ? 16 : 14
                                    drawDropletPill(ctx, playedW, cy, pillW, pillH, root.cfg.accent)
                                }
                            } else {
                                // Обычная плавная полоса Material You
                                ctx.beginPath()
                                ctx.lineWidth = 5
                                ctx.lineCap = "round"
                                ctx.strokeStyle = root.cfg.bgElevated
                                ctx.moveTo(3, cy)
                                ctx.lineTo(width - 3, cy)
                                ctx.stroke()

                                if (playedW > 0) {
                                    ctx.beginPath()
                                    ctx.lineWidth = 5
                                    ctx.lineCap = "round"
                                    ctx.strokeStyle = root.cfg.accent
                                    ctx.moveTo(3, cy)
                                    ctx.lineTo(Math.max(3, playedW), cy)
                                    ctx.stroke()

                                    let pillW = progressContainer.isSeeking ? 6.0 : 5.0
                                    let pillH = progressContainer.isSeeking ? 16 : 14
                                    drawDropletPill(ctx, playedW, cy, pillW, pillH, root.cfg.accent)
                                }
                            }
                        }

                        Connections {
                            target: progressContainer
                            function onSmoothRatioChanged() { waveCanvas.requestPaint() }
                        }

                        Connections {
                            target: root.cfg
                            function onPlayerProgressStyleChanged() { waveCanvas.requestPaint() }
                            function onAccentChanged() { waveCanvas.requestPaint() }
                        }
                    }

                    // Интерактивная перемотка кликом и перетаскиванием
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function seekTo(mx) {
                            if (root.player && root.trackLen > 0) {
                                let ratio = Math.max(0, Math.min(1, mx / width))
                                progressContainer.smoothRatio = ratio
                                let targetSec = ratio * root.trackLen
                                root.localPos = targetSec
                                root.player.position = targetSec
                            }
                        }
                        onPressed: m => {
                            progressContainer.isSeeking = true
                            seekTo(m.x)
                        }
                        onPositionChanged: m => { if (pressed) seekTo(m.x) }
                        onReleased: progressContainer.isSeeking = false
                    }
                }

                // Метки времени
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.formatTime(root.localPos)
                        color: root.cfg.textMuted
                        font.pixelSize: 10
                        font.family: root.cfg.fontFamily
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.trackLen > 0 ? root.formatTime(root.trackLen) : "--:--"
                        color: root.cfg.textMuted
                        font.pixelSize: 10
                        font.family: root.cfg.fontFamily
                    }
                }
            }

            // 3. Блок управления воспроизведением (Точно отцентрован, без квадрата остановки)
            RowLayout {
                Layout.fillWidth: true
                spacing: 28

                Item { Layout.fillWidth: true } // Левый гибкий центрирующий спейсер

                // Кнопка: Предыдущий трек
                Rectangle {
                    antialiasing: true
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: prevM.containsMouse ? root.cfg.bgElevated : "transparent"
                    scale: prevM.pressed ? 0.90 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        color: root.cfg.textPrimary
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: prevM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.player) root.player.previous() }
                    }
                }

                // Кнопка: Плей / Пауза (Плавный Material You морфинг и кроссфейд)
                Item {
                    id: playBtnBox
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    scale: playM.pressed ? 0.88 : (root.isPlaying ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    MaterialShape {
                        anchors.fill: parent
                        color: root.cfg.accent
                        shape: (root.cfg.activeShapeStyle === "blossom" && root.isPlaying) ? "blossom" : "circle"
                    }

                    // Векторная плавная иконка Плей (Строго центрированный скругленный треугольник)
                    Canvas {
                        antialiasing: true
                        id: playVectorCanvas
                        anchors.fill: parent
                        opacity: root.isPlaying ? 0 : 1
                        scale: root.isPlaying ? 0.4 : 1.0
                        transformOrigin: Item.Center
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                        onPaint: {
                            let ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            let cx = width / 2
                            let cy = height / 2

                            ctx.fillStyle = root.cfg.accentText
                            ctx.beginPath()
                            // Оптически сбалансированный треугольник воспроизведения
                            let r = 2.5
                            let x0 = cx - 5.5, y0 = cy - 9.0
                            let x1 = cx + 8.5, y1 = cy
                            let x2 = cx - 5.5, y2 = cy + 9.0
                            ctx.moveTo(x0 + r, y0)
                            ctx.arcTo(x1, y1, x2, y2, r)
                            ctx.arcTo(x2, y2, x0, y0, r)
                            ctx.arcTo(x0, y0, x1, y1, r)
                            ctx.closePath()
                            ctx.fill()
                        }

                        Connections {
                            target: root.cfg
                            function onAccentTextChanged() { playVectorCanvas.requestPaint() }
                        }
                    }

                    // Векторная плавная иконка Паузы (Две скругленные полосы Material You)
                    Canvas {
                        antialiasing: true
                        id: pauseVectorCanvas
                        anchors.fill: parent
                        opacity: root.isPlaying ? 1 : 0
                        scale: root.isPlaying ? 1.0 : 0.4
                        transformOrigin: Item.Center
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                        onPaint: {
                            let ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            let cx = width / 2
                            let cy = height / 2

                            ctx.strokeStyle = root.cfg.accentText
                            ctx.lineWidth = 4.5
                            ctx.lineCap = "round"

                            ctx.beginPath()
                            // Левая полоса
                            ctx.moveTo(cx - 5.5, cy - 8.0)
                            ctx.lineTo(cx - 5.5, cy + 8.0)
                            // Правая полоса
                            ctx.moveTo(cx + 5.5, cy - 8.0)
                            ctx.lineTo(cx + 5.5, cy + 8.0)
                            ctx.stroke()
                        }

                        Connections {
                            target: root.cfg
                            function onAccentTextChanged() { pauseVectorCanvas.requestPaint() }
                        }
                    }

                    MouseArea {
                        id: playM
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player) root.player.togglePlaying()
                        }
                    }
                }

                // Кнопка: Следующий трек
                Rectangle {
                    antialiasing: true
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: nextM.containsMouse ? root.cfg.bgElevated : "transparent"
                    scale: nextM.pressed ? 0.90 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        color: root.cfg.textPrimary
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: nextM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.player) root.player.next() }
                    }
                }

                Item { Layout.fillWidth: true } // Правый гибкий центрирующий спейсер
            }
        }
    }

    // ================= СОСТОЯНИЕ 2: НЕТ АКТИВНОГО ТРЕКА =================
    Item {
        anchors.fill: parent
        visible: !root.hasMedia

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
                antialiasing: true
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 24
                color: root.cfg.bgElevated

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: root.cfg.accent
                    font.pixelSize: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: "Медиаплеер"
                    color: root.cfg.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }

                Text {
                    text: "Яндекс Музыка • Spotify • SoundCloud"
                    color: root.cfg.textMuted
                    font.pixelSize: 10
                    font.family: root.cfg.fontFamily
                }

                Text {
                    text: "Запустите трек в браузере или приложении"
                    color: root.cfg.accent
                    font.pixelSize: 9
                    font.family: root.cfg.fontFamily
                }
            }
        }
    }
}
