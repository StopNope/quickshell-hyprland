import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    required property var cfg
    property int targetX: 0
    property int targetY: 0
    property bool isOpen: false

    signal closeRequested()

    // ── Цвета и оформление (согласованы с Bar.qml) ──
    readonly property color barColor: root.cfg.surfaceContainer || "#1e2025"
    readonly property color borderColor: root.cfg.outlineVariant || "#383b45"
    readonly property bool isAttached: root.cfg.barStyle === "attached" && root.cfg.barPosition === "top"

    // ── Размеры геометрии (гармоничные скругления и сопряжения с баром) ──
    readonly property real cardW: 520
    readonly property real fR: 24           // Плавный радиус сопряжения (fillet) с кромкой бара
    readonly property real bR: 28           // Радиус нижних углов медиацентра
    readonly property real targetH: 236      // Полная высота раскрытого меню
    readonly property real totalW: isAttached ? (cardW + 2 * fR) : cardW

    implicitWidth: totalW
    width: totalW
    implicitHeight: targetH
    height: targetH
    clip: true  // Контейнер обрезает меню, обеспечивая физический выезд из бара вниз

    // ── MPRIS Управление (С липким активным плеером и защитой от скачков) ──
    readonly property var players: Mpris.players.values || []
    property var activePlayer: null

    function updateActivePlayer() {
        let list = players
        if (!list || list.length === 0) {
            activePlayer = null
            return
        }

        // 1. Приоритет активно играющему плееру
        for (let i = 0; i < list.length; i++) {
            let p = list[i]
            if (p && p.isPlaying) {
                if (activePlayer !== p) activePlayer = p
                return
            }
        }

        // 2. Липкий текущий плеер, если у него есть трек
        if (activePlayer) {
            for (let i = 0; i < list.length; i++) {
                if (list[i] === activePlayer && activePlayer.trackTitle && activePlayer.trackTitle !== "") {
                    return
                }
            }
        }

        // 3. Плеер с треком
        for (let i = 0; i < list.length; i++) {
            let p = list[i]
            if (p && p.trackTitle && p.trackTitle !== "") {
                activePlayer = p
                return
            }
        }

        // 4. Первый доступный
        activePlayer = list[0]
    }

    onPlayersChanged: updateActivePlayer()
    Component.onCompleted: updateActivePlayer()

    readonly property var player: activePlayer

    readonly property bool hasMedia: player !== null && (player.trackTitle !== "" || player.isPlaying)
    readonly property bool isPlaying: player !== null && player.isPlaying

    // ── КЭШИРОВАНИЕ МЕТАДАННЫХ (Защита от задержек и сброса D-Bus при смене трека) ──
    property string cachedTitle: "Музыка не играет"
    property string cachedArtist: "Запустите трек в любом приложении"
    property string cachedArt: ""

    readonly property string rawTitle: player ? (player.trackTitle || "") : ""
    readonly property string rawArtist: {
        if (!player) return ""
        if (player.trackArtist) return player.trackArtist
        if (player.trackArtists && player.trackArtists.length > 0) return player.trackArtists.join(", ")
        return ""
    }

    onRawTitleChanged: {
        if (rawTitle && rawTitle !== "") cachedTitle = rawTitle
    }
    onRawArtistChanged: {
        if (rawArtist && rawArtist !== "") cachedArtist = rawArtist
    }

    readonly property string trackTitle: hasMedia ? (rawTitle !== "" ? rawTitle : cachedTitle) : "Музыка не играет"
    readonly property string trackArtist: hasMedia ? (rawArtist !== "" ? rawArtist : cachedArtist) : "Запустите трек в любом приложении"

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec <= 0) return "00:00"
        let s = Math.floor(sec)
        let m = Math.floor(s / 60)
        let remSec = s % 60
        let mStr = (m < 10 ? "0" : "") + m
        let sStr = (remSec < 10 ? "0" : "") + remSec
        return mStr + ":" + sStr
    }

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
            return { name: "Браузер", icon: "󰈹" }
        }
        return { name: player.identity || "Медиа", icon: "󰎆" }
    }

    // ── СТАБИЛИЗАЦИЯ И МГНОВЕННАЯ ЗАГРУЗКА ОБЛОЖКИ ──
    property string fetchedArtUrl: ""

    Process {
        id: artProc
        running: false
        command: ["/home/stopnope/.config/quickshell/scripts/art_fetcher.py", root.trackArtist, root.trackTitle]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim()
                if (trimmed && trimmed.startsWith("file://")) {
                    root.fetchedArtUrl = trimmed
                    root.cachedArt = trimmed
                }
            }
        }
    }

    function checkArt() {
        if (root.hasMedia && root.trackTitle && root.trackTitle !== "Музыка не играет") {
            artProc.running = true
        }
    }

    onTrackTitleChanged: checkArt()
    onTrackArtistChanged: checkArt()
    onIsOpenChanged: {
        if (isOpen) {
            checkArt()
            if (player) {
                root.localPos = player.position
                root.smoothPos = player.position
            }
        }
    }

    readonly property string finalArtUrl: {
        if (player && player.trackArtUrl && player.trackArtUrl !== "") return player.trackArtUrl
        if (fetchedArtUrl !== "") return fetchedArtUrl
        if (cachedArt !== "") return cachedArt
        return ""
    }

    // ── УПРАВЛЕНИЕ ВОСПРОИЗВЕДЕНИЕМ (Строго 1 вызов, без дублирования!) ──
    function doPlayPause() {
        if (root.player) {
            root.player.togglePlaying()
        }
    }

    function doNext() {
        if (root.player) {
            root.smoothPos = 0
            root.localPos = 0
            root.player.next()
        }
    }

    function doPrev() {
        if (root.player) {
            root.smoothPos = 0
            root.localPos = 0
            root.player.previous()
        }
    }

    // ── УПРАВЛЕНИЕ ГРОМКОСТЬЮ (Атомарные вызовы wpctl) ──
    Process {
        id: volCmdProc
        property string cmdStr: ""
        command: ["sh", "-c", cmdStr]
    }

    function changeVolumeExact(val) {
        let v = Math.max(0, Math.min(100, Math.round(val)))
        root.cfg.currentVolume = v
        if (v === 0) {
            root.cfg.isMuted = true
            volCmdProc.cmdStr = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 1; wpctl set-volume @DEFAULT_AUDIO_SINK@ 0%"
        } else {
            root.cfg.isMuted = false
            volCmdProc.cmdStr = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + v + "%"
        }
        volCmdProc.running = false
        volCmdProc.running = true
    }

    function changeVolume(delta) {
        if (delta === "mute") {
            root.cfg.isMuted = !root.cfg.isMuted
            volCmdProc.cmdStr = "wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (root.cfg.isMuted ? "1" : "0")
        } else {
            root.cfg.isMuted = false
            let d = delta.includes("+") ? 3 : -3
            let nextV = Math.max(0, Math.min(100, root.cfg.currentVolume + d))
            root.cfg.currentVolume = nextV
            volCmdProc.cmdStr = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + nextV + "%"
        }
        volCmdProc.running = false
        volCmdProc.running = true
    }

    // ── СВЕРХПЛАВНАЯ 60 FPS ПОЗИЦИЯ ТРЕКА БЕЗ СКАЧКОВ ──
    property real localPos: player ? player.position : 0
    property real smoothPos: player ? player.position : 0
    property real trackLen: (player && player.length > 0) ? player.length : 0
    property bool isSeeking: false

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            if (!root.player || root.isSeeking) return
            let mprisPos = root.player.position
            root.localPos = mprisPos
            // Синхронизация при значительном отклонении (> 1.2с) или перемотке
            if (Math.abs(root.smoothPos - mprisPos) > 1.2) {
                root.smoothPos = mprisPos
            }
        }
        function onTrackTitleChanged() {
            root.smoothPos = 0
            root.localPos = 0
            root.checkArt()
        }
        function onIsPlayingChanged() {
            if (root.player && !root.isSeeking) {
                let mprisPos = root.player.position
                if (Math.abs(root.smoothPos - mprisPos) > 1.0) {
                    root.smoothPos = mprisPos
                }
            }
        }
    }

    // 60 FPS сверхплавный инкремент времени
    Timer {
        id: smoothProgressTimer
        interval: 33 // ~30-60 FPS непрерывное скольжение
        running: root.isPlaying && !root.isSeeking && root.isOpen
        repeat: true
        onTriggered: {
            if (root.trackLen > 0) {
                if (root.smoothPos < root.trackLen) {
                    root.smoothPos = Math.min(root.trackLen, root.smoothPos + 0.033)
                }
            } else {
                root.smoothPos += 0.033
            }
        }
    }

    Timer {
        id: seekDebounceTimer
        interval: 250
        onTriggered: root.isSeeking = false
    }

    // ── CAVA ВИЗУАЛИЗАТОР СПЕКТРА (32 ПОЛОСКИ) ──
    property var cavaBars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

    Process {
        id: cavaProc
        running: root.isOpen
        command: ["cava", "-p", "/home/stopnope/.config/quickshell/cava/cava.conf"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let trimmed = data.trim()
                if (!trimmed) return
                let parts = trimmed.split(";")
                let vals = []
                let count = Math.min(32, parts.length)
                for (let i = 0; i < count; i++) {
                    if (parts[i].length > 0) {
                        let num = parseInt(parts[i]) || 0
                        vals.push(Math.min(100, Math.max(0, num)))
                    }
                }
                while (vals.length < 32) vals.push(0)
                root.cavaBars = vals
            }
        }
    }

    // Защита от кликов сквозь меню
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    // ==========================================
    // ВЫДВИЖНОЙ БЛОК (ФИЗИЧЕСКИЙ ВЫЕЗД ИЗ БАРА ВНИЗ)
    // ==========================================
    Item {
        id: slidingDrawer
        width: root.totalW
        height: root.targetH

        // Анимация выезда: панель опускается из-за пределов бара сверху (y: -targetH -> 0)
        y: root.isOpen ? 0 : -root.targetH
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        // ==========================================
        // 1. МОНОЛИТНАЯ ГЕОМЕТРИЯ С СОПРЯЖЕНИЯМИ
        // ==========================================
        Shape {
            id: attachedShape
            visible: root.isAttached
            width: root.totalW
            height: root.targetH

            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, root.cfg.barOpacity || 1.0)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                startX: 0
                startY: 0

                PathArc {
                    x: root.fR
                    y: root.fR
                    radiusX: root.fR
                    radiusY: root.fR
                    direction: PathArc.Clockwise
                    useLargeArc: false
                }

                PathLine {
                    x: root.fR
                    y: root.targetH - root.bR
                }

                PathArc {
                    x: root.fR + root.bR
                    y: root.targetH
                    radiusX: root.bR
                    radiusY: root.bR
                    direction: PathArc.Counterclockwise
                    useLargeArc: false
                }

                PathLine {
                    x: root.fR + root.cardW - root.bR
                    y: root.targetH
                }

                PathArc {
                    x: root.fR + root.cardW
                    y: root.targetH - root.bR
                    radiusX: root.bR
                    radiusY: root.bR
                    direction: PathArc.Counterclockwise
                    useLargeArc: false
                }

                PathLine {
                    x: root.fR + root.cardW
                    y: root.fR
                }

                PathArc {
                    x: root.totalW
                    y: 0
                    radiusX: root.fR
                    radiusY: root.fR
                    direction: PathArc.Clockwise
                    useLargeArc: false
                }

                PathLine {
                    x: 0
                    y: 0
                }
            }

            ShapePath {
                strokeColor: (root.cfg.barBorder === false) ? "transparent" : Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.cfg.barOpacity || 1.0)
                strokeWidth: (root.cfg.barBorder === false) ? 0 : 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                startX: 0
                startY: 0

                PathArc {
                    x: root.fR
                    y: root.fR
                    radiusX: root.fR
                    radiusY: root.fR
                    direction: PathArc.Clockwise
                    useLargeArc: false
                }

                PathLine {
                    x: root.fR
                    y: root.targetH - root.bR
                }

                PathArc {
                    x: root.fR + root.bR
                    y: root.targetH
                    radiusX: root.bR
                    radiusY: root.bR
                    direction: PathArc.Counterclockwise
                    useLargeArc: false
                }

                PathLine {
                    x: root.fR + root.cardW - root.bR
                    y: root.targetH
                }

                PathArc {
                    x: root.fR + root.cardW
                    y: root.targetH - root.bR
                    radiusX: root.bR
                    radiusY: root.bR
                    direction: PathArc.Counterclockwise
                    useLargeArc: false
                }

                PathLine {
                    x: root.fR + root.cardW
                    y: root.fR
                }

                PathArc {
                    x: root.totalW
                    y: 0
                    radiusX: root.fR
                    radiusY: root.fR
                    direction: PathArc.Clockwise
                    useLargeArc: false
                }

                PathLine {
                    x: 0
                    y: 0
                }
            }
        }

        Rectangle {
            id: floatingShape
            visible: !root.isAttached
            width: root.cardW
            height: root.targetH
            radius: root.bR
            color: Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, root.cfg.barOpacity || 1.0)
            border.color: (root.cfg.barBorder === false) ? "transparent" : Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.cfg.barOpacity || 1.0)
            border.width: (root.cfg.barBorder === false) ? 0 : 1
        }

        // ==========================================
        // 2. ТЕЛО МЕДИАЦЕНТРА И КОНТЕНТ
        // ==========================================
        Item {
            id: cardBody
            x: root.isAttached ? root.fR : 0
            width: root.cardW
            height: root.targetH

            // ==========================================
            // 3. CAVA АУДИО-ВИЗУАЛИЗАТОР (32 ПОЛОСКИ)
            // ==========================================
            Item {
                id: cavaBox
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                width: 32 * 8 + 31 * 6 // 442px
                height: 95
                z: 1
                opacity: root.isPlaying ? 0.85 : 0.20
                Behavior on opacity { NumberAnimation { duration: 250 } }

                Row {
                    anchors.fill: parent
                    spacing: 6

                    Repeater {
                        model: 32
                        delegate: Item {
                            width: 8
                            height: parent.height

                            readonly property int rawVal: (root.cavaBars && root.cavaBars.length > index) ? root.cavaBars[index] : 0
                            readonly property real barHeight: Math.max(3, (rawVal / 100.0) * parent.height)

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: parent.barHeight
                                radius: 4

                                gradient: Gradient {
                                    GradientStop {
                                        position: 0.0
                                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.70)
                                    }
                                    GradientStop {
                                        position: 1.0
                                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.08)
                                    }
                                }

                                Behavior on height {
                                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 4. СТУДИЙНЫЙ ИНТЕРФЕЙС ПЛЕЕРА (FOREGROUND)
            // ==========================================
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 12
                anchors.bottomMargin: 14
                spacing: 12
                z: 2

                // ── А. ШАПКА: Источник с живым эквалайзером и кнопка закрытия ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        height: 24
                        implicitWidth: sRow.implicitWidth + 16
                        radius: 12
                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.16)
                        border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.30)
                        border.width: 1

                        RowLayout {
                            id: sRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: root.serviceInfo.icon
                                color: root.cfg.accent
                                font.pixelSize: 12
                            }

                            Text {
                                text: root.serviceInfo.name
                                color: root.cfg.textPrimary
                                font.pixelSize: 10
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }

                            // Живой мини-эквалайзер из 3 полосок при воспроизведении
                            Row {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter
                                visible: root.isPlaying

                                Rectangle {
                                    width: 2.5; height: 8; radius: 1; color: root.cfg.accent
                                    SequentialAnimation on height {
                                        running: root.isPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 3; to: 11; duration: 380; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 11; to: 3; duration: 380; easing.type: Easing.InOutQuad }
                                    }
                                }
                                Rectangle {
                                    width: 2.5; height: 11; radius: 1; color: root.cfg.accent
                                    SequentialAnimation on height {
                                        running: root.isPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 10; to: 4; duration: 300; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 4; to: 10; duration: 300; easing.type: Easing.InOutQuad }
                                    }
                                }
                                Rectangle {
                                    width: 2.5; height: 5; radius: 1; color: root.cfg.accent
                                    SequentialAnimation on height {
                                        running: root.isPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 4; to: 12; duration: 440; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 12; to: 4; duration: 440; easing.type: Easing.InOutQuad }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: closeM.containsMouse ? (root.cfg.surfaceContainerHighest || "#303440") : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: closeM.containsMouse ? root.cfg.textPrimary : root.cfg.textMuted
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: closeM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.closeRequested()
                        }
                    }
                }

                // ── Б. ОСНОВНОЙ БЛОК: Обложка + Инфо + Скраббер ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Обложка трека (Аппаратный Squircle radius: 18 через MultiEffect)
                    Item {
                        id: coverFrame
                        Layout.preferredWidth: 84
                        Layout.preferredHeight: 84

                        // Фоновая подложка
                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: root.cfg.surfaceContainerHighest || "#262933"
                        }

                        // Запасная иконка ноты
                        Text {
                            anchors.centerIn: parent
                            visible: coverImg.status !== Image.Ready
                            text: "󰎆"
                            color: root.cfg.accent
                            font.pixelSize: 34
                        }

                        // Исходное изображение для эффекта
                        Image {
                            id: coverImg
                            anchors.fill: parent
                            source: root.finalArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                        }

                        // Элемент-маска со скруглением radius: 18
                        Item {
                            id: coverMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false

                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: "black"
                            }
                        }

                        // Скруглённая обложка через MultiEffect
                        MultiEffect {
                            id: coverEffect
                            anchors.fill: parent
                            source: coverImg
                            maskEnabled: true
                            maskSource: coverMask
                            visible: coverImg.status === Image.Ready
                            opacity: visible ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        // Рамка со скруглением поверх
                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: "transparent"
                            border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.28)
                            border.width: 1
                        }
                    }

                    // Инфо трека и таймлайн
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: root.trackTitle
                            color: root.cfg.textPrimary
                            font.pixelSize: 15
                            font.bold: true
                            font.family: root.cfg.fontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.trackArtist
                            color: root.cfg.accent
                            font.pixelSize: 12
                            font.family: root.cfg.fontFamily
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Item { height: 2 }

                        // ── СКРАББЕР / ПРОГРЕСС-БАР ТРЕКА ──
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Item {
                                id: progressBox
                                Layout.fillWidth: true
                                height: 18

                                property real progressRatio: (root.trackLen > 0) ? Math.max(0.0, Math.min(1.0, root.smoothPos / root.trackLen)) : 0.0
                                property real progressX: progressRatio * width
                                property real wavePhase: 0
                                property real targetAmp: (root.isPlaying && progressX > 15) ? 3.0 : 0.0
                                property real liveAmp: targetAmp
                                Behavior on liveAmp { NumberAnimation { duration: 350; easing.type: Easing.OutQuad } }

                                NumberAnimation on wavePhase {
                                    from: 0
                                    to: Math.PI * 2
                                    duration: 1600
                                    loops: Animation.Infinite
                                    running: root.isPlaying && root.isOpen
                                }

                                Canvas {
                                    id: wavyCanvas
                                    anchors.fill: parent

                                    onPaint: {
                                        let ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        if (width <= 0 || height <= 0) return

                                        let cy = height / 2
                                        let px = Math.max(0, Math.min(width, progressBox.progressX))
                                        let isHover = scrubArea.containsMouse || scrubArea.pressed

                                        // 1. Непроигранная часть (фоновый трек)
                                        ctx.beginPath()
                                        ctx.strokeStyle = root.cfg.surfaceContainerHighest || "#2c2f38"
                                        ctx.lineWidth = isHover ? 4.5 : 3.5
                                        ctx.lineCap = "round"
                                        ctx.moveTo(px, cy)
                                        ctx.lineTo(width, cy)
                                        ctx.stroke()

                                        // 2. Проигранная часть (жидкая волна в стиле Android 14 / Serpantinum)
                                        if (px > 0) {
                                            ctx.beginPath()
                                            ctx.strokeStyle = root.cfg.accent
                                            ctx.lineWidth = isHover ? 4.5 : 3.5
                                            ctx.lineCap = "round"
                                            ctx.moveTo(0, cy)

                                            let amp = progressBox.liveAmp
                                            let step = 3
                                            for (let x = step; x <= px; x += step) {
                                                // Плавное затухание волны у краев для идеального сопряжения
                                                let edgeFactor = Math.min(1.0, Math.min(x / 18.0, (px - x) / 18.0))
                                                let y = cy + (amp * edgeFactor) * Math.sin((x / 14.0) * Math.PI - progressBox.wavePhase)
                                                ctx.lineTo(x, y)
                                            }
                                            ctx.lineTo(px, cy)
                                            ctx.stroke()

                                            // 3. Бегунок / Thumb (акцентная круглая капсула на конце волны)
                                            ctx.beginPath()
                                            ctx.fillStyle = root.cfg.accent
                                            let thumbR = isHover ? 6.0 : 4.5
                                            ctx.arc(px, cy, thumbR, 0, Math.PI * 2)
                                            ctx.fill()
                                        }
                                    }

                                    Connections {
                                        target: progressBox
                                        function onProgressXChanged() { wavyCanvas.requestPaint() }
                                        function onWavePhaseChanged() { wavyCanvas.requestPaint() }
                                        function onLiveAmpChanged() { wavyCanvas.requestPaint() }
                                    }
                                }

                                MouseArea {
                                    id: scrubArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    function updateSeek(mouse) {
                                        if (root.trackLen <= 0) return
                                        let newRatio = Math.max(0, Math.min(1.0, mouse.x / width))
                                        let targetSec = newRatio * root.trackLen
                                        root.smoothPos = targetSec
                                        root.localPos = targetSec
                                    }

                                    onPressed: mouse => {
                                        root.isSeeking = true
                                        updateSeek(mouse)
                                        wavyCanvas.requestPaint()
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed) {
                                            updateSeek(mouse)
                                            wavyCanvas.requestPaint()
                                        }
                                    }
                                    onReleased: {
                                        if (root.player && root.trackLen > 0) {
                                            root.player.position = root.smoothPos
                                        }
                                        seekDebounceTimer.restart()
                                        wavyCanvas.requestPaint()
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: root.formatTime(root.smoothPos)
                                    color: root.cfg.textMuted
                                    font.pixelSize: 10
                                    font.family: root.cfg.fontFamily
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.formatTime(root.trackLen)
                                    color: root.cfg.textMuted
                                    font.pixelSize: 10
                                    font.family: root.cfg.fontFamily
                                }
                            }
                        }
                    }
                }

                // ── В. НИЖНЯЯ ПАНЕЛЬ: ЧЕТКИЕ ОРГАНЫ УПРАВЛЕНИЯ БЕЗ ДУБЛИРОВАНИЯ ИКОНОК ЗВУКА ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Предыдущий трек (Previous)
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 21
                        color: prevM.containsMouse ? (root.cfg.surfaceContainerHighest || "#333744") : "transparent"
                        scale: prevM.pressed ? 0.86 : (prevM.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            color: root.cfg.textPrimary
                            font.pixelSize: 21
                        }

                        MouseArea {
                            id: prevM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.doPrev()
                        }
                    }

                    // Кнопка Play/Pause (Главная капсула по центру)
                    Rectangle {
                        id: playHeroBtn
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 42
                        radius: 21
                        color: root.cfg.accent
                        scale: playM.pressed ? 0.88 : (playM.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "󰏤" : "󰐊"
                            color: root.cfg.accentText || "#ffffff"
                            font.pixelSize: 22
                        }

                        MouseArea {
                            id: playM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.doPlayPause()
                        }
                    }

                    // Следующий трек (Next)
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 21
                        color: nextM.containsMouse ? (root.cfg.surfaceContainerHighest || "#333744") : "transparent"
                        scale: nextM.pressed ? 0.86 : (nextM.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            color: root.cfg.textPrimary
                            font.pixelSize: 21
                        }

                        MouseArea {
                            id: nextM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.doNext()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // ЕДИНСТВЕННЫЙ ПОЛНОЦЕННЫЙ СЛАЙДЕР ГРОМКОСТИ MATERIAL 3 (СО SCISSOR-КЛИППИНГОМ, НИКОГДА НЕ СПЛЮЩИВАЕТСЯ!)
                    Rectangle {
                        id: volSliderRoot
                        Layout.preferredWidth: 176
                        Layout.preferredHeight: 38
                        radius: 19
                        color: root.cfg.surfaceContainerHigh || "#242730"
                        border.color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0.45)
                        border.width: 1
                        clip: true

                        readonly property real progressRatio: root.cfg.isMuted ? 0 : Math.max(0, Math.min(1.0, root.cfg.currentVolume / 100.0))

                        // 1. Неактивный нижний слой (темный фон)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: 6

                            Text {
                                text: root.cfg.isMuted ? "󰝟" : (root.cfg.currentVolume > 50 ? "󰕾" : "󰖀")
                                color: root.cfg.isMuted ? root.cfg.danger : root.cfg.textMuted
                                font.pixelSize: 15
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.cfg.isMuted ? "MUT" : (root.cfg.currentVolume + "%")
                                color: root.cfg.isMuted ? root.cfg.danger : root.cfg.textPrimary
                                font.pixelSize: 11
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }
                        }

                        // 2. Активный цветной слой со Scissor-клиппингом (геометрия Rectangle ВСЕГДА полная, радиус НЕ деформируется!)
                        Item {
                            id: fillClipper
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: Math.max(0, Math.min(parent.width, parent.width * volSliderRoot.progressRatio))
                            visible: !root.cfg.isMuted && root.cfg.currentVolume > 0
                            clip: true

                            Behavior on width {
                                enabled: !volMouse.pressed
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }

                            // Прямоугольник ПОЛНОЙ ширины с неизменным радиусом 19px!
                            Rectangle {
                                width: volSliderRoot.width
                                height: volSliderRoot.height
                                radius: volSliderRoot.radius
                                color: root.cfg.accent

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 6

                                    Text {
                                        text: root.cfg.currentVolume > 50 ? "󰕾" : "󰖀"
                                        color: root.cfg.accentText || "#ffffff"
                                        font.pixelSize: 15
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: root.cfg.currentVolume + "%"
                                        color: root.cfg.accentText || "#ffffff"
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.family: root.cfg.fontFamily
                                    }
                                }
                            }
                        }

                        // 3. Интерактивная зона: клик по иконке = Mute, клик/перетаскивание по телу = установка громкости, скролл
                        MouseArea {
                            id: volMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            function applyVal(mouse) {
                                let ratio = Math.max(0, Math.min(1.0, mouse.x / width))
                                let val = Math.round(ratio * 100)
                                root.changeVolumeExact(val)
                            }

                            onClicked: mouse => {
                                if (mouse.x < 32) {
                                    root.changeVolume("mute")
                                } else {
                                    applyVal(mouse)
                                }
                            }

                            onPositionChanged: mouse => {
                                if (pressed && mouse.x >= 20) applyVal(mouse)
                            }

                            onWheel: wheel => {
                                let delta = wheel.angleDelta.y > 0 ? "3%+" : "3%-"
                                root.changeVolume(delta)
                            }
                        }
                    }
                }
            }
        }
    }
}
