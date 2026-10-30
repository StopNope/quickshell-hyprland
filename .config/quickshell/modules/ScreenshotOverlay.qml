import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var cfg

    property bool isOpen: false
    property string imageSource: ""
    property string currentTool: "crop" // "crop", "pen", "arrow", "rect", "blur"
    property color currentColor: cfg.accent
    property int strokeWidth: 4

    // Выделенная область
    property bool hasCrop: false
    property real cropX: 0
    property real cropY: 0
    property real cropW: 0
    property real cropH: 0

    // Текущее рисование
    property real dragStartX: 0
    property real dragStartY: 0
    property real currentX: 0
    property real currentY: 0
    property bool isDragging: false
    property var activePenPoints: []

    // Список сохраненных фигур
    property var shapes: []

    signal closeRequested()

    focus: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeOverlay()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.commitSave()
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
            root.undo()
            event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) {
            root.commitSave()
            event.accepted = true
        }
    }

    // Процесс сохранения и обработки скриншота через Python PIL
    Process {
        id: saveProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let savedFile = data.trim()
                if (savedFile.length > 0) {
                    root.cfg.pushNotification("Снимок экрана", "Сохранен в Pictures/Screenshots и скопирован")
                }
            }
        }
        onExited: {
            root.closeOverlay()
        }
    }

    function openOverlay() {
        isOpen = true
        shapes = []
        hasCrop = false
        cropX = 0; cropY = 0; cropW = 0; cropH = 0
        currentTool = "crop"
        currentColor = cfg.accent
        activePenPoints = []
        // Сбрасываем кэш картинки временем
        imageSource = "file:///tmp/qs_freeze.png?" + Date.now()
        drawCanvas.requestPaint()
        root.forceActiveFocus()
    }

    function closeOverlay() {
        isOpen = false
        closeRequested()
    }

    function commitSave() {
        let cropStr = ""
        if (hasCrop && cropW > 10 && cropH > 10) {
            cropStr = Math.round(cropX) + "," + Math.round(cropY) + "," + Math.round(cropW) + "," + Math.round(cropH)
        }

        saveProc.command = [
            "/home/stopnope/.config/quickshell/save_screenshot.py",
            "--base", "/tmp/qs_freeze.png",
            "--crop", cropStr,
            "--shapes", JSON.stringify(shapes)
        ]
        saveProc.running = true
    }

    function undo() {
        if (shapes.length > 0) {
            let nextShapes = []
            for (let i = 0; i < shapes.length - 1; i++) {
                nextShapes.push(shapes[i])
            }
            shapes = nextShapes
            drawCanvas.requestPaint()
        } else if (hasCrop) {
            hasCrop = false
            cropX = 0; cropY = 0; cropW = 0; cropH = 0
            currentTool = "crop"
        }
    }

    function clearAll() {
        shapes = []
        hasCrop = false
        cropX = 0; cropY = 0; cropW = 0; cropH = 0
        currentTool = "crop"
        drawCanvas.requestPaint()
    }

    // ========================================================
    // 1. ЗАМОРОЖЕННЫЙ ЭКРАН (BASE FREEZE IMAGE)
    // ========================================================
    Image {
        id: freezeImage
        anchors.fill: parent
        source: root.imageSource
        fillMode: Image.PreserveAspectCrop
        cache: false
        smooth: true
    }

    // ========================================================
    // 2. ЗАТЕМНЕНИЕ (SCRIM)
    // Затемняет весь экран, кроме выделенной области crop!
    // ========================================================
    Item {
        id: scrimContainer
        anchors.fill: parent

        // Полное затемнение до создания выделения
        Rectangle {
            antialiasing: true
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.58)
            visible: !root.hasCrop
        }

        // 4 прямоугольника затемнения вокруг выделенной области
        // Верхний
        Rectangle {
            antialiasing: true
            visible: root.hasCrop
            x: 0; y: 0; width: root.width
            height: Math.max(0, root.cropY)
            color: Qt.rgba(0, 0, 0, 0.58)
        }
        // Нижний
        Rectangle {
            antialiasing: true
            visible: root.hasCrop
            x: 0; y: root.cropY + root.cropH
            width: root.width
            height: Math.max(0, root.height - (root.cropY + root.cropH))
            color: Qt.rgba(0, 0, 0, 0.58)
        }
        // Левый
        Rectangle {
            antialiasing: true
            visible: root.hasCrop
            x: 0; y: root.cropY
            width: Math.max(0, root.cropX)
            height: root.cropH
            color: Qt.rgba(0, 0, 0, 0.58)
        }
        // Правый
        Rectangle {
            antialiasing: true
            visible: root.hasCrop
            x: root.cropX + root.cropW
            y: root.cropY
            width: Math.max(0, root.width - (root.cropX + root.cropW))
            height: root.cropH
            color: Qt.rgba(0, 0, 0, 0.58)
        }
    }

    // ========================================================
    // 3. РАМКА ВЫДЕЛЕНИЯ (MATERIAL YOU CROP BOX)
    // ========================================================
    Rectangle {
        antialiasing: true
        id: cropBorder
        visible: root.hasCrop
        x: root.cropX
        y: root.cropY
        width: root.cropW
        height: root.cropH
        color: "transparent"
        border.color: root.cfg.accent
        border.width: 2
        radius: 4

        // Бейдж с разрешением в стиле Material You
        Rectangle {
            antialiasing: true
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            visible: root.cropW > 40 && root.cropH > 40
            height: 24
            implicitWidth: dimText.implicitWidth + 16
            radius: 12
            color: root.cfg.bgSurface
            border.color: root.cfg.borderCol
            border.width: 1

            Text {
                id: dimText
                anchors.centerIn: parent
                text: Math.round(root.cropW) + " × " + Math.round(root.cropH)
                color: root.cfg.textPrimary
                font.pixelSize: 11
                font.bold: true
                font.family: "JetBrainsMono Nerd Font, monospace"
            }
        }

        // 4 Угловые точки выделения
        Rectangle { width: 8; height: 8; radius: 4; color: root.cfg.accent; anchors.top: parent.top; anchors.left: parent.left; anchors.margins: -4 }
        Rectangle { width: 8; height: 8; radius: 4; color: root.cfg.accent; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: -4 }
        Rectangle { width: 8; height: 8; radius: 4; color: root.cfg.accent; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: -4 }
        Rectangle { width: 8; height: 8; radius: 4; color: root.cfg.accent; anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: -4 }
    }

    // ========================================================
    // 4. CANVAS ДЛЯ АННОТАЦИЙ (СТРЕЛКИ, КАРАНДАШ, РАМКИ)
    // ========================================================
    Canvas {
        antialiasing: true
        id: drawCanvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Функция рисования стрелки
            function drawArrow(x1, y1, x2, y2, color, w) {
                ctx.strokeStyle = color
                ctx.fillStyle = color
                ctx.lineWidth = w
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                ctx.beginPath()
                ctx.moveTo(x1, y1)
                ctx.lineTo(x2, y2)
                ctx.stroke()

                var theta = Math.atan2(y2 - y1, x2 - x1)
                var headLen = Math.max(16, w * 4.5)
                var lx = x2 - headLen * Math.cos(theta - Math.PI / 6)
                var ly = y2 - headLen * Math.sin(theta - Math.PI / 6)
                var rx = x2 - headLen * Math.cos(theta + Math.PI / 6)
                var ry = y2 - headLen * Math.sin(theta + Math.PI / 6)

                ctx.beginPath()
                ctx.moveTo(x2, y2)
                ctx.lineTo(lx, ly)
                ctx.lineTo(rx, ry)
                ctx.closePath()
                ctx.fill()
            }

            // Функция рисования рамки
            function drawRect(x, y, w, h, color, lw) {
                ctx.strokeStyle = color
                ctx.lineWidth = lw
                ctx.strokeRect(x, y, w, h)
            }

            // Функция рисования блюра/цензуры (в превью полупрозрачная штриховка)
            function drawBlurPreview(x, y, w, h) {
                ctx.fillStyle = "rgba(40, 40, 45, 0.85)"
                ctx.fillRect(x, y, w, h)
                ctx.strokeStyle = "#888888"
                ctx.lineWidth = 1
                ctx.strokeRect(x, y, w, h)
            }

            // 1. Отрисовка зафиксированных фигур
            for (var i = 0; i < root.shapes.length; i++) {
                var s = root.shapes[i]
                if (s.type === "pen" && s.points.length >= 2) {
                    ctx.strokeStyle = s.color
                    ctx.fillStyle = s.color
                    ctx.lineWidth = s.width
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(s.points[0][0], s.points[0][1])
                    for (var p = 1; p < s.points.length; p++) {
                        ctx.lineTo(s.points[p][0], s.points[p][1])
                    }
                    ctx.stroke()
                } else if (s.type === "arrow") {
                    drawArrow(s.x1, s.y1, s.x2, s.y2, s.color, s.width)
                } else if (s.type === "rect") {
                    drawRect(s.x, s.y, s.w, s.h, s.color, s.width)
                } else if (s.type === "blur") {
                    drawBlurPreview(s.x, s.y, s.w, s.h)
                }
            }

            // 2. Отрисовка текущей рисуемой фигуры
            if (root.isDragging) {
                if (root.currentTool === "pen" && root.activePenPoints.length >= 2) {
                    ctx.strokeStyle = root.currentColor
                    ctx.lineWidth = root.strokeWidth
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(root.activePenPoints[0][0], root.activePenPoints[0][1])
                    for (var k = 1; k < root.activePenPoints.length; k++) {
                        ctx.lineTo(root.activePenPoints[k][0], root.activePenPoints[k][1])
                    }
                    ctx.stroke()
                } else if (root.currentTool === "arrow") {
                    drawArrow(root.dragStartX, root.dragStartY, root.currentX, root.currentY, root.currentColor, root.strokeWidth)
                } else if (root.currentTool === "rect") {
                    var rx = Math.min(root.dragStartX, root.currentX)
                    var ry = Math.min(root.dragStartY, root.currentY)
                    var rw = Math.abs(root.currentX - root.dragStartX)
                    var rh = Math.abs(root.currentY - root.dragStartY)
                    drawRect(rx, ry, rw, rh, root.currentColor, root.strokeWidth)
                } else if (root.currentTool === "blur") {
                    var bx = Math.min(root.dragStartX, root.currentX)
                    var by = Math.min(root.dragStartY, root.currentY)
                    var bw = Math.abs(root.currentX - root.dragStartX)
                    var bh = Math.abs(root.currentY - root.dragStartY)
                    drawBlurPreview(bx, by, bw, bh)
                }
            }
        }
    }

    // ========================================================
    // 5. ОБРАБОТЧИК МЫШИ (DRAG & DRAW)
    // ========================================================
    MouseArea {
        id: mainMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.currentTool === "crop" ? Qt.CrossCursor : Qt.ArrowCursor

        onPressed: mouse => {
            root.forceActiveFocus()
            root.isDragging = true
            root.dragStartX = mouse.x
            root.dragStartY = mouse.y
            root.currentX = mouse.x
            root.currentY = mouse.y

            if (root.currentTool === "pen") {
                root.activePenPoints = [[mouse.x, mouse.y]]
            } else if (root.currentTool === "crop") {
                root.hasCrop = true
                root.cropX = mouse.x
                root.cropY = mouse.y
                root.cropW = 0
                root.cropH = 0
            }
            drawCanvas.requestPaint()
        }

        onPositionChanged: mouse => {
            if (!root.isDragging) return
            root.currentX = mouse.x
            root.currentY = mouse.y

            if (root.currentTool === "crop") {
                var x1 = Math.min(root.dragStartX, mouse.x)
                var y1 = Math.min(root.dragStartY, mouse.y)
                var w = Math.abs(mouse.x - root.dragStartX)
                var h = Math.abs(mouse.y - root.dragStartY)
                root.cropX = x1
                root.cropY = y1
                root.cropW = w
                root.cropH = h
            } else if (root.currentTool === "pen") {
                var pts = root.activePenPoints
                pts.push([mouse.x, mouse.y])
                root.activePenPoints = pts
                drawCanvas.requestPaint()
            } else {
                drawCanvas.requestPaint()
            }
        }

        onReleased: mouse => {
            if (!root.isDragging) return
            root.isDragging = false

            if (root.currentTool === "crop") {
                if (root.cropW < 10 || root.cropH < 10) {
                    root.hasCrop = false
                }
            } else if (root.currentTool === "pen") {
                if (root.activePenPoints.length >= 2) {
                    var newShapes = root.shapes.slice()
                    newShapes.push({
                        type: "pen",
                        points: root.activePenPoints,
                        color: root.currentColor.toString(),
                        width: root.strokeWidth
                    })
                    root.shapes = newShapes
                }
                root.activePenPoints = []
            } else if (root.currentTool === "arrow") {
                var dist = Math.hypot(mouse.x - root.dragStartX, mouse.y - root.dragStartY)
                if (dist > 10) {
                    var newShapes = root.shapes.slice()
                    newShapes.push({
                        type: "arrow",
                        x1: root.dragStartX,
                        y1: root.dragStartY,
                        x2: mouse.x,
                        y2: mouse.y,
                        color: root.currentColor.toString(),
                        width: root.strokeWidth
                    })
                    root.shapes = newShapes
                }
            } else if (root.currentTool === "rect") {
                var rw = Math.abs(mouse.x - root.dragStartX)
                var rh = Math.abs(mouse.y - root.dragStartY)
                if (rw > 5 && rh > 5) {
                    var newShapes = root.shapes.slice()
                    newShapes.push({
                        type: "rect",
                        x: Math.min(root.dragStartX, mouse.x),
                        y: Math.min(root.dragStartY, mouse.y),
                        w: rw,
                        h: rh,
                        color: root.currentColor.toString(),
                        width: root.strokeWidth
                    })
                    root.shapes = newShapes
                }
            } else if (root.currentTool === "blur") {
                var bw = Math.abs(mouse.x - root.dragStartX)
                var bh = Math.abs(mouse.y - root.dragStartY)
                if (bw > 5 && bh > 5) {
                    var newShapes = root.shapes.slice()
                    newShapes.push({
                        type: "blur",
                        x: Math.min(root.dragStartX, mouse.x),
                        y: Math.min(root.dragStartY, mouse.y),
                        w: bw,
                        h: bh
                    })
                    root.shapes = newShapes
                }
            }

            drawCanvas.requestPaint()
        }
    }

    // ========================================================
    // 6. ВСПЛЫВАЮЩАЯ ПОДСКАЗКА СВЕРХУ (HINT BANNER)
    // ========================================================
    Rectangle {
        antialiasing: true
        id: hintBanner
        visible: !root.hasCrop
        anchors.horizontalCenter: parent.horizontalCenter
        y: 28
        height: 38
        implicitWidth: hintRow.implicitWidth + 32
        radius: 19
        color: root.cfg.bgSurface
        border.color: root.cfg.borderCol
        border.width: 1

        RowLayout {
            id: hintRow
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "󰄀"
                font.pixelSize: 16
                color: root.cfg.accent
                font.family: "JetBrainsMono Nerd Font, monospace"
            }

            Text {
                text: "Выделите область мышью"
                font.pixelSize: 13
                font.bold: true
                color: root.cfg.textPrimary
                font.family: root.cfg.fontFamily
            }

            Rectangle { width: 4; height: 4; radius: 2; color: root.cfg.borderCol }

            Text {
                text: "↵ Сохранить весь экран"
                font.pixelSize: 12
                color: root.cfg.textMuted
                font.family: root.cfg.fontFamily
            }

            Rectangle { width: 4; height: 4; radius: 2; color: root.cfg.borderCol }

            Text {
                text: "Esc Отмена"
                font.pixelSize: 12
                color: root.cfg.textMuted
                font.family: root.cfg.fontFamily
            }
        }
    }

    // ========================================================
    // 7. MATERIAL YOU ПЛАВАЮЩАЯ ПАНЕЛЬ ИНСТРУМЕНТОВ (TOOLBAR)
    // ========================================================
    Rectangle {
        antialiasing: true
        id: toolBar
        visible: root.hasCrop || root.shapes.length > 0
        height: 48
        implicitWidth: toolRow.implicitWidth + 24
        radius: 24
        color: root.cfg.bgSurface
        border.color: root.cfg.borderCol
        border.width: 1

        // Умное позиционирование рядом с областью выделения
        x: Math.max(20, Math.min(root.width - width - 20, root.hasCrop ? (root.cropX + (root.cropW - width) / 2) : (root.width - width) / 2))
        y: {
            if (!root.hasCrop) return root.height - 80
            if (root.cropY + root.cropH + 16 + height < root.height) {
                return root.cropY + root.cropH + 16
            } else {
                return Math.max(16, root.cropY - height - 16)
            }
        }

        // Блокируем передачу кликов на canvas
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        RowLayout {
            id: toolRow
            anchors.centerIn: parent
            spacing: 6

            // Кнопка: Кадрирование/Выделение
            Rectangle {
                antialiasing: true
                width: 36; height: 36; radius: 18
                color: root.currentTool === "crop" ? root.cfg.accentContainer : "transparent"
                border.color: root.currentTool === "crop" ? root.cfg.accent : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰄀"
                    font.pixelSize: 16
                    color: root.currentTool === "crop" ? root.cfg.accent : root.cfg.textMuted
                    font.family: "JetBrainsMono Nerd Font, monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTool = "crop"
                }
            }

            // Кнопка: Карандаш
            Rectangle {
                antialiasing: true
                width: 36; height: 36; radius: 18
                color: root.currentTool === "pen" ? root.cfg.accentContainer : "transparent"
                border.color: root.currentTool === "pen" ? root.cfg.accent : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰈞"
                    font.pixelSize: 16
                    color: root.currentTool === "pen" ? root.cfg.accent : root.cfg.textMuted
                    font.family: "JetBrainsMono Nerd Font, monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTool = "pen"
                }
            }

            // Кнопка: Стрелка
            Rectangle {
                antialiasing: true
                width: 36; height: 36; radius: 18
                color: root.currentTool === "arrow" ? root.cfg.accentContainer : "transparent"
                border.color: root.currentTool === "arrow" ? root.cfg.accent : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰤨"
                    font.pixelSize: 16
                    color: root.currentTool === "arrow" ? root.cfg.accent : root.cfg.textMuted
                    font.family: "JetBrainsMono Nerd Font, monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTool = "arrow"
                }
            }

            // Кнопка: Рамка / Прямоугольник
            Rectangle {
                antialiasing: true
                width: 36; height: 36; radius: 18
                color: root.currentTool === "rect" ? root.cfg.accentContainer : "transparent"
                border.color: root.currentTool === "rect" ? root.cfg.accent : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰗘"
                    font.pixelSize: 16
                    color: root.currentTool === "rect" ? root.cfg.accent : root.cfg.textMuted
                    font.family: "JetBrainsMono Nerd Font, monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTool = "rect"
                }
            }

            // Кнопка: Размытие / Цензура
            Rectangle {
                antialiasing: true
                width: 36; height: 36; radius: 18
                color: root.currentTool === "blur" ? root.cfg.accentContainer : "transparent"
                border.color: root.currentTool === "blur" ? root.cfg.accent : "transparent"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰓢"
                    font.pixelSize: 16
                    color: root.currentTool === "blur" ? root.cfg.accent : root.cfg.textMuted
                    font.family: "JetBrainsMono Nerd Font, monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTool = "blur"
                }
            }

            // Разделитель
            Rectangle { width: 1; height: 22; color: root.cfg.borderCol }

            // Палитра цветов (Цветные точки)
            Repeater {
                model: [
                    { col: root.cfg.accent },
                    { col: "#ff5449" },
                    { col: "#facc15" },
                    { col: "#4ade80" },
                    { col: "#38bdf8" },
                    { col: "#ffffff" }
                ]

                Rectangle {
                    antialiasing: true
                    required property var modelData
                    width: 22; height: 22; radius: 11
                    color: modelData.col
                    border.color: root.currentColor === modelData.col ? "#ffffff" : "transparent"
                    border.width: 2

                    Rectangle {
                        antialiasing: true
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: 14
                        color: "transparent"
                        border.color: root.currentColor === modelData.col ? modelData.col : "transparent"
                        border.width: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentColor = modelData.col
                            if (root.currentTool === "crop") root.currentTool = "pen"
                        }
                    }
                }
            }

            // Разделитель
            Rectangle { width: 1; height: 22; color: root.cfg.borderCol }

            // Отменить (Undo)
            Rectangle {
                antialiasing: true
                width: 36; height: 36; radius: 18
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰕌"
                    font.pixelSize: 16
                    color: root.cfg.textMuted
                    font.family: "JetBrainsMono Nerd Font, monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.undo()
                }
            }

            // Очистить (Reset)
            Rectangle {
                antialiasing: true
                width: 36; height: 36; radius: 18
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰃢"
                    font.pixelSize: 16
                    color: root.cfg.textMuted
                    font.family: "JetBrainsMono Nerd Font, monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearAll()
                }
            }

            // Закрыть / Отмена (Esc)
            Rectangle {
                antialiasing: true
                width: 36; height: 36; radius: 18
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.pixelSize: 16
                    color: root.cfg.danger
                    font.family: "JetBrainsMono Nerd Font, monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeOverlay()
                }
            }

            // Главная кнопка: СОХРАНИТЬ (ENTER)
            Rectangle {
                antialiasing: true
                height: 36
                implicitWidth: saveRow.implicitWidth + 24
                radius: 18
                color: root.cfg.accent

                RowLayout {
                    id: saveRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰆏"
                        font.pixelSize: 15
                        color: root.cfg.accentText
                        font.family: "JetBrainsMono Nerd Font, monospace"
                    }

                    Text {
                        text: "Сохранить"
                        font.pixelSize: 13
                        font.bold: true
                        color: root.cfg.accentText
                        font.family: root.cfg.fontFamily
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.commitSave()
                }
            }
        }
    }
}
