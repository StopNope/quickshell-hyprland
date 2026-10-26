import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "./widgets"

Item {
    id: root

    required property var cfg
    property string mode: "widgets" // "widgets", "osd" или "bar"
    property bool isOpen: false
    property var currentScreen: null

    // Определение смещения текущего монитора в общем глобальном пространстве Hyprland
    readonly property var screenOffset: root.cfg.getScreenOffset(root.currentScreen ? root.currentScreen.name : "")
    readonly property int monX: screenOffset ? screenOffset.x : 0
    readonly property int monY: screenOffset ? screenOffset.y : 0
    readonly property int monW: screenOffset ? screenOffset.w : (root.currentScreen ? root.currentScreen.width : 1920)
    readonly property int monH: screenOffset ? screenOffset.h : (root.currentScreen ? root.currentScreen.height : 1080)
    readonly property bool isPrimaryScreen: !root.currentScreen || root.currentScreen.name === "DP-2"

    signal closeRequested()

    focus: true
    Keys.onEscapePressed: root.closeEditor()

    // Направляющие выравнивания (PowerPoint-style smart alignment guides)
    property var activeGuides: []

    // ================= ИНТЕРАКТИВНЫЙ РЕДАКТОР БАРА (DIRECT DRAG & DROP) =================
    property string draggingBarModId: ""
    property string draggingSourceZone: ""
    property int draggingSourceIndex: -1
    property real barDragX: 0
    property real barDragY: 0
    property string barHoverZone: ""
    property int barTargetDropIndex: -1
    property real barMarkerX: 0

    function startBarModDrag(modId, sourceZone, srcIdx, gx, gy) {
        draggingBarModId = modId
        draggingSourceZone = sourceZone
        draggingSourceIndex = (typeof srcIdx === "number") ? srcIdx : -1
        barDragX = gx
        barDragY = gy
        barHoverZone = sourceZone
        barTargetDropIndex = draggingSourceIndex
        updateBarModDrag(gx, gy)
    }

    function updateBarModDrag(gx, gy) {
        barDragX = gx
        barDragY = gy

        if (!onScreenBarCapsule) return

        let capsulePos = onScreenBarCapsule.mapFromItem(root, gx, gy)
        let barW = onScreenBarCapsule.width
        let barH = onScreenBarCapsule.height

        // 1. Проверяем зону сброса в склад (удаление из бара в центр экрана)
        if (root.cfg.barPosition === "top" && capsulePos.y > (barH + 45) && gy < (root.height - 110)) {
            barHoverZone = "trash"
            barTargetDropIndex = -1
            barMarkerX = 0
            return
        }
        if (root.cfg.barPosition === "bottom" && capsulePos.y < -45 && gy > 110) {
            barHoverZone = "trash"
            barTargetDropIndex = -1
            barMarkerX = 0
            return
        }

        // 2. Определяем горизонтальную зону бара (left, center, right)
        let leftRightEdge = (leftZoneBox && leftZoneBox.width > 0) ? (leftZoneBox.x + leftZoneBox.width) : 250
        let centerLeftEdge = (centerZoneBox && centerZoneBox.width > 0) ? centerZoneBox.x : (barW / 2 - 100)
        let centerRightEdge = (centerZoneBox && centerZoneBox.width > 0) ? (centerZoneBox.x + centerZoneBox.width) : (barW / 2 + 100)
        let rightLeftEdge = (rightZoneBox && rightZoneBox.width > 0) ? rightZoneBox.x : (barW - 350)

        let splitLeftCenter = (leftRightEdge + centerLeftEdge) / 2
        let splitCenterRight = (centerRightEdge + rightLeftEdge) / 2

        let localX = capsulePos.x
        let chosenZone = "center"
        if (localX < splitLeftCenter) chosenZone = "left"
        else if (localX > splitCenterRight) chosenZone = "right"
        else chosenZone = "center"

        barHoverZone = chosenZone

        // 3. Вычисляем точный индекс вставки и позицию маркера внутри chosenZone
        let repeater = (chosenZone === "left" ? leftModRepeater : (chosenZone === "center" ? centerModRepeater : rightModRepeater))
        let targetBox = (chosenZone === "left" ? leftZoneBox : (chosenZone === "center" ? centerZoneBox : rightZoneBox))
        let targetList = (chosenZone === "left" ? root.cfg.barModulesLeft : (chosenZone === "center" ? root.cfg.barModulesCenter : root.cfg.barModulesRight)) || []

        if (!repeater || targetList.length === 0 || !targetBox) {
            barTargetDropIndex = 0
            barMarkerX = targetBox ? (targetBox.x + targetBox.width / 2) : (barW / 2)
            return
        }

        let count = repeater.count
        if (count === 0) {
            barTargetDropIndex = 0
            barMarkerX = targetBox.x + 20
            return
        }

        // Собираем экранные координаты каждого чипа
        let chipItems = []
        for (let i = 0; i < count; i++) {
            let chip = repeater.itemAt(i)
            if (chip) {
                let mappedChip = chip.mapToItem(onScreenBarCapsule, 0, 0)
                chipItems.push({
                    left: mappedChip.x,
                    right: mappedChip.x + chip.width,
                    midX: mappedChip.x + chip.width / 2
                })
            }
        }

        if (chipItems.length === 0) {
            barTargetDropIndex = 0
            barMarkerX = targetBox.x + 20
            return
        }

        // Проверяем, перед каким чипом находится курсор
        let targetIdx = chipItems.length
        let markerPos = chipItems[chipItems.length - 1].right + 4

        if (localX < chipItems[0].midX) {
            targetIdx = 0
            markerPos = Math.max(targetBox.x, chipItems[0].left - 4)
        } else {
            for (let i = 0; i < chipItems.length - 1; i++) {
                if (localX >= chipItems[i].midX && localX < chipItems[i + 1].midX) {
                    targetIdx = i + 1
                    markerPos = (chipItems[i].right + chipItems[i + 1].left) / 2
                    break
                }
            }
        }

        barTargetDropIndex = targetIdx
        barMarkerX = markerPos
    }

    function finishBarModDrag() {
        if (!draggingBarModId) return

        if (barHoverZone === "trash") {
            root.cfg.removeBarModule(draggingBarModId)
        } else if (barHoverZone === "left" || barHoverZone === "center" || barHoverZone === "right") {
            let targetIdx = barTargetDropIndex >= 0 ? barTargetDropIndex : 999

            // Если перемещаем внутри одной и той же зоны, корректируем индекс
            let finalIdx = targetIdx
            if (draggingSourceZone === barHoverZone && draggingSourceIndex >= 0 && targetIdx > draggingSourceIndex) {
                finalIdx = targetIdx - 1
            }

            root.cfg.insertBarModuleAt(draggingBarModId, barHoverZone, finalIdx)
        }

        draggingBarModId = ""
        draggingSourceZone = ""
        draggingSourceIndex = -1
        barHoverZone = ""
        barTargetDropIndex = -1
        barMarkerX = 0
    }

    function openEditor(editMode) {
        mode = editMode || "widgets"
        isOpen = true
        activeGuides = []
        root.forceActiveFocus()
    }

    function closeEditor() {
        isOpen = false
        activeGuides = []
        root.cfg.save()
        closeRequested()
    }

    function getBarModInfo(modId) {
        if (!root.cfg || !root.cfg.allBarModules) return { id: modId, name: modId, icon: "󰍛" }
        if (typeof modId === "string" && modId.indexOf("+") !== -1) {
            let parts = modId.split("+")
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
            return { id: modId, name: names.join(" + "), icon: icons.join(" "), isGroup: true, parts: parts }
        }
        for (let i = 0; i < root.cfg.allBarModules.length; i++) {
            if (root.cfg.allBarModules[i].id === modId) return root.cfg.allBarModules[i]
        }
        return { id: modId, name: modId, icon: "󰍛" }
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

    // Вычисление умного выравнивания (Center X/Y, edge-to-edge alignment with other widgets)
    function calculateSmartSnap(targetId, curX, curY, w, h) {
        let threshold = 20
        let snapX = curX
        let snapY = curY
        let guides = []

        let centerX = curX + w / 2
        let centerY = curY + h / 2

        let screenCenterX = Math.round(root.width / 2)
        let screenCenterY = Math.round(root.height / 2)

        // 1. Центр экрана по вертикали и горизонтали
        if (Math.abs(centerX - screenCenterX) < threshold) {
            snapX = screenCenterX - w / 2
            guides.push({ type: "v", pos: screenCenterX, label: "Центр экрана" })
        }
        if (Math.abs(centerY - screenCenterY) < threshold) {
            snapY = screenCenterY - h / 2
            guides.push({ type: "h", pos: screenCenterY, label: "Центр экрана" })
        }

        // 2. Отступы от краев экрана
        if (Math.abs(curX - 40) < threshold) {
            snapX = 40
            guides.push({ type: "v", pos: 40, label: "Левый край" })
        } else if (Math.abs((curX + w) - (root.width - 40)) < threshold) {
            snapX = root.width - 40 - w
            guides.push({ type: "v", pos: root.width - 40, label: "Правый край" })
        }
        if (Math.abs(curY - 60) < threshold) {
            snapY = 60
            guides.push({ type: "h", pos: 60, label: "Отступ от бара" })
        }

        // 3. Выравнивание относительно других виджетов
        for (let i = 0; i < root.cfg.desktopWidgets.length; i++) {
            let other = root.cfg.desktopWidgets[i]
            if (!other || other.id === targetId || other.visible === false) continue

            let otherLeft = (other.x !== undefined ? other.x : 100) - root.monX
            let otherCenterX = otherLeft + (other.w || 260) / 2
            let otherRight = otherLeft + (other.w || 260)

            let otherTop = (other.y !== undefined ? other.y : 100) - root.monY
            let otherCenterY = otherTop + (other.h || 130) / 2
            let otherBottom = otherTop + (other.h || 130)

            // X-выравнивание:
            if (Math.abs(curX - otherLeft) < threshold) {
                snapX = otherLeft
                guides.push({ type: "v", pos: otherLeft, label: "Левый край" })
            } else if (Math.abs(centerX - otherCenterX) < threshold) {
                snapX = otherCenterX - w / 2
                guides.push({ type: "v", pos: otherCenterX, label: "По центру" })
            } else if (Math.abs((curX + w) - otherRight) < threshold) {
                snapX = otherRight - w
                guides.push({ type: "v", pos: otherRight, label: "Правый край" })
            }

            // Y-выравнивание:
            if (Math.abs(curY - otherTop) < threshold) {
                snapY = otherTop
                guides.push({ type: "h", pos: otherTop, label: "Верхний край" })
            } else if (Math.abs(centerY - otherCenterY) < threshold) {
                snapY = otherCenterY - h / 2
                guides.push({ type: "h", pos: otherCenterY, label: "По центру" })
            } else if (Math.abs((curY + h) - otherBottom) < threshold) {
                snapY = otherBottom - h
                guides.push({ type: "h", pos: otherBottom, label: "Нижний край" })
            }
        }

        return { x: snapX, y: snapY, guides: guides }
    }

    // Вычисление умного примагничивания при динамическом изменении размера виджетов
    function calculateResizeSnap(targetId, curX, curY, curW, curH) {
        let threshold = 16
        let snapW = curW
        let snapH = curH
        let guides = []

        let screenCenterX = Math.round(root.width / 2)
        let rightEdge = curX + curW
        let bottomEdge = curY + curH

        // 1. Примагничивание правого края к центру экрана
        if (Math.abs(rightEdge - screenCenterX) < threshold) {
            snapW = screenCenterX - curX
            guides.push({ type: "v", pos: screenCenterX, label: "Центр экрана" })
        }

        // 2. Примагничивание правого края к правому отступу экрана (width - 40)
        if (Math.abs(rightEdge - (root.width - 40)) < threshold) {
            snapW = (root.width - 40) - curX
            guides.push({ type: "v", pos: root.width - 40, label: "Правый край" })
        }

        // 3. Выравнивание относительно размеров других виджетов
        for (let i = 0; i < root.cfg.desktopWidgets.length; i++) {
            let other = root.cfg.desktopWidgets[i]
            if (!other || other.id === targetId || other.visible === false) continue

            let otherLeft = (other.x !== undefined ? other.x : 100) - root.monX
            let otherTop = (other.y !== undefined ? other.y : 100) - root.monY
            let otherRight = otherLeft + (other.w || 260)
            let otherBottom = otherTop + (other.h || 130)
            let otherW = (other.w || 260)
            let otherH = (other.h || 130)

            if (Math.abs(rightEdge - otherRight) < threshold) {
                snapW = otherRight - curX
                guides.push({ type: "v", pos: otherRight, label: "По краю виджета" })
            } else if (Math.abs(curW - otherW) < threshold) {
                snapW = otherW
                guides.push({ type: "v", pos: curX + otherW, label: "Одинаковая ширина (" + Math.round(otherW) + " px)" })
            }

            if (Math.abs(bottomEdge - otherBottom) < threshold) {
                snapH = otherBottom - curY
                guides.push({ type: "h", pos: otherBottom, label: "По нижнему краю" })
            } else if (Math.abs(curH - otherH) < threshold) {
                snapH = otherH
                guides.push({ type: "h", pos: curY + otherH, label: "Одинаковая высота (" + Math.round(otherH) + " px)" })
            }
        }

        return { w: Math.max(160, snapW), h: Math.max(80, snapH), guides: guides }
    }

    // 1. Полупрозрачное затемнение рабочего стола с точечной сеткой
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        Canvas {
            anchors.fill: parent
            opacity: 0.15
            onPaint: {
                let ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                let step = 40
                ctx.beginPath()
                for (let x = 0; x < width; x += step) {
                    for (let y = 0; y < height; y += step) {
                        ctx.arc(x, y, 1, 0, 2 * Math.PI)
                    }
                }
                ctx.fillStyle = root.cfg.accent
                ctx.fill()
            }
        }
    }

    // =========================================================
    // POWERPOINT-STYLE СМАРТ-НАПРАВЛЯЮЩИЕ (ЖИВЫЕ ЛИНИИ)
    // =========================================================
    Item {
        anchors.fill: parent
        z: 90
        visible: root.activeGuides.length > 0

        Repeater {
            model: root.activeGuides

            Item {
                anchors.fill: parent
                required property var modelData

                // Вертикальная направляющая
                Rectangle {
                    visible: modelData.type === "v"
                    x: modelData.pos - 1
                    y: 0
                    width: 2
                    height: root.height
                    color: root.cfg.accent
                    opacity: 0.85

                    // Бейдж с надписью у верхнего края
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 20
                        height: 20
                        implicitWidth: vTxt.implicitWidth + 12
                        radius: 10
                        color: root.cfg.accent
                        Text {
                            id: vTxt
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.cfg.accentText
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }
                }

                // Горизонтальная направляющая
                Rectangle {
                    visible: modelData.type === "h"
                    x: 0
                    y: modelData.pos - 1
                    width: root.width
                    height: 2
                    color: root.cfg.accent
                    opacity: 0.85

                    // Бейдж с надписью у левого края
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 20
                        height: 20
                        implicitWidth: hTxt.implicitWidth + 12
                        radius: 10
                        color: root.cfg.accent
                        Text {
                            id: hTxt
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.cfg.accentText
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // РЕЖИМ 1: РЕДАКТИРОВАНИЕ ВИДЖЕТОВ НА РАБОЧЕМ СТОЛЕ
    // =========================================================
    Item {
        anchors.fill: parent
        visible: root.mode === "widgets"

        Repeater {
            model: root.cfg.desktopWidgets

            Item {
                id: dragBox
                required property var modelData
                readonly property var widgetItem: modelData

                readonly property int rawGlobalX: modelData.x !== undefined ? modelData.x : 100
                readonly property int rawGlobalY: modelData.y !== undefined ? modelData.y : 100
                readonly property int initialLocalX: rawGlobalX - root.monX
                readonly property int initialLocalY: rawGlobalY - root.monY

                x: isDragging ? dragBox.x : initialLocalX
                y: isDragging ? dragBox.y : initialLocalY
                width: boxW
                height: boxH

                property real boxW: modelData.w || 260
                property real boxH: modelData.h || 130
                property bool isResizing: false
                property bool isDragging: dragArea.isDragging
                property bool colorPaletteOpen: false
                property bool radiusPopupOpen: false
                readonly property int currentRadius: (modelData.radius !== undefined) ? modelData.radius : (root.cfg.widgetRadius || 28)

                // Виджет виден в редакторе, если он попадает на данный экран или перетаскивается
                visible: (modelData.visible !== false) && (isDragging || ((initialLocalX + boxW > 0) && (initialLocalX < root.monW) && (initialLocalY + boxH > 0) && (initialLocalY < root.monH)))

                onWidgetItemChanged: {
                    if (!isResizing) {
                        boxW = modelData.w || 260
                        boxH = modelData.h || 130
                    }
                }

                z: (isResizing || isDragging || dragArea.containsMouse || colorPaletteOpen || radiusPopupOpen) ? 100 : 1

                // Визуальный контент виджета
                Loader {
                    anchors.fill: parent
                    property var itemData: modelData
                    sourceComponent: {
                        let t = modelData.type
                        if (t === "clock") return clockComp
                        if (t === "weather") return weatherComp
                        if (t === "vitals") return vitalsComp
                        if (t === "player") return playerComp
                        if (t === "calendar") return calendarComp
                        if (t === "notes") return notesComp
                        if (t === "storage") return storageComp
                        return clockComp
                    }
                }

                // Интерактивная рамка перетаскивания и изменения размера
                Rectangle {
                    anchors.fill: parent
                    radius: dragBox.currentRadius
                    color: (dragArea.drag.active || dragBox.isResizing) ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.15) : "transparent"
                    border.color: root.cfg.accent
                    border.width: (dragArea.drag.active || dragBox.isResizing) ? 2.5 : 1.5

                    // Верхняя панель управления виджетом (Тип + Размеры S/M/L + Кастомный размер + Вид + Удалить)
                    Rectangle {
                        anchors.bottom: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 8
                        height: 28
                        implicitWidth: wControlsRow.implicitWidth + 16
                        radius: 14
                        color: root.cfg.bgSurface
                        border.color: root.cfg.borderCol
                        border.width: 1
                        z: 10

                        // Плавающее меню настройки скругления (Слайдер + Пресеты + Применить ко всем)
                        Rectangle {
                            anchors.bottom: dragBox.y < 80 ? undefined : parent.top
                            anchors.top: dragBox.y < 80 ? parent.bottom : undefined
                            anchors.bottomMargin: 6
                            anchors.topMargin: 6
                            x: {
                                let idealX = (parent.width - width) / 2
                                let scrX = dragBox.x + parent.x + idealX
                                if (scrX < 16) return idealX + (16 - scrX)
                                if (scrX + width > root.monW - 16) return idealX - ((scrX + width) - (root.monW - 16))
                                return idealX
                            }
                            visible: dragBox.radiusPopupOpen
                            height: 40
                            implicitWidth: radiusControlRow.implicitWidth + 24
                            radius: 20
                            color: root.cfg.surfaceContainerHigh || Qt.rgba(0.14, 0.15, 0.19, 0.98)
                            border.color: root.cfg.accent
                            border.width: 1.5
                            z: 55

                            RowLayout {
                                id: radiusControlRow
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "󰚌 Скругление:"
                                    color: root.cfg.textPrimary
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                // Кнопка - (шаг 1px)
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: minusM.containsMouse ? root.cfg.bgElevated : root.cfg.bgSurface
                                    border.color: root.cfg.borderCol
                                    border.width: 1
                                    Text { anchors.centerIn: parent; text: "−"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true }
                                    MouseArea {
                                        id: minusM
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.cfg.setWidgetRadius(dragBox.widgetItem.id, Math.max(0, dragBox.currentRadius - 1))
                                    }
                                }

                                // Интерактивный ползунок скругления (Slider)
                                Item {
                                    id: wSliderItem
                                    width: 110
                                    height: 20

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 6
                                        radius: 3
                                        color: root.cfg.bgSurface || Qt.rgba(1, 1, 1, 0.15)

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: Math.max(6, (dragBox.currentRadius / 52) * parent.width)
                                            radius: 3
                                            color: root.cfg.accent
                                        }
                                    }

                                    Rectangle {
                                        x: Math.max(0, Math.min(wSliderItem.width - width, (dragBox.currentRadius / 52) * (wSliderItem.width - width)))
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: wSliderMouse.containsMouse || wSliderMouse.pressed ? root.cfg.accent : "#ffffff"
                                        border.color: root.cfg.accent
                                        border.width: 2
                                        scale: wSliderMouse.pressed ? 1.2 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 80 } }
                                    }

                                    MouseArea {
                                        id: wSliderMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        function updateRadius(mx) {
                                            let ratio = Math.max(0, Math.min(1, mx / width))
                                            let r = Math.round(ratio * 52)
                                            root.cfg.setWidgetRadius(dragBox.widgetItem.id, r)
                                        }

                                        onPressed: mouse => updateRadius(mouse.x)
                                        onPositionChanged: mouse => {
                                            if (pressed) updateRadius(mouse.x)
                                        }
                                    }
                                }

                                // Кнопка + (шаг 1px)
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: plusM.containsMouse ? root.cfg.bgElevated : root.cfg.bgSurface
                                    border.color: root.cfg.borderCol
                                    border.width: 1
                                    Text { anchors.centerIn: parent; text: "+"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true }
                                    MouseArea {
                                        id: plusM
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.cfg.setWidgetRadius(dragBox.widgetItem.id, Math.min(56, dragBox.currentRadius + 1))
                                    }
                                }

                                // Значение
                                Text {
                                    text: dragBox.currentRadius + " px"
                                    color: root.cfg.accent
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                Rectangle { width: 1; height: 16; color: root.cfg.borderCol }

                                // Быстрые пресеты: 0, 14, 28, 40
                                Repeater {
                                    model: [
                                        { label: "0", val: 0 },
                                        { label: "14", val: 14 },
                                        { label: "28", val: 28 },
                                        { label: "40", val: 40 }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        width: 22
                                        height: 22
                                        radius: 11
                                        readonly property bool isCur: dragBox.currentRadius === modelData.val
                                        color: isCur ? root.cfg.accent : (pM.containsMouse ? root.cfg.bgElevated : root.cfg.bgSurface)
                                        border.color: isCur ? root.cfg.accent : root.cfg.borderCol
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: isCur ? root.cfg.accentText : root.cfg.textPrimary
                                            font.pixelSize: 8
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: pM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.cfg.setWidgetRadius(dragBox.widgetItem.id, modelData.val)
                                        }
                                    }
                                }

                                Rectangle { width: 1; height: 16; color: root.cfg.borderCol }

                                // Кнопка «Применить ко всем»
                                Rectangle {
                                    height: 22
                                    implicitWidth: allBtnTxt.implicitWidth + 12
                                    radius: 11
                                    color: allBtnM.containsMouse ? root.cfg.accent : root.cfg.bgSurface
                                    border.color: root.cfg.accent
                                    border.width: 1

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text { text: "󰈈"; color: allBtnM.containsMouse ? root.cfg.accentText : root.cfg.accent; font.pixelSize: 9 }
                                        Text {
                                            id: allBtnTxt
                                            text: "Ко всем"
                                            color: allBtnM.containsMouse ? root.cfg.accentText : root.cfg.accent
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        id: allBtnM
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.cfg.setAllWidgetsRadius(dragBox.currentRadius)
                                        }
                                    }
                                }
                            }
                        }

                        // Плавающая палитра выбора цвета часов (быстрый выбор в 1 клик)
                        Rectangle {
                            anchors.bottom: dragBox.y < 80 ? undefined : parent.top
                            anchors.top: dragBox.y < 80 ? parent.bottom : undefined
                            anchors.bottomMargin: 6
                            anchors.topMargin: 6
                            x: {
                                let idealX = (parent.width - width) / 2
                                let scrX = dragBox.x + parent.x + idealX
                                if (scrX < 16) return idealX + (16 - scrX)
                                if (scrX + width > root.monW - 16) return idealX - ((scrX + width) - (root.monW - 16))
                                return idealX
                            }
                            visible: dragBox.colorPaletteOpen && dragBox.widgetItem.type === "clock"
                            height: 38
                            implicitWidth: colorPaletteRow.implicitWidth + 24
                            radius: 19
                            color: root.cfg.surfaceContainerHigh
                            border.color: root.cfg.accent
                            border.width: 1.5
                            z: 50

                            RowLayout {
                                id: colorPaletteRow
                                anchors.centerIn: parent
                                spacing: 7

                                Repeater {
                                    model: [
                                        { id: "lavender", name: "Лаванда", c: "#ede8f5" },
                                        { id: "monet", name: "Monet", c: root.cfg.accent },
                                        { id: "white", name: "Белый", c: "#ffffff" },
                                        { id: "mint", name: "Мята", c: "#86efac" },
                                        { id: "cyan", name: "Циан", c: "#7dd3fc" },
                                        { id: "peach", name: "Персик", c: "#fca5a5" },
                                        { id: "coral", name: "Коралл", c: "#f43f5e" },
                                        { id: "violet", name: "Фиолет", c: "#c084fc" },
                                        { id: "gold", name: "Золото", c: "#facc15" }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: modelData.c
                                        readonly property bool isCur: (dragBox.widgetItem.clockColor === modelData.id) || (!dragBox.widgetItem.clockColor && modelData.id === "lavender")
                                        border.color: isCur ? "#ffffff" : Qt.rgba(0,0,0,0.3)
                                        border.width: isCur ? 2.5 : 1
                                        scale: isCur ? 1.15 : (cM.containsMouse ? 1.1 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: isCur
                                            text: "✓"
                                            color: (modelData.id === "white" || modelData.id === "lavender" || modelData.id === "mint" || modelData.id === "gold") ? "#1e2025" : "#ffffff"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: cM
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.cfg.setWidgetClockColor(dragBox.widgetItem.id, modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            id: wControlsRow
                            anchors.centerIn: parent
                            spacing: 6

                            // Заголовок виджета
                            Text {
                                text: {
                                    let t = dragBox.widgetItem.type
                                    if (t === "clock") return "󰥔 Часы"
                                    if (t === "weather") return "󰖐 Погода"
                                    if (t === "vitals") return "󰍛 Ресурсы"
                                    if (t === "player") return "󰎆 Плеер"
                                    if (t === "calendar") return "󰸗 Календарь"
                                    if (t === "notes") return "󰏫 Заметки"
                                    if (t === "storage") return "󰋊 Диск"
                                    return "Виджет"
                                }
                                color: root.cfg.textPrimary
                                font.pixelSize: 10
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }

                            Rectangle { width: 1; height: 14; color: root.cfg.borderCol }

                            // Переключатели стандартных размеров: S, M, L
                            RowLayout {
                                spacing: 3
                                Repeater {
                                    model: ["S", "M", "L"]
                                    Rectangle {
                                        required property string modelData
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: (dragBox.widgetItem.size || "M") === modelData ? root.cfg.accent : root.cfg.bgElevated
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: (dragBox.widgetItem.size || "M") === modelData ? root.cfg.accentText : root.cfg.textMuted
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.cfg.setWidgetSize(dragBox.widgetItem.id, modelData)
                                        }
                                    }
                                }
                            }

                            Rectangle { width: 1; height: 14; color: root.cfg.borderCol }

                            // Индикатор текущего размера в пикселях
                            Rectangle {
                                height: 20
                                implicitWidth: dimTxt.implicitWidth + 10
                                radius: 10
                                color: dragBox.isResizing ? root.cfg.accent : root.cfg.bgElevated
                                Text {
                                    id: dimTxt
                                    anchors.centerIn: parent
                                    text: Math.round(dragBox.boxW) + " × " + Math.round(dragBox.boxH)
                                    color: dragBox.isResizing ? root.cfg.accentText : root.cfg.textMuted
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            Rectangle { width: 1; height: 14; color: root.cfg.borderCol }

                            // Настройка скругления углов виджета (Radius Control)
                            Rectangle {
                                height: 20
                                implicitWidth: radBtnTxt.implicitWidth + 14
                                radius: 10
                                color: dragBox.radiusPopupOpen ? root.cfg.accentContainer : (radM.containsMouse ? root.cfg.surfaceContainerHigh : root.cfg.bgElevated)
                                border.color: dragBox.radiusPopupOpen ? root.cfg.accent : root.cfg.borderCol
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "󰚌"
                                        color: dragBox.radiusPopupOpen ? root.cfg.accent : root.cfg.accent
                                        font.pixelSize: 10
                                    }
                                    Text {
                                        id: radBtnTxt
                                        text: dragBox.currentRadius + " px"
                                        color: dragBox.radiusPopupOpen ? root.cfg.accent : root.cfg.textPrimary
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: radM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dragBox.colorPaletteOpen = false
                                        dragBox.radiusPopupOpen = !dragBox.radiusPopupOpen
                                    }
                                }
                            }

                            Rectangle { width: 1; height: 14; color: root.cfg.borderCol }

                            // Переключатель вида (Variant)
                            Rectangle {
                                height: 20
                                implicitWidth: vTxt.implicitWidth + 10
                                radius: 10
                                color: root.cfg.bgElevated
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text { text: "󰒋"; color: root.cfg.accent; font.pixelSize: 9 }
                                    Text {
                                        id: vTxt
                                        text: {
                                            let v = dragBox.widgetItem.variant || "default"
                                            if (v === "stacked_duotone" || v === "minimal") return "Pixel Дуэт"
                                            if (v === "tall_digital") return "Pixel Карточка"
                                            if (v === "numeral") return "Цифры Numeral"
                                            if (v === "clover") return "Клевер Clover"
                                            if (v === "circle") return "Круг Circle"
                                            if (v === "scallop" || v === "flower") return "Цветок Scallop"
                                            if (v === "stacked_mono") return "Pixel Моно"
                                            if (v === "stacked_expressive") return "M3 Экспрессив"
                                            if (v === "pill_horizontal") return "Пилюля"
                                            if (v === "analog") return "Аналог"
                                            if (v === "bento") return "Бенто"
                                            if (v === "forecast" || v === "pixel_card") return "Pixel Погода"
                                            if (v === "pebble") return "Камушек Pixel"
                                            if (v === "pill") return "At-a-Glance"
                                            if (v === "compact") return "Компакт"
                                            if (v === "detailed") return "Подробно"
                                            if (v === "pill_strip") return "Стрип"
                                            if (v === "wavy") return "Волна"
                                            if (v === "vinyl_disc") return "Винил"
                                            if (v === "sleek_capsule") return "Капсула"
                                            if (v === "month") return "Месяц"
                                            if (v === "week_strip") return "Неделя"
                                            if (v === "minimal_pill") return "День"
                                            if (v === "bars") return "Полосы"
                                            if (v === "circles") return "Кольца"
                                            if (v === "compact_capsules") return "Капсулы"
                                            if (v === "gauges") return "Плитки"
                                            if (v === "pills_grid") return "Трио"
                                            if (v === "classic") return "Блокнот"
                                            if (v === "bullet_journal") return "Чек-лист"
                                            if (v === "sticky_card") return "Стикер"
                                            return "Вид: " + v
                                        }
                                        color: root.cfg.textPrimary
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cfg.cycleWidgetVariant(dragBox.widgetItem.id)
                                }
                            }

                            // Выбор цвета часов (открывает палитру в 1 клик)
                            Rectangle {
                                visible: dragBox.widgetItem.type === "clock"
                                height: 20
                                implicitWidth: clrTxt.implicitWidth + 14
                                radius: 10
                                color: dragBox.colorPaletteOpen ? root.cfg.accentContainer : (clrM.containsMouse ? root.cfg.surfaceContainerHigh : root.cfg.bgElevated)
                                border.color: dragBox.colorPaletteOpen ? root.cfg.accent : root.cfg.borderCol
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Rectangle {
                                        width: 10; height: 10; radius: 5
                                        color: {
                                            let c = dragBox.widgetItem.clockColor || "lavender"
                                            if (c === "lavender") return "#ede8f5"
                                            if (c === "monet") return root.cfg.accent
                                            if (c === "white") return "#ffffff"
                                            if (c === "mint") return "#86efac"
                                            if (c === "cyan") return "#7dd3fc"
                                            if (c === "peach") return "#fca5a5"
                                            if (c === "coral") return "#f43f5e"
                                            if (c === "violet") return "#c084fc"
                                            if (c === "gold") return "#facc15"
                                            return root.cfg.accent
                                        }
                                    }
                                    Text {
                                        id: clrTxt
                                        text: "Цвет"
                                        color: dragBox.colorPaletteOpen ? root.cfg.accent : root.cfg.textPrimary
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: clrM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dragBox.colorPaletteOpen = !dragBox.colorPaletteOpen
                                }
                            }

                            // Переключатель прозрачности фона виджета
                            Rectangle {
                                height: 20
                                width: 20
                                radius: 10
                                color: dragBox.widgetItem.transparentBg ? root.cfg.accent : root.cfg.bgElevated
                                border.color: root.cfg.borderCol
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: dragBox.widgetItem.transparentBg ? "󰈈" : "󰈉"
                                    color: dragBox.widgetItem.transparentBg ? root.cfg.accentText : root.cfg.textMuted
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cfg.toggleWidgetTransparent(dragBox.widgetItem.id)
                                }
                            }

                            // Кнопка удаления
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: root.cfg.danger
                                Text { anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.cfg.removeWidget(dragBox.widgetItem.id)
                                }
                            }
                        }
                    }

                    // Зона перетаскивания со смарт-направляющими (PowerPoint live magnetic snapping)
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeAllCursor

                        property real startRootX: 0
                        property real startRootY: 0
                        property real initialBoxX: 0
                        property real initialBoxY: 0
                        property bool isDragging: false

                        onPressed: mouse => {
                            isDragging = true
                            let p = mapToItem(root, mouse.x, mouse.y)
                            startRootX = p.x
                            startRootY = p.y
                            initialBoxX = dragBox.x
                            initialBoxY = dragBox.y
                        }

                        onPositionChanged: mouse => {
                            if (isDragging) {
                                let p = mapToItem(root, mouse.x, mouse.y)
                                let rawX = initialBoxX + (p.x - startRootX)
                                let rawY = initialBoxY + (p.y - startRootY)

                                let res = root.calculateSmartSnap(modelData.id, rawX, rawY, dragBox.boxW, dragBox.boxH)
                                root.activeGuides = res.guides

                                dragBox.x = Math.max(10, Math.min(root.width - dragBox.boxW - 10, res.x))
                                dragBox.y = Math.max(10, Math.min(root.height - dragBox.boxH - 10, res.y))
                            }
                        }

                        onReleased: {
                            if (isDragging) {
                                isDragging = false
                                root.activeGuides = []
                                root.cfg.updateWidgetPos(modelData.id, root.monX + Math.round(dragBox.x), root.monY + Math.round(dragBox.y))
                            }
                        }
                    }

                    // =========================================================
                    // ИНТЕРАКТИВНЫЕ МАРКЕРЫ ДИНАМИЧЕСКОГО ИЗМЕНЕНИЯ РАЗМЕРА
                    // =========================================================

                    // 1. Угловой маркер (Resize Corner ⤡)
                    Rectangle {
                        id: brCornerHandle
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -6
                        anchors.bottomMargin: -6
                        width: 26
                        height: 26
                        radius: 13
                        color: (brM.containsMouse || brM.isDragging) ? root.cfg.accent : root.cfg.bgSurface
                        border.color: root.cfg.accent
                        border.width: 2
                        z: 40
                        scale: (brM.containsMouse || brM.isDragging) ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "⤡"
                            color: (brM.containsMouse || brM.isDragging) ? root.cfg.accentText : root.cfg.accent
                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            id: brM
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.SizeFDiagCursor

                            property real startX: 0
                            property real startY: 0
                            property real initW: 0
                            property real initH: 0
                            property bool isDragging: false

                            onPressed: mouse => {
                                isDragging = true
                                dragBox.isResizing = true
                                let p = mapToItem(root, mouse.x, mouse.y)
                                startX = p.x
                                startY = p.y
                                initW = dragBox.boxW
                                initH = dragBox.boxH
                            }

                            onPositionChanged: mouse => {
                                if (isDragging) {
                                    let p = mapToItem(root, mouse.x, mouse.y)
                                    let rawW = initW + (p.x - startX)
                                    let rawH = initH + (p.y - startY)

                                    let snap = root.calculateResizeSnap(modelData.id, dragBox.x, dragBox.y, rawW, rawH)
                                    root.activeGuides = snap.guides

                                    dragBox.boxW = Math.max(160, Math.min(root.width - dragBox.x - 20, snap.w))
                                    dragBox.boxH = Math.max(80, Math.min(root.height - dragBox.y - 20, snap.h))
                                }
                            }

                            onReleased: {
                                if (isDragging) {
                                    isDragging = false
                                    dragBox.isResizing = false
                                    root.activeGuides = []
                                    root.cfg.updateWidgetDimensions(modelData.id, dragBox.boxW, dragBox.boxH)
                                }
                            }
                        }
                    }

                    // 2. Правый боковой маркер (Horizontal Resize)
                    Rectangle {
                        id: rEdgeHandle
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: -5
                        width: 10
                        height: 36
                        radius: 5
                        color: (rEdgeM.containsMouse || rEdgeM.isDragging) ? root.cfg.accent : root.cfg.bgSurface
                        border.color: root.cfg.accent
                        border.width: 1.5
                        z: 40
                        scale: (rEdgeM.containsMouse || rEdgeM.isDragging) ? 1.2 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        MouseArea {
                            id: rEdgeM
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.SizeHorCursor

                            property real startX: 0
                            property real initW: 0
                            property bool isDragging: false

                            onPressed: mouse => {
                                isDragging = true
                                dragBox.isResizing = true
                                let p = mapToItem(root, mouse.x, mouse.y)
                                startX = p.x
                                initW = dragBox.boxW
                            }

                            onPositionChanged: mouse => {
                                if (isDragging) {
                                    let p = mapToItem(root, mouse.x, mouse.y)
                                    let rawW = initW + (p.x - startX)
                                    let snap = root.calculateResizeSnap(modelData.id, dragBox.x, dragBox.y, rawW, dragBox.boxH)
                                    root.activeGuides = snap.guides
                                    dragBox.boxW = Math.max(160, Math.min(root.width - dragBox.x - 20, snap.w))
                                }
                            }

                            onReleased: {
                                if (isDragging) {
                                    isDragging = false
                                    dragBox.isResizing = false
                                    root.activeGuides = []
                                    root.cfg.updateWidgetDimensions(modelData.id, dragBox.boxW, dragBox.boxH)
                                }
                            }
                        }
                    }

                    // 3. Нижний маркер высоты (Vertical Resize)
                    Rectangle {
                        id: bEdgeHandle
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: -5
                        width: 36
                        height: 10
                        radius: 5
                        color: (bEdgeM.containsMouse || bEdgeM.isDragging) ? root.cfg.accent : root.cfg.bgSurface
                        border.color: root.cfg.accent
                        border.width: 1.5
                        z: 40
                        scale: (bEdgeM.containsMouse || bEdgeM.isDragging) ? 1.2 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        MouseArea {
                            id: bEdgeM
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor

                            property real startY: 0
                            property real initH: 0
                            property bool isDragging: false

                            onPressed: mouse => {
                                isDragging = true
                                dragBox.isResizing = true
                                let p = mapToItem(root, mouse.x, mouse.y)
                                startY = p.y
                                initH = dragBox.boxH
                            }

                            onPositionChanged: mouse => {
                                if (isDragging) {
                                    let p = mapToItem(root, mouse.x, mouse.y)
                                    let rawH = initH + (p.y - startY)
                                    let snap = root.calculateResizeSnap(modelData.id, dragBox.x, dragBox.y, dragBox.boxW, rawH)
                                    root.activeGuides = snap.guides
                                    dragBox.boxH = Math.max(80, Math.min(root.height - dragBox.y - 20, snap.h))
                                }
                            }

                            onReleased: {
                                if (isDragging) {
                                    isDragging = false
                                    dragBox.isResizing = false
                                    root.activeGuides = []
                                    root.cfg.updateWidgetDimensions(modelData.id, dragBox.boxW, dragBox.boxH)
                                }
                            }
                        }
                    }

                    // 4. Плавающий бейдж с размерами при изменении
                    Rectangle {
                        visible: dragBox.isResizing
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 12
                        height: 24
                        implicitWidth: resizeBadgeTxt.implicitWidth + 16
                        radius: 12
                        color: root.cfg.accent
                        z: 50

                        Text {
                            id: resizeBadgeTxt
                            anchors.centerIn: parent
                            text: Math.round(dragBox.boxW) + " × " + Math.round(dragBox.boxH) + " px"
                            color: root.cfg.accentText
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // РЕЖИМ 2: ИНТЕРАКТИВНОЕ ПОЗИЦИОНИРОВАНИЕ OSD НА ЭКРАНЕ
    // (РЕАЛЬНЫЕ РАЗМЕРЫ 240x44 И ТОЧНЕЙШАЯ ЦЕНТРОВКА 840px)
    // =========================================================
    Item {
        anchors.fill: parent
        visible: root.mode === "osd"

        Item {
            id: ghostOsd
            width: 240
            height: 44
            x: root.cfg.osdLeftMargin > 0 ? root.cfg.osdLeftMargin : Math.round((root.width - 240) / 2)
            y: root.cfg.osdBottomMargin > 0 ? (root.height - 44 - root.cfg.osdBottomMargin) : (root.height - 44 - 120)

            Rectangle {
                anchors.fill: parent
                radius: 22
                color: root.cfg.bgSurface
                border.color: root.cfg.accent
                border.width: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: root.cfg.accentContainer

                        Text {
                            anchors.centerIn: parent
                            text: "󰕾"
                            color: root.cfg.accent
                            font.pixelSize: 14
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 8
                        radius: 4
                        color: root.cfg.bgPrimary

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * 0.8
                            radius: 4
                            color: root.cfg.accent
                        }
                    }
                }

                // Индикатор координат и центровки
                Rectangle {
                    anchors.bottom: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 8
                    height: 22
                    implicitWidth: osdCoordTxt.implicitWidth + 16
                    radius: 11
                    color: Math.abs(ghostOsd.x - (root.width - 240) / 2) < 4 ? root.cfg.accent : root.cfg.bgElevated
                    border.color: root.cfg.accent
                    border.width: 1

                    Text {
                        id: osdCoordTxt
                        anchors.centerIn: parent
                        text: Math.abs(ghostOsd.x - (root.width - 240) / 2) < 4 ? "✓ Строго по центру (X: " + Math.round(ghostOsd.x) + " px)" : ("X: " + Math.round(ghostOsd.x) + " px • Y: " + Math.round(ghostOsd.y) + " px")
                        color: parent.color === root.cfg.accent ? root.cfg.accentText : root.cfg.textPrimary
                        font.pixelSize: 10
                        font.bold: true
                        font.family: root.cfg.fontFamily
                    }
                }

                MouseArea {
                    id: osdDrag
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor

                    property real startRootX: 0
                    property real startRootY: 0
                    property real initialOsdX: 0
                    property real initialOsdY: 0
                    property bool isDragging: false

                    onPressed: mouse => {
                        isDragging = true
                        let p = mapToItem(root, mouse.x, mouse.y)
                        startRootX = p.x
                        startRootY = p.y
                        initialOsdX = ghostOsd.x
                        initialOsdY = ghostOsd.y
                    }

                    onPositionChanged: mouse => {
                        if (isDragging) {
                            let p = mapToItem(root, mouse.x, mouse.y)
                            let rawX = initialOsdX + (p.x - startRootX)
                            let rawY = initialOsdY + (p.y - startRootY)

                            let screenCenterX = root.width / 2
                            let ghostCenterX = rawX + 120
                            let guides = []
                            let finalX = rawX

                            // Живое примагничивание к центру экрана (PowerPoint snapping)
                            if (Math.abs(ghostCenterX - screenCenterX) < 18) {
                                finalX = (root.width - 240) / 2
                                guides.push({ type: "v", pos: screenCenterX, label: "Центр экрана" })
                            }
                            root.activeGuides = guides

                            ghostOsd.x = Math.max(10, Math.min(root.width - 240 - 10, finalX))
                            ghostOsd.y = Math.max(10, Math.min(root.height - 44 - 10, rawY))
                        }
                    }

                    onReleased: {
                        if (isDragging) {
                            isDragging = false
                            root.activeGuides = []
                            root.cfg.osdLeftMargin = Math.round(ghostOsd.x)
                            root.cfg.osdBottomMargin = Math.round(root.height - ghostOsd.y - 44)
                            root.cfg.save()
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // РЕЖИМ 3: ИНТЕРАКТИВНОЕ РЕДАКТИРОВАНИЕ ПАНЕЛИ ЗАДАЧ (БАРА)
    // =========================================================
    Item {
        id: barEditorSection
        anchors.fill: parent
        visible: root.mode === "bar"

        // Чип модуля на экранной панели бара (минималистичный, без лишних надписей и стрелок)
        component BarModuleChip: Rectangle {
            id: chipItem
            required property var modelData
            required property int index
            property string zone: "center"

            readonly property bool isBeingDragged: root.draggingBarModId === modelData
            readonly property var modInfo: root.getBarModInfo(modelData)

            height: Math.max(30, (root.cfg.barHeight || 42) - 6)
            implicitWidth: chipRow.implicitWidth + 24
            radius: {
                let r = (root.cfg.barModuleRadius !== undefined) ? root.cfg.barModuleRadius : 16
                if (r >= 20 || r < 0) return height / 2
                return Math.min(height / 2, r)
            }

            color: isBeingDragged
                   ? Qt.rgba(root.cfg.primaryContainer.r, root.cfg.primaryContainer.g, root.cfg.primaryContainer.b, 0.35)
                   : (chipM.containsMouse ? root.cfg.surfaceContainerHigh : root.cfg.bgElevated)
            border.color: isBeingDragged ? root.cfg.accent : (chipM.containsMouse ? root.cfg.accent : root.cfg.borderCol)
            border.width: isBeingDragged ? 2 : 1
            opacity: isBeingDragged ? 0.38 : 1.0

            scale: chipM.pressed ? 0.95 : (chipM.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: (chipItem.modInfo && chipItem.modInfo.icon) ? chipItem.modInfo.icon : "󰍛"
                    color: root.cfg.accent
                    font.pixelSize: 13
                }

                Text {
                    text: (chipItem.modInfo && chipItem.modInfo.name) ? chipItem.modInfo.name : ""
                    color: root.cfg.textPrimary
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }

            MouseArea {
                id: chipM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property real pressX: 0
                property real pressY: 0
                property bool draggingStarted: false

                onPressed: mouse => {
                    pressX = mouse.x
                    pressY = mouse.y
                    draggingStarted = false
                }

                onPositionChanged: mouse => {
                    if (pressed) {
                        let dx = mouse.x - pressX
                        let dy = mouse.y - pressY
                        if (!draggingStarted && (Math.abs(dx) > 3 || Math.abs(dy) > 3)) {
                            draggingStarted = true
                            let mapped = mapToItem(root, mouse.x, mouse.y)
                            root.startBarModDrag(chipItem.modelData, chipItem.zone, chipItem.index, mapped.x, mapped.y)
                        }
                        if (draggingStarted) {
                            let mapped = mapToItem(root, mouse.x, mouse.y)
                            root.updateBarModDrag(mapped.x, mapped.y)
                        }
                    }
                }

                onReleased: {
                    if (draggingStarted) {
                        root.finishBarModDrag()
                        draggingStarted = false
                    }
                }
            }
        }

        // Верхний поясняющий баннер
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: root.cfg.barPosition === "top" ? 78 : 24
            anchors.horizontalCenter: parent.horizontalCenter
            height: 34
            implicitWidth: barHintTxt.implicitWidth + 36
            radius: 17
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.accent
            border.width: 1.5
            z: 50

            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Text { text: "󰕮"; color: root.cfg.accent; font.pixelSize: 14 }
                Text {
                    id: barHintTxt
                    text: "Редактор бара • Перетаскивайте модули курсором в любое место бара или сбросьте вниз"
                    color: root.cfg.textPrimary
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // Интерактивная панель бара на экране (точно на месте панели задач)
        Rectangle {
            id: onScreenBarCapsule
            anchors.top: root.cfg.barPosition === "top" ? parent.top : undefined
            anchors.bottom: root.cfg.barPosition === "bottom" ? parent.bottom : undefined
            anchors.topMargin: root.cfg.barPosition === "top" ? 14 : undefined
            anchors.bottomMargin: root.cfg.barPosition === "bottom" ? 14 : undefined
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 24, Math.max(1820, root.cfg.barWidth || 1400))
            height: Math.max(38, Math.min(60, root.cfg.barHeight || 42))
            radius: root.cfg.barRadius > 0 ? Math.min(height / 2, root.cfg.barRadius) : height / 2
            color: root.cfg.barStyle === "bubbles" ? "transparent" : root.cfg.bgSurface
            border.color: root.cfg.barStyle === "bubbles" ? "transparent" : root.cfg.accent
            border.width: root.cfg.barStyle === "bubbles" ? 0 : 2
            clip: false

            // Плавающий светящийся маркер точного слота вставки модуля
            Rectangle {
                id: dropMarkerLine
                visible: root.draggingBarModId !== "" &&
                         (root.barHoverZone === "left" || root.barHoverZone === "center" || root.barHoverZone === "right") &&
                         root.barMarkerX > 0
                x: Math.round(root.barMarkerX - width / 2)
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: Math.max(26, onScreenBarCapsule.height - 10)
                radius: 2
                color: root.cfg.accent
                z: 200

                // Верхняя и нижняя точки маркера Material You
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: -3
                    width: 8; height: 8; radius: 4
                    color: root.cfg.accent
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -3
                    width: 8; height: 8; radius: 4
                    color: root.cfg.accent
                }

                Behavior on x { NumberAnimation { duration: 75; easing.type: Easing.OutQuad } }
            }

            // --- 1. Левая секция (Left Zone) ---
            Item {
                id: leftZoneBox
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: leftZoneRow.implicitWidth

                RowLayout {
                    id: leftZoneRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    spacing: 8

                    Repeater {
                        id: leftModRepeater
                        model: root.cfg.barModulesLeft || []
                        delegate: BarModuleChip {
                            zone: "left"
                        }
                    }

                    Rectangle {
                        visible: (root.cfg.barModulesLeft || []).length === 0
                        height: 32
                        implicitWidth: emptyLTxt.implicitWidth + 24
                        radius: 16
                        color: (root.barHoverZone === "left" && root.draggingBarModId !== "") ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22) : "transparent"
                        border.color: (root.barHoverZone === "left" && root.draggingBarModId !== "") ? root.cfg.accent : root.cfg.borderCol
                        border.width: 1.5
                        Text {
                            id: emptyLTxt
                            anchors.centerIn: parent
                            text: (root.barHoverZone === "left" && root.draggingBarModId !== "") ? "󰆏 Поместить сюда" : "Левая зона"
                            color: (root.barHoverZone === "left" && root.draggingBarModId !== "") ? root.cfg.accent : root.cfg.textMuted
                            font.pixelSize: 11
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }

            // --- 2. Центральная секция (Center Zone) ---
            Item {
                id: centerZoneBox
                anchors.centerIn: parent
                height: parent.height
                width: centerZoneRow.implicitWidth

                RowLayout {
                    id: centerZoneRow
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        id: centerModRepeater
                        model: root.cfg.barModulesCenter || []
                        delegate: BarModuleChip {
                            zone: "center"
                        }
                    }

                    Rectangle {
                        visible: (root.cfg.barModulesCenter || []).length === 0
                        height: 32
                        implicitWidth: emptyCTxt.implicitWidth + 24
                        radius: 16
                        color: (root.barHoverZone === "center" && root.draggingBarModId !== "") ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22) : "transparent"
                        border.color: (root.barHoverZone === "center" && root.draggingBarModId !== "") ? root.cfg.accent : root.cfg.borderCol
                        border.width: 1.5
                        Text {
                            id: emptyCTxt
                            anchors.centerIn: parent
                            text: (root.barHoverZone === "center" && root.draggingBarModId !== "") ? "󰆏 Поместить сюда" : "Центр"
                            color: (root.barHoverZone === "center" && root.draggingBarModId !== "") ? root.cfg.accent : root.cfg.textMuted
                            font.pixelSize: 11
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }

            // --- 3. Правая секция (Right Zone) ---
            Item {
                id: rightZoneBox
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: rightZoneRow.implicitWidth

                RowLayout {
                    id: rightZoneRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    spacing: 8

                    Repeater {
                        id: rightModRepeater
                        model: root.cfg.barModulesRight || []
                        delegate: BarModuleChip {
                            zone: "right"
                        }
                    }

                    Rectangle {
                        visible: (root.cfg.barModulesRight || []).length === 0
                        height: 32
                        implicitWidth: emptyRTxt.implicitWidth + 24
                        radius: 16
                        color: (root.barHoverZone === "right" && root.draggingBarModId !== "") ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22) : "transparent"
                        border.color: (root.barHoverZone === "right" && root.draggingBarModId !== "") ? root.cfg.accent : root.cfg.borderCol
                        border.width: 1.5
                        Text {
                            id: emptyRTxt
                            anchors.centerIn: parent
                            text: (root.barHoverZone === "right" && root.draggingBarModId !== "") ? "󰆏 Поместить сюда" : "Правая зона"
                            color: (root.barHoverZone === "right" && root.draggingBarModId !== "") ? root.cfg.accent : root.cfg.textMuted
                            font.pixelSize: 11
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }
        }

        // Индикатор сброса модуля вниз (Зона удаления / возврата в склад)
        Rectangle {
            anchors.centerIn: parent
            visible: root.draggingBarModId !== ""
            height: 52
            implicitWidth: trashGuideRow.implicitWidth + 36
            radius: 26
            color: root.barHoverZone === "trash" ? Qt.rgba(root.cfg.danger.r, root.cfg.danger.g, root.cfg.danger.b, 0.28) : Qt.rgba(0,0,0,0.5)
            border.color: root.barHoverZone === "trash" ? root.cfg.danger : Qt.rgba(root.cfg.borderCol.r, root.cfg.borderCol.g, root.cfg.borderCol.b, 0.6)
            border.width: root.barHoverZone === "trash" ? 2.5 : 1
            z: 9990

            RowLayout {
                id: trashGuideRow
                anchors.centerIn: parent
                spacing: 10
                Text { text: "󰆴"; color: root.barHoverZone === "trash" ? root.cfg.danger : root.cfg.textMuted; font.pixelSize: 18 }
                Text {
                    text: root.barHoverZone === "trash" ? "Отпустите, чтобы убрать в склад" : "Перетащите сюда, чтобы убрать модуль с бара"
                    color: root.barHoverZone === "trash" ? root.cfg.danger : root.cfg.textPrimary
                    font.pixelSize: 12
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // Плавающий фантомный чип под курсором при перетаскивании модуля
        Rectangle {
            id: floatingGhostChip
            visible: root.draggingBarModId !== ""
            x: Math.round(root.barDragX - width / 2)
            y: Math.round(root.barDragY - height / 2)
            z: 99999
            height: 40
            implicitWidth: fGhostRow.implicitWidth + 24
            radius: 20
            color: root.barHoverZone === "trash" ? root.cfg.danger : root.cfg.surfaceContainerHigh
            border.color: root.barHoverZone === "trash" ? "#ffffff" : root.cfg.accent
            border.width: 2
            scale: 1.08
            opacity: 0.95

            RowLayout {
                id: fGhostRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: root.barHoverZone === "trash" ? "󰆴" : root.getBarModInfo(root.draggingBarModId).icon
                    color: root.barHoverZone === "trash" ? "#ffffff" : root.cfg.accent
                    font.pixelSize: 14
                }
                Text {
                    text: root.barHoverZone === "trash" ? "Убрать в склад" : root.getBarModInfo(root.draggingBarModId).name
                    color: root.barHoverZone === "trash" ? "#ffffff" : root.cfg.textPrimary
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }
    }
    // =========================================================
    // ПЛАВАЮЩИЙ MATERIAL YOU DOCK УПРАВЛЕНИЯ (BOTTOM BAR)
    // =========================================================
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        height: 64
        implicitWidth: dockContent.implicitWidth + 32
        radius: 32
        color: root.cfg.bgSurface
        border.color: root.cfg.borderCol
        border.width: 1
        z: 95

        RowLayout {
            id: dockContent
            anchors.centerIn: parent
            spacing: 8

            // Режим Виджетов: кнопки добавления
            RowLayout {
                visible: root.mode === "widgets"
                spacing: 8

                Text {
                    text: "Добавить:"
                    color: root.cfg.textMuted
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }

                Rectangle {
                    height: 36; implicitWidth: cBtnTxt.implicitWidth + 20; radius: 18; color: cBtnM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: cBtnTxt; anchors.centerIn: parent; text: "󰥔 Часы"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: cBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cfg.addWidget("clock", root.monX + 100, root.monY + 100) }
                }

                Rectangle {
                    height: 36; implicitWidth: wBtnTxt.implicitWidth + 20; radius: 18; color: wBtnM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: wBtnTxt; anchors.centerIn: parent; text: "󰖐 Погода"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: wBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cfg.addWidget("weather", root.monX + 380, root.monY + 100) }
                }

                Rectangle {
                    height: 36; implicitWidth: vBtnTxt.implicitWidth + 20; radius: 18; color: vBtnM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: vBtnTxt; anchors.centerIn: parent; text: "󰍛 Ресурсы"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: vBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cfg.addWidget("vitals", root.monX + 100, root.monY + 260) }
                }

                Rectangle {
                    height: 36; implicitWidth: mBtnTxt.implicitWidth + 20; radius: 18; color: mBtnM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: mBtnTxt; anchors.centerIn: parent; text: "󰎆 Плеер"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: mBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cfg.addWidget("player", root.monX + 440, root.monY + 260) }
                }

                Rectangle {
                    height: 36; implicitWidth: calBtnTxt.implicitWidth + 20; radius: 18; color: calBtnM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: calBtnTxt; anchors.centerIn: parent; text: "󰸗 Календарь"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: calBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cfg.addWidget("calendar", root.monX + 200, root.monY + 150) }
                }

                Rectangle {
                    height: 36; implicitWidth: nBtnTxt.implicitWidth + 20; radius: 18; color: nBtnM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: nBtnTxt; anchors.centerIn: parent; text: "󰏫 Заметки"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: nBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cfg.addWidget("notes", root.monX + 300, root.monY + 200) }
                }

                Rectangle {
                    height: 36; implicitWidth: stBtnTxt.implicitWidth + 20; radius: 18; color: stBtnM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: stBtnTxt; anchors.centerIn: parent; text: "󰋊 Диск"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: stBtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cfg.addWidget("storage", root.monX + 200, root.monY + 300) }
                }

                Rectangle { width: 1; height: 24; color: root.cfg.borderCol }

                // Общее скругление всех виджетов (Слайдер + степперы)
                RowLayout {
                    spacing: 8

                    Text {
                        text: "󰚌 Общее скругление:"
                        color: root.cfg.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        font.family: root.cfg.fontFamily
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: gMinusM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                        border.color: root.cfg.borderCol; border.width: 1
                        Text { anchors.centerIn: parent; text: "−"; color: root.cfg.textPrimary; font.pixelSize: 13; font.bold: true }
                        MouseArea {
                            id: gMinusM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.cfg.setAllWidgetsRadius(Math.max(0, (root.cfg.widgetRadius || 28) - 1))
                        }
                    }

                    Item {
                        id: gSliderItem
                        width: 110; height: 24

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.right: parent.right
                            height: 6; radius: 3
                            color: root.cfg.bgElevated

                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: Math.max(6, Math.min(parent.width, ((root.cfg.widgetRadius || 28) / 52) * parent.width))
                                radius: 3; color: root.cfg.accent
                            }
                        }

                        Rectangle {
                            x: Math.max(0, Math.min(gSliderItem.width - width, ((root.cfg.widgetRadius || 28) / 52) * (gSliderItem.width - width)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 7
                            color: gSliderMouse.containsMouse || gSliderMouse.pressed ? root.cfg.accent : "#ffffff"
                            border.color: root.cfg.accent; border.width: 2
                            scale: gSliderMouse.pressed ? 1.2 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                        }

                        MouseArea {
                            id: gSliderMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            function updateGlobal(mx) {
                                let ratio = Math.max(0, Math.min(1, mx / width))
                                root.cfg.setAllWidgetsRadius(Math.round(ratio * 52))
                            }
                            onPressed: mouse => updateGlobal(mouse.x)
                            onPositionChanged: mouse => { if (pressed) updateGlobal(mouse.x) }
                        }
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: gPlusM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                        border.color: root.cfg.borderCol; border.width: 1
                        Text { anchors.centerIn: parent; text: "+"; color: root.cfg.textPrimary; font.pixelSize: 13; font.bold: true }
                        MouseArea {
                            id: gPlusM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.cfg.setAllWidgetsRadius(Math.min(56, (root.cfg.widgetRadius || 28) + 1))
                        }
                    }

                    Rectangle {
                        height: 24; implicitWidth: gValTxt.implicitWidth + 12; radius: 12
                        color: root.cfg.accentContainer
                        Text {
                            id: gValTxt; anchors.centerIn: parent
                            text: (root.cfg.widgetRadius || 28) + " px"
                            color: root.cfg.accent; font.pixelSize: 11; font.bold: true
                        }
                    }
                }
            }

            // Режим OSD: пресеты расположения с точнейшей центровкой
            RowLayout {
                visible: root.mode === "osd"
                spacing: 8

                Text { text: "Пресеты OSD:"; color: root.cfg.textMuted; font.pixelSize: 11; font.bold: true }

                Rectangle {
                    height: 36; implicitWidth: p1Txt.implicitWidth + 18; radius: 18; color: p1M.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: p1Txt; anchors.centerIn: parent; text: "󰆤 Снизу строго по центру"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        id: p1M; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ghostOsd.x = Math.round((root.width - 240) / 2) // 840px на 1920 экране
                            ghostOsd.y = root.height - 44 - 120
                            root.cfg.osdLeftMargin = Math.round(ghostOsd.x)
                            root.cfg.osdBottomMargin = 120
                            root.cfg.save()
                        }
                    }
                }

                Rectangle {
                    height: 36; implicitWidth: p2Txt.implicitWidth + 18; radius: 18; color: p2M.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    Text { id: p2Txt; anchors.centerIn: parent; text: "Вверху справа"; color: root.cfg.textPrimary; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        id: p2M; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ghostOsd.x = root.width - 240 - 40
                            ghostOsd.y = 60
                            root.cfg.osdLeftMargin = Math.round(ghostOsd.x)
                            root.cfg.osdBottomMargin = Math.round(root.height - ghostOsd.y - 44)
                            root.cfg.save()
                        }
                    }
                }
            }

            // Режим Бара: склад неиспользуемых модулей + сброс по умолчанию
            RowLayout {
                visible: root.mode === "bar"
                spacing: 8

                Text { text: "Склад модулей:"; color: root.cfg.textMuted; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }

                Text {
                    visible: root.getUnusedBarMods().length === 0
                    text: "(Все модули добавлены на панель)"
                    color: root.cfg.textMuted
                    font.pixelSize: 11
                    font.italic: true
                }

                Repeater {
                    model: root.getUnusedBarMods()

                    Rectangle {
                        id: whChip
                        required property var modelData
                        height: 36
                        implicitWidth: whRow.implicitWidth + 24
                        radius: 18
                        color: whM.containsMouse ? root.cfg.surfaceContainerHigh : root.cfg.bgElevated
                        border.color: whM.containsMouse ? root.cfg.accent : root.cfg.borderCol
                        border.width: 1
                        scale: whM.pressed ? 0.95 : (whM.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        RowLayout {
                            id: whRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "󰐕 " + whChip.modelData.icon
                                color: root.cfg.accent
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                text: whChip.modelData.name
                                color: root.cfg.textPrimary
                                font.pixelSize: 11
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }
                        }

                        MouseArea {
                            id: whM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property real pressX: 0
                            property real pressY: 0
                            property bool draggingStarted: false

                            onPressed: mouse => {
                                pressX = mouse.x
                                pressY = mouse.y
                                draggingStarted = false
                            }

                            onPositionChanged: mouse => {
                                if (pressed) {
                                    let dx = mouse.x - pressX
                                    let dy = mouse.y - pressY
                                    if (!draggingStarted && (Math.abs(dx) > 3 || Math.abs(dy) > 3)) {
                                        draggingStarted = true
                                        let mapped = mapToItem(root, mouse.x, mouse.y)
                                        root.startBarModDrag(whChip.modelData.id, "warehouse", -1, mapped.x, mapped.y)
                                    }
                                    if (draggingStarted) {
                                        let mapped = mapToItem(root, mouse.x, mouse.y)
                                        root.updateBarModDrag(mapped.x, mapped.y)
                                    }
                                }
                            }

                            onReleased: {
                                if (draggingStarted) {
                                    root.finishBarModDrag()
                                    draggingStarted = false
                                } else {
                                    let id = whChip.modelData.id
                                    if (id === "launcher" || id === "workspaces") root.cfg.insertBarModuleAt(id, "left", 999)
                                    else if (id === "clock" || id === "weather") root.cfg.insertBarModuleAt(id, "center", 999)
                                    else root.cfg.insertBarModuleAt(id, "right", 999)
                                }
                            }
                        }
                    }
                }

                // Переключатели стиля бара (Островки / Монолит)
                Rectangle {
                    height: 36
                    implicitWidth: bStyleBubbles.implicitWidth + 18
                    radius: 18
                    color: root.cfg.barStyle === "bubbles" ? root.cfg.accent : root.cfg.bgElevated
                    Text {
                        id: bStyleBubbles
                        anchors.centerIn: parent
                        text: "󰘖 Островки"
                        color: root.cfg.barStyle === "bubbles" ? root.cfg.accentText : root.cfg.textPrimary
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cfg.barStyle = "bubbles"
                            root.cfg.barModuleBubbles = true
                            root.cfg.save()
                        }
                    }
                }

                Rectangle {
                    height: 36
                    implicitWidth: bStyleMono.implicitWidth + 18
                    radius: 18
                    color: root.cfg.barStyle === "monolith" ? root.cfg.accent : root.cfg.bgElevated
                    Text {
                        id: bStyleMono
                        anchors.centerIn: parent
                        text: "󰛲 Монолит"
                        color: root.cfg.barStyle === "monolith" ? root.cfg.accentText : root.cfg.textPrimary
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cfg.barStyle = "monolith"
                            root.cfg.barModuleBubbles = false
                            root.cfg.save()
                        }
                    }
                }

                Rectangle {
                    height: 36
                    implicitWidth: rstTxt.implicitWidth + 20
                    radius: 18
                    color: rstM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    border.color: root.cfg.borderCol
                    border.width: 1
                    Text { id: rstTxt; anchors.centerIn: parent; text: "󰁯 По умолчанию"; color: root.cfg.textMuted; font.pixelSize: 11; font.bold: true }
                    MouseArea {
                        id: rstM
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cfg.resetBarModules()
                    }
                }

                Rectangle { width: 1; height: 24; color: root.cfg.borderCol }

                // Скругление капсул модулей прямо в редакторе бара
                RowLayout {
                    spacing: 6
                    Text { text: "󰚌 Скругление:"; color: root.cfg.textMuted; font.pixelSize: 11; font.bold: true; font.family: root.cfg.fontFamily }

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: bModRMinus.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                        border.color: root.cfg.borderCol; border.width: 1
                        Text { anchors.centerIn: parent; text: "−"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true }
                        MouseArea {
                            id: bModRMinus; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let cur = root.cfg.barModuleRadius !== undefined ? root.cfg.barModuleRadius : 16
                                root.cfg.barModuleRadius = Math.max(0, cur - 1)
                                root.cfg.save()
                            }
                        }
                    }

                    Item {
                        id: bModRSlider
                        width: 90; height: 20
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.right: parent.right
                            height: 6; radius: 3; color: root.cfg.bgElevated
                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: Math.max(6, ((root.cfg.barModuleRadius !== undefined ? root.cfg.barModuleRadius : 16) / 20) * parent.width)
                                radius: 3; color: root.cfg.accent
                            }
                        }
                        Rectangle {
                            x: Math.max(0, Math.min(bModRSlider.width - width, ((root.cfg.barModuleRadius !== undefined ? root.cfg.barModuleRadius : 16) / 20) * (bModRSlider.width - width)))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 7
                            color: bModRMouse.containsMouse || bModRMouse.pressed ? root.cfg.accent : "#ffffff"
                            border.color: root.cfg.accent; border.width: 2
                            scale: bModRMouse.pressed ? 1.2 : 1.0
                            Behavior on scale { NumberAnimation { duration: 80 } }
                        }
                        MouseArea {
                            id: bModRMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            function update(mx) {
                                let ratio = Math.max(0, Math.min(1, mx / width))
                                root.cfg.barModuleRadius = Math.round(ratio * 20)
                                root.cfg.save()
                            }
                            onPressed: mouse => update(mouse.x)
                            onPositionChanged: mouse => { if (pressed) update(mouse.x) }
                        }
                    }

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: bModRPlus.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                        border.color: root.cfg.borderCol; border.width: 1
                        Text { anchors.centerIn: parent; text: "+"; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true }
                        MouseArea {
                            id: bModRPlus; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let cur = root.cfg.barModuleRadius !== undefined ? root.cfg.barModuleRadius : 16
                                root.cfg.barModuleRadius = Math.min(20, cur + 1)
                                root.cfg.save()
                            }
                        }
                    }

                    Rectangle {
                        height: 22; implicitWidth: bModRTxt.implicitWidth + 10; radius: 11
                        color: root.cfg.accentContainer
                        Text {
                            id: bModRTxt; anchors.centerIn: parent
                            text: {
                                let r = root.cfg.barModuleRadius !== undefined ? root.cfg.barModuleRadius : 16
                                if (r >= 20 || r < 0) return "Капсула"
                                return r + " px"
                            }
                            color: root.cfg.accent; font.pixelSize: 10; font.bold: true
                        }
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: root.cfg.borderCol }

            // Кнопка сохранения и выхода
            Rectangle {
                height: 40
                implicitWidth: saveBtnTxt.implicitWidth + 24
                radius: 20
                color: root.cfg.accent

                Text {
                    id: saveBtnTxt
                    anchors.centerIn: parent
                    text: "✓  Готово"
                    color: root.cfg.accentText
                    font.pixelSize: 12
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeEditor()
                }
            }
        }
    }

    Component { id: clockComp; ClockWidget { cfg: root.cfg; widgetData: parent.itemData || ({}) } }
    Component { id: weatherComp; WeatherWidget { cfg: root.cfg; widgetData: parent.itemData || ({}) } }
    Component { id: vitalsComp; VitalsWidget { cfg: root.cfg; widgetData: parent.itemData || ({}) } }
    Component { id: playerComp; MediaWidget { cfg: root.cfg; widgetData: parent.itemData || ({}) } }
    Component { id: calendarComp; CalendarWidget { cfg: root.cfg; widgetData: parent.itemData || ({}) } }
    Component { id: notesComp; NotesWidget { cfg: root.cfg; widgetData: parent.itemData || ({}) } }
    Component { id: storageComp; StorageWidget { cfg: root.cfg; widgetData: parent.itemData || ({}) } }
}
