import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import ".."

Rectangle {
    antialiasing: true
    id: root

    required property var cfg
    property var widgetData: ({})

    readonly property string variant: (widgetData && widgetData.variant) ? widgetData.variant : "wavy"
    readonly property string size: (widgetData && widgetData.size) ? widgetData.size : "M"

    readonly property var players: Mpris.players.values || []
    readonly property var player: {
        if (!players || players.length === 0) return null
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) return players[i]
        }
        return players[0]
    }

    readonly property bool hasMedia: player !== null && (player.trackTitle !== "" || player.isPlaying)
    readonly property bool isPlaying: player !== null && player.isPlaying

    property real localPos: player ? player.position : 0
    property real trackLen: (player && player.length > 0) ? player.length : 0

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "0:00"
        let m = Math.floor(sec / 60)
        let s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            if (root.player) {
                let p = root.player.position
                if (Math.abs(root.localPos - p) > 1.2) {
                    root.localPos = p
                }
            }
        }
    }

    Timer {
        interval: 33
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.player && root.player.isPlaying) {
                if (root.trackLen > 0 && root.localPos < root.trackLen) {
                    root.localPos = Math.min(root.trackLen, root.localPos + 0.033)
                } else if (root.trackLen <= 0) {
                    root.localPos += 0.033
                }
            }
        }
    }

    radius: (widgetData && widgetData.radius !== undefined) ? widgetData.radius : (root.cfg.widgetRadius || 28)
    color: root.cfg.surfaceContainer
    border.color: root.cfg.outlineVariant
    border.width: 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8
        visible: root.variant === "wavy"

        // Верхняя строка: Обложка + Название + Кнопки управления
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Обложка трека: radius: 12 в строгом соответствии с M3 (аппаратное скругление через MultiEffect)
            Item {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46

                Rectangle {
                    antialiasing: true
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                }

                Text {
                    anchors.centerIn: parent
                    visible: cArt.status !== Image.Ready
                    text: "󰎆"
                    color: root.cfg.accent
                    font.pixelSize: 20
                }

                Image {
                    id: cArt
                    anchors.fill: parent
                    source: root.player ? (root.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                Item {
                    id: cArtMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle {
                        antialiasing: true
                        anchors.fill: parent
                        radius: 12
                        color: "black"
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: cArt
                    maskEnabled: true
                    maskSource: cArtMask
                    visible: cArt.status === Image.Ready
                }

                Rectangle {
                    antialiasing: true
                    anchors.fill: parent
                    radius: 12
                    color: "transparent"
                    border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                    border.width: 1
                }
            }

            // Название трека и исполнитель
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.hasMedia ? root.player.trackTitle : "Нет активного трека"
                    color: root.cfg.textPrimary
                    font.pixelSize: 12
                    font.bold: true
                    font.family: root.cfg.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.hasMedia ? (root.player.trackArtist || root.player.identity || "Медиаплеер") : "Запустите плеер"
                    color: root.cfg.onSurfaceVariant
                    font.pixelSize: 10
                    font.family: root.cfg.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Кнопки управления: Назад, Плей/Пауза (лаконичный круг без зубцов), Вперед
            RowLayout {
                spacing: 6

                // Кнопка Предыдущий трек
                Rectangle {
                    antialiasing: true
                    width: 30
                    height: 30
                    radius: 15
                    color: prevM.containsMouse ? root.cfg.surfaceContainerHigh : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        color: root.cfg.textPrimary
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: prevM
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.previous()
                    }
                }

                // Кнопка Play/Pause: Лаконичный круг (smooth circle) без рваных зубцов
                Rectangle {
                    antialiasing: true
                    id: playBtn
                    width: 38
                    height: 38
                    radius: 19
                    color: root.cfg.accent
                    scale: playWidgetM.pressed ? 0.88 : (playWidgetM.containsMouse ? 1.04 : 1.0)

                    Behavior on scale {
                        NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    // Векторная плавная иконка Плей
                    Canvas {
                        antialiasing: true
                        id: widgetPlayCanvas
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
                            let ox = cx + 1.5
                            let w = 13.5, h = 14
                            let r = 2.4

                            let x0 = ox - w / 2
                            let x1 = ox + w / 2
                            let y0 = cy - h / 2
                            let y1 = cy + h / 2

                            let p0 = { x: x0, y: y0 }
                            let p1 = { x: x1, y: cy }
                            let p2 = { x: x0, y: y1 }

                            ctx.fillStyle = root.cfg.accentText
                            ctx.beginPath()
                            ctx.moveTo(p0.x, (p0.y + p2.y) / 2)
                            ctx.arcTo(p0.x, p0.y, p1.x, p1.y, r)
                            ctx.arcTo(p1.x, p1.y, p2.x, p2.y, r)
                            ctx.arcTo(p2.x, p2.y, p0.x, p0.y, r)
                            ctx.closePath()
                            ctx.fill()
                        }

                        Connections {
                            target: root.cfg
                            function onAccentTextChanged() { widgetPlayCanvas.requestPaint() }
                        }
                    }

                    // Векторная плавная иконка Паузы
                    Canvas {
                        antialiasing: true
                        id: widgetPauseCanvas
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
                            ctx.lineWidth = 3.5
                            ctx.lineCap = "round"

                            ctx.beginPath()
                            ctx.moveTo(cx - 4.0, cy - 6.0)
                            ctx.lineTo(cx - 4.0, cy + 6.0)
                            ctx.moveTo(cx + 4.0, cy - 6.0)
                            ctx.lineTo(cx + 4.0, cy + 6.0)
                            ctx.stroke()
                        }

                        Connections {
                            target: root.cfg
                            function onAccentTextChanged() { widgetPauseCanvas.requestPaint() }
                        }
                    }

                    MouseArea {
                        id: playWidgetM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.togglePlaying()
                    }
                }

                // Кнопка Следующий трек
                Rectangle {
                    antialiasing: true
                    width: 30
                    height: 30
                    radius: 15
                    color: nextM.containsMouse ? root.cfg.surfaceContainerHigh : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        color: root.cfg.textPrimary
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: nextM
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.next()
                    }
                }
            }
        }

        // Нижняя строка: Wavy Progress Bar с 60 FPS плавной интерполяцией и каплей-скруббером
        Item {
            id: widgetProgContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            readonly property real progressRatio: (root.trackLen > 0) ? Math.max(0, Math.min(1, root.localPos / root.trackLen)) : 0
            property bool isSeeking: false
            property real smoothRatio: progressRatio

            Behavior on smoothRatio {
                enabled: !widgetProgContainer.isSeeking && root.isPlaying
                NumberAnimation {
                    duration: 950
                    easing.type: Easing.Linear
                }
            }

            onProgressRatioChanged: {
                if (widgetProgContainer.isSeeking || Math.abs(smoothRatio - progressRatio) > 0.04) {
                    smoothRatio = progressRatio
                } else {
                    smoothRatio = progressRatio
                }
            }

            Canvas {
                antialiasing: true
                id: dWave
                anchors.fill: parent
                property real phase: 0
                onPhaseChanged: requestPaint()

                NumberAnimation {
                    target: dWave
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
                    let playedW = Math.max(0, Math.min(width, width * widgetProgContainer.smoothRatio))

                    if (root.cfg.playerProgressStyle === "wavy") {
                        ctx.beginPath()
                        ctx.lineWidth = 3
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"
                        ctx.strokeStyle = root.cfg.accent
                        let amp = root.isPlaying ? 2.5 : 0.0
                        let waveLen = 14.0

                        ctx.moveTo(0, cy)
                        for (let x = 0; x <= playedW; x += 1.5) {
                            let taperL = Math.min(1.0, x / 14.0)
                            let taperR = Math.min(1.0, (playedW - x) / 14.0)
                            let envelope = Math.sin(taperL * Math.PI / 2) * Math.sin(taperR * Math.PI / 2)
                            let y = cy + Math.sin((x / waveLen) * 2 * Math.PI - phase) * (amp * envelope)
                            ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        if (playedW < width) {
                            ctx.beginPath()
                            ctx.lineWidth = 3
                            ctx.lineCap = "round"
                            ctx.strokeStyle = "#333742"
                            ctx.moveTo(Math.min(width, playedW + 3), cy)
                            ctx.lineTo(width, cy)
                            ctx.stroke()
                        }

                        if (playedW >= 0 && playedW <= width) {
                            let pillW = widgetProgContainer.isSeeking ? 5.0 : 4.0
                            let pillH = widgetProgContainer.isSeeking ? 15 : 13
                            drawDropletPill(ctx, playedW, cy, pillW, pillH, root.cfg.accent)
                        }
                    } else {
                        ctx.beginPath()
                        ctx.lineWidth = 4
                        ctx.lineCap = "round"
                        ctx.strokeStyle = "#333742"
                        ctx.moveTo(2, cy); ctx.lineTo(width - 2, cy); ctx.stroke()

                        if (playedW > 0) {
                            ctx.beginPath()
                            ctx.lineWidth = 4
                            ctx.lineCap = "round"
                            ctx.strokeStyle = root.cfg.accent
                            ctx.moveTo(2, cy); ctx.lineTo(playedW, cy); ctx.stroke()

                            let pillW = widgetProgContainer.isSeeking ? 5.0 : 4.0
                            let pillH = widgetProgContainer.isSeeking ? 15 : 13
                            drawDropletPill(ctx, playedW, cy, pillW, pillH, root.cfg.accent)
                        }
                    }
                }

                Connections {
                    target: widgetProgContainer
                    function onSmoothRatioChanged() { dWave.requestPaint() }
                }

                Connections {
                    target: root.cfg
                    function onPlayerProgressStyleChanged() { dWave.requestPaint() }
                    function onAccentChanged() { dWave.requestPaint() }
                }
            }

            // Интерактивная перемотка кликом и перетаскиванием
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function seekTo(mx) {
                    if (root.player && root.trackLen > 0) {
                        let ratio = Math.max(0, Math.min(1, mx / width))
                        widgetProgContainer.smoothRatio = ratio
                        let targetSec = ratio * root.trackLen
                        root.localPos = targetSec
                        root.player.position = targetSec
                    }
                }
                onPressed: m => {
                    widgetProgContainer.isSeeking = true
                    seekTo(m.x)
                }
                onPositionChanged: m => { if (pressed) seekTo(m.x) }
                onReleased: widgetProgContainer.isSeeking = false
            }
        }

        // Таймкоды (текущая позиция / общая длительность)
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.formatTime(root.localPos)
                color: root.cfg.onSurfaceVariant
                font.pixelSize: 9
                font.family: root.cfg.fontFamily
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.formatTime(root.trackLen)
                color: root.cfg.onSurfaceVariant
                font.pixelSize: 9
                font.family: root.cfg.fontFamily
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 2: COMPACT (МИНИ-ПЛЕЕР В СТИЛЕ M3 PILL)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        visible: root.variant === "compact"

        Rectangle {
            antialiasing: true
            Layout.preferredWidth: Math.min(parent.height - 8, 48)
            Layout.preferredHeight: Layout.preferredWidth
            radius: 14
            color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
            clip: true

            Image {
                anchors.fill: parent
                source: root.player ? (root.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
            }
            Text {
                anchors.centerIn: parent
                visible: !root.player || !root.player.trackArtUrl
                text: "󰎆"
                color: root.cfg.accent
                font.pixelSize: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: root.hasMedia ? root.player.trackTitle : "Нет активного трека"
                color: root.cfg.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.cfg.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.hasMedia ? (root.player.trackArtist || root.player.identity || "Медиаплеер") : "Ожидание воспроизведения"
                color: root.cfg.onSurfaceVariant
                font.pixelSize: 10
                font.family: root.cfg.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: 6
            Rectangle {
                antialiasing: true
                width: 38
                height: 38
                radius: 19
                color: root.cfg.accent
                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "󰏤" : "󰐊"
                    color: root.cfg.accentText
                    font.pixelSize: 16
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.togglePlaying()
                }
            }
            Rectangle {
                antialiasing: true
                width: 32
                height: 32
                radius: 16
                color: cmpNextM.containsMouse ? root.cfg.surfaceContainerHigh : "transparent"
                Text { anchors.centerIn: parent; text: "󰒭"; color: root.cfg.textPrimary; font.pixelSize: 15 }
                MouseArea {
                    id: cmpNextM
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.next()
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 3: VINYL DISC (ВРАЩАЮЩАЯСЯ ВИНИЛОВАЯ ПЛАСТИНКА)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
        visible: root.variant === "vinyl_disc"

        // Виниловая пластинка
        Item {
            Layout.preferredWidth: Math.min(parent.height - 12, 100)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                antialiasing: true
                id: vinylPlatter
                anchors.fill: parent
                radius: width / 2
                color: "#18181b"
                border.color: "#27272a"
                border.width: 1

                RotationAnimation {
                    target: vinylPlatter
                    property: "rotation"
                    from: 0
                    to: 360
                    duration: 4000
                    loops: Animation.Infinite
                    running: root.isPlaying
                }

                // Бороздки винила
                Rectangle {
                    antialiasing: true
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1
                }
                Rectangle {
                    antialiasing: true
                    anchors.centerIn: parent
                    width: parent.width * 0.58
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1
                }

                // Центральное яблоко пластинки
                Rectangle {
                    antialiasing: true
                    anchors.centerIn: parent
                    width: parent.width * 0.42
                    height: width
                    radius: width / 2
                    color: root.cfg.accent
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player ? (root.player.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                    }

                    // Центральное отверстие
                    Rectangle {
                        antialiasing: true
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        color: "#09090b"
                    }
                }
            }
        }

        // Информация и управление
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            Text {
                text: root.hasMedia ? root.player.trackTitle : "Нет активного трека"
                color: root.cfg.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.cfg.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.hasMedia ? (root.player.trackArtist || root.player.identity || "Плеер") : "Пауза"
                color: root.cfg.onSurfaceVariant
                font.pixelSize: 10
                font.family: root.cfg.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            // Управление
            RowLayout {
                spacing: 8
                Rectangle {
                    antialiasing: true
                    width: 32; height: 32; radius: 16
                    color: vnPrevM.containsMouse ? root.cfg.surfaceContainerHigh : "transparent"
                    Text { anchors.centerIn: parent; text: "󰒮"; color: root.cfg.textPrimary; font.pixelSize: 14 }
                    MouseArea { id: vnPrevM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.previous() }
                }
                Rectangle {
                    antialiasing: true
                    width: 36; height: 36; radius: 18
                    color: root.cfg.accent
                    Text { anchors.centerIn: parent; text: root.isPlaying ? "󰏤" : "󰐊"; color: root.cfg.accentText; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.togglePlaying() }
                }
                Rectangle {
                    antialiasing: true
                    width: 32; height: 32; radius: 16
                    color: vnNextM.containsMouse ? root.cfg.surfaceContainerHigh : "transparent"
                    Text { anchors.centerIn: parent; text: "󰒭"; color: root.cfg.textPrimary; font.pixelSize: 14 }
                    MouseArea { id: vnNextM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.next() }
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 4: SLEEK CAPSULE (ГОРИЗОНТАЛЬНАЯ ПОТОКОВАЯ КАПСУЛА)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        visible: root.variant === "sleek_capsule"

        Rectangle {
            antialiasing: true
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: 21
            color: root.cfg.primaryContainer
            clip: true

            Image {
                anchors.fill: parent
                source: root.player ? (root.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
            }
            Text {
                anchors.centerIn: parent
                visible: !root.player || !root.player.trackArtUrl
                text: "󰎆"
                color: root.cfg.onPrimaryContainer
                font.pixelSize: 20
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: root.hasMedia ? root.player.trackTitle : "Медиаплеер"
                color: root.cfg.textPrimary
                font.pixelSize: 11
                font.bold: true
                font.family: root.cfg.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                antialiasing: true
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: root.cfg.surfaceContainerHigh
                Rectangle {
                    antialiasing: true
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: (root.trackLen > 0) ? Math.max(4, parent.width * Math.min(1, root.localPos / root.trackLen)) : 0
                    radius: 2
                    color: root.cfg.accent
                }
            }
        }

        Rectangle {
            antialiasing: true
            width: 36
            height: 36
            radius: 18
            color: root.cfg.accent
            Text {
                anchors.centerIn: parent
                text: root.isPlaying ? "󰏤" : "󰐊"
                color: root.cfg.accentText
                font.pixelSize: 15
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (root.player) root.player.togglePlaying()
            }
        }
    }
}
