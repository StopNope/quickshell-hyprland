import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ================= ПУТИ СИСТЕМЫ И ПОЛЬЗОВАТЕЛЯ =================
    readonly property string homeDir: Quickshell.env("HOME") || ("/home/" + (Quickshell.env("USER") || "user"))
    readonly property string qsDir: homeDir + "/.config/quickshell"

    // ================= 1. ГЕОМЕТРИЯ И ПОЛОЖЕНИЕ БАРА =================
    property string barPosition: "top"       // "top", "bottom", "left", "right"
    property bool swapBarSides: false
    property int barWidth: 1900
    property int barHeight: 34
    property real barRadius: 17
    property int barVerticalHeight: 680
    property string barStyle: "bubbles"      // "bubbles" (парящие островки), "classic" (сплошная плашка)
    property real barOpacity: 1.0            // 0.0 to 1.0 (прозрачность общей плашки бара)
    property bool barModuleBubbles: true     // каждый модуль обернут в свою собственную капсулу
    property real barBubbleOpacity: 0.90     // прозрачность самих капсул-пузырьков
    property int barBubbleSpacing: 8         // расстояние между пузырьками
    property int barModuleRadius: 16         // скругление подложки/капсул модулей (0-20, где 20=полная капсула pill)
    property bool barDragReorder: false      // перетаскивание модулей делается через интерактивный конструктор в настройках

    // ================= 2. МОДУЛИ И МОДУЛЬНЫЙ КОНСТРУКТОР БАРА =================
    property bool showWorkspaces: true
    property bool showCpu: true
    property bool showRam: true
    property bool showGpu: true
    property bool showWeatherBar: true
    property bool showClockSeconds: true
    property bool showNetwork: true
    property bool showBluetooth: true
    property bool showLang: true
    property bool showVolume: true
    property bool showTray: true

    property var barModulesLeft: ["workspaces"]
    property var barModulesCenter: ["clock", "weather"]
    property var barModulesRight: ["cpu", "ram", "gpu", "net", "bt", "lang", "vol", "tray"]

    readonly property var allBarModules: [
        { id: "launcher", name: "Меню приложений", icon: "󰀻" },
        { id: "workspaces", name: "Воркспейсы", icon: "󰄯" },
        { id: "clock", name: "Часы", icon: "󰥔" },
        { id: "weather", name: "Погода", icon: "󰖐" },
        { id: "cpu", name: "Процессор (CPU)", icon: "󰍛" },
        { id: "ram", name: "Память (RAM)", icon: "󰘚" },
        { id: "gpu", name: "Видеокарта (GPU)", icon: "󰢮" },
        { id: "net", name: "Сеть (Wi-Fi/LAN)", icon: "󰈀" },
        { id: "bt", name: "Bluetooth", icon: "󰂯" },
        { id: "lang", name: "Раскладка", icon: "󰌌" },
        { id: "vol", name: "Звук", icon: "󰕾" },
        { id: "tray", name: "Системный трей", icon: "󰍜" }
    ]

    function moveBarModule(modId, targetZone) {
        let left = barModulesLeft.filter(m => m !== modId)
        let center = barModulesCenter.filter(m => m !== modId)
        let right = barModulesRight.filter(m => m !== modId)
        if (targetZone === "left") left.push(modId)
        else if (targetZone === "center") center.push(modId)
        else if (targetZone === "right") right.push(modId)
        barModulesLeft = left
        barModulesCenter = center
        barModulesRight = right
        save()
    }

    function removeBarModule(modId) {
        function clean(list) {
            let res = []
            for (let i = 0; i < list.length; i++) {
                let item = list[i]
                if (item === modId) continue
                if (typeof item === "string" && item.indexOf("+") !== -1) {
                    let parts = item.split("+").filter(p => p !== modId)
                    if (parts.length === 1) res.push(parts[0])
                    else if (parts.length > 1) res.push(parts.join("+"))
                } else {
                    res.push(item)
                }
            }
            return res
        }
        barModulesLeft = clean(barModulesLeft)
        barModulesCenter = clean(barModulesCenter)
        barModulesRight = clean(barModulesRight)
        save()
    }

    function combineBarModules(zone, idx) {
        let list = (zone === "left" ? barModulesLeft : (zone === "center" ? barModulesCenter : barModulesRight)).slice()
        if (idx >= 0 && idx < list.length - 1) {
            let combined = list[idx] + "+" + list[idx + 1]
            list.splice(idx, 2, combined)
            if (zone === "left") barModulesLeft = list
            else if (zone === "center") barModulesCenter = list
            else barModulesRight = list
            save()
        }
    }

    function splitBarModule(zone, idx) {
        let list = (zone === "left" ? barModulesLeft : (zone === "center" ? barModulesCenter : barModulesRight)).slice()
        if (idx >= 0 && idx < list.length) {
            let item = list[idx]
            if (typeof item === "string" && item.indexOf("+") !== -1) {
                let parts = item.split("+")
                list.splice(idx, 1, ...parts)
                if (zone === "left") barModulesLeft = list
                else if (zone === "center") barModulesCenter = list
                else barModulesRight = list
                save()
            }
        }
    }

    function reorderBarModule(zone, idx, delta) {
        let list = (zone === "left" ? barModulesLeft : (zone === "center" ? barModulesCenter : barModulesRight)).slice()
        let newIdx = idx + delta
        if (newIdx >= 0 && newIdx < list.length) {
            let tmp = list[idx]
            list[idx] = list[newIdx]
            list[newIdx] = tmp
            if (zone === "left") barModulesLeft = list
            else if (zone === "center") barModulesCenter = list
            else barModulesRight = list
            save()
        }
    }

    function resetBarModules() {
        barModulesLeft = ["launcher", "workspaces"]
        barModulesCenter = ["clock", "weather"]
        barModulesRight = ["cpu", "ram", "gpu", "net", "bt", "lang", "vol", "tray"]
        save()
    }

    // Перемещение или вставка модуля в любую зону бара по точному индексу
    function insertBarModuleAt(modId, targetZone, targetIdx) {
        if (!modId) return
        let left = barModulesLeft.filter(m => m !== modId)
        let center = barModulesCenter.filter(m => m !== modId)
        let right = barModulesRight.filter(m => m !== modId)

        let targetList = (targetZone === "left" ? left : (targetZone === "center" ? center : right))
        let idx = (typeof targetIdx === "number") ? targetIdx : targetList.length
        if (idx < 0) idx = 0
        if (idx > targetList.length) idx = targetList.length
        targetList.splice(idx, 0, modId)

        barModulesLeft = left
        barModulesCenter = center
        barModulesRight = right
        save()
    }

    // Перемещение модуля из одной зоны в другую с указанием точного индекса
    function moveBarModuleToIndex(sourceZone, sourceIdx, targetZone, targetIdx) {
        let left = barModulesLeft.slice()
        let center = barModulesCenter.slice()
        let right = barModulesRight.slice()

        let sourceList = (sourceZone === "left" ? left : (sourceZone === "center" ? center : right))
        if (sourceIdx < 0 || sourceIdx >= sourceList.length) return
        let item = sourceList.splice(sourceIdx, 1)[0]

        let targetList = (targetZone === "left" ? left : (targetZone === "center" ? center : right))
        if (targetIdx < 0) targetIdx = 0
        if (targetIdx > targetList.length) targetIdx = targetList.length
        targetList.splice(targetIdx, 0, item)

        barModulesLeft = left
        barModulesCenter = center
        barModulesRight = right
        save()
    }

    // Поменять местами два модуля внутри одной зоны (интерактивный swap)
    function swapBarModulesInZone(zone, idxA, idxB) {
        let list = (zone === "left" ? barModulesLeft : (zone === "center" ? barModulesCenter : barModulesRight)).slice()
        if (idxA >= 0 && idxA < list.length && idxB >= 0 && idxB < list.length && idxA !== idxB) {
            let tmp = list[idxA]
            list[idxA] = list[idxB]
            list[idxB] = tmp
            if (zone === "left") barModulesLeft = list
            else if (zone === "center") barModulesCenter = list
            else barModulesRight = list
            save()
        }
    }

    // ================= 3. БОКОВАЯ ПАНЕЛЬ (SIDEPANEL) =================
    property int sidePanelWidth: 380
    property bool sideShowHero: true
    property bool sideShowTiles: true
    property bool sideShowSliders: true
    property bool sideShowMedia: true
    property bool sideShowGauges: true
    property bool sideShowNotifications: true
    property bool sideShowPower: true
    property string sideSliderStyle: "pill"         // "pill" (Material Inset Pill), "classic"
    property string playerProgressStyle: "wavy"     // "wavy" (Material You Squiggly Wave), "flat"
    property string activeShapeStyle: "blossom"     // "blossom" (скругленные шипы), "circle"

    property var sidePanelOrder: ["tiles", "sliders", "gauges", "media", "notifications", "power"]

    readonly property var allSideSections: [
        { id: "tiles", name: "Быстрые плитки (Wi-Fi, BT, Свет, DND)", icon: "󰤨" },
        { id: "sliders", name: "Регуляторы звука и яркости", icon: "󰕾" },
        { id: "gauges", name: "Круговые датчики CPU / RAM / GPU", icon: "󰍛" },
        { id: "media", name: "Медиаплеер с управлением", icon: "󰎆" },
        { id: "notifications", name: "Центр уведомлений", icon: "󰂚" },
        { id: "power", name: "Док-панель питания", icon: "󰐥" }
    ]

    function reorderSideSection(idx, delta) {
        let list = sidePanelOrder.slice()
        let newIdx = idx + delta
        if (newIdx >= 0 && newIdx < list.length) {
            let tmp = list[idx]
            list[idx] = list[newIdx]
            list[newIdx] = tmp
            sidePanelOrder = list
            save()
        }
    }

    function toggleSideSection(secId) {
        let list = sidePanelOrder.slice()
        let idx = list.indexOf(secId)
        if (idx !== -1) {
            list.splice(idx, 1)
        } else {
            list.push(secId)
        }
        sidePanelOrder = list
        save()
    }

    // ================= 3.1 ВИДЖЕТЫ РАБОЧЕГО СТОЛА (DESKTOP WIDGETS) =================
    property bool showDesktopWidgets: true
    property int widgetRadius: 28
    property string userNotes: "• Добро пожаловать в Material You!\n• Виджеты можно перетаскивать на рабочий стол\n• Нажмите карандаш в шторке для кастомизации"
    property var desktopWidgets: [
        { id: "clock-1", type: "clock", x: 60, y: 70, w: 260, h: 140, visible: true },
        { id: "weather-1", type: "weather", x: 340, y: 70, w: 220, h: 140, visible: true },
        { id: "vitals-1", type: "vitals", x: 60, y: 230, w: 320, h: 120, visible: true },
        { id: "player-1", type: "player", x: 400, y: 230, w: 360, h: 140, visible: true }
    ]

    // ================= 3.2 ДОК-БАР ПРИЛОЖЕНИЙ (APPLICATION DOCK) =================
    property bool dockEnabled: true
    property bool dockAutohide: true
    property int dockIconSize: 42
    property var dockPinnedApps: ["firefox", "kitty", "thunar", "vesktop", "telegram"]

    function pinAppToDock(appId) {
        if (!appId) return
        let list = (dockPinnedApps || []).slice()
        if (!list.includes(appId)) {
            list.push(appId)
            dockPinnedApps = list
            save()
        }
    }

    function unpinAppFromDock(appId) {
        if (!appId) return
        let list = (dockPinnedApps || []).filter(id => id !== appId)
        dockPinnedApps = list
        save()
    }

    function isAppPinned(appId) {
        if (!dockPinnedApps || !appId) return false
        return dockPinnedApps.includes(appId)
    }

    // ================= 3.3 ЕДИНОЕ ПРОСТРАНСТВО МОНИТОРОВ ДЛЯ ВИДЖЕТОВ =================
    property var monitorGeometries: ({
        "DP-2": { x: 0, y: 0, w: 1920, h: 1080 },
        "HDMI-A-1": { x: -1920, y: 0, w: 1920, h: 1080 }
    })

    function getScreenOffset(screenName) {
        if (root.monitorGeometries && screenName && root.monitorGeometries[screenName]) {
            return root.monitorGeometries[screenName]
        }
        if (screenName === "HDMI-A-1") return { x: -1920, y: 0, w: 1920, h: 1080 }
        return { x: 0, y: 0, w: 1920, h: 1080 }
    }

    property Process monitorProc: Process {
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let mons = JSON.parse(text.trim())
                    let map = {}
                    for (let i = 0; i < mons.length; i++) {
                        let m = mons[i]
                        map[m.name] = { x: m.x, y: m.y, w: m.width, h: m.height }
                    }
                    root.monitorGeometries = map
                } catch(e) {}
            }
        }
    }

    function addWidget(type, px, py) {
        let list = desktopWidgets.slice()
        let newId = type + "-" + Date.now()
        let w = 260, h = 130
        let variant = "bento"
        if (type === "clock") { w = 260; h = 130; variant = "bento" }
        else if (type === "weather") { w = 220; h = 140; variant = "forecast" }
        else if (type === "vitals") { w = 320; h = 120; variant = "bars" }
        else if (type === "player") { w = 360; h = 140; variant = "wavy" }
        else if (type === "calendar") { w = 280; h = 260; variant = "month" }
        else if (type === "notes") { w = 280; h = 200; variant = "classic" }
        else if (type === "storage") { w = 260; h = 120; variant = "bars" }
        list.push({ id: newId, type: type, x: px || 120, y: py || 120, w: w, h: h, size: "M", variant: variant, visible: true })
        desktopWidgets = list
        save()
    }

    property bool isConfigLoaded: false

    function setWidgetSize(id, size) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                let type = item.type
                item.size = size
                if (size === "S") {
                    if (type === "clock") { item.w = 200; item.h = 95 }
                    else if (type === "weather") { item.w = 180; item.h = 105 }
                    else if (type === "vitals") { item.w = 240; item.h = 95 }
                    else if (type === "player") { item.w = 280; item.h = 105 }
                    else if (type === "calendar") { item.w = 240; item.h = 210 }
                    else if (type === "notes") { item.w = 220; item.h = 150 }
                    else if (type === "storage") { item.w = 200; item.h = 95 }
                } else if (size === "L") {
                    if (type === "clock") { item.w = 360; item.h = 165 }
                    else if (type === "weather") { item.w = 300; item.h = 175 }
                    else if (type === "vitals") { item.w = 400; item.h = 150 }
                    else if (type === "player") { item.w = 440; item.h = 170 }
                    else if (type === "calendar") { item.w = 340; item.h = 320 }
                    else if (type === "notes") { item.w = 340; item.h = 260 }
                    else if (type === "storage") { item.w = 320; item.h = 150 }
                } else { // "M"
                    if (type === "clock") { item.w = 260; item.h = 130 }
                    else if (type === "weather") { item.w = 220; item.h = 140 }
                    else if (type === "vitals") { item.w = 320; item.h = 120 }
                    else if (type === "player") { item.w = 360; item.h = 140 }
                    else if (type === "calendar") { item.w = 280; item.h = 260 }
                    else if (type === "notes") { item.w = 280; item.h = 200 }
                    else if (type === "storage") { item.w = 260; item.h = 120 }
                }
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    function setWidgetVariant(id, variant) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                item.variant = variant
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    function setWidgetClockColor(id, color) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                item.clockColor = color
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    function setWidgetRadius(id, r) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                item.radius = Math.max(0, Math.min(60, r))
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    function setAllWidgetsRadius(r) {
        widgetRadius = Math.max(0, Math.min(60, r))
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            let item = Object.assign({}, list[i])
            item.radius = widgetRadius
            list[i] = item
        }
        desktopWidgets = list
        save()
    }

    function cycleWidgetVariant(id) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                let t = item.type
                let cur = item.variant || "default"
                if (t === "clock") {
                    let variants = ["stacked_duotone", "tall_digital", "numeral", "clover", "circle", "scallop", "stacked_mono", "stacked_expressive", "bento", "pill_horizontal"]
                    let idx = variants.indexOf(cur)
                    if (idx === -1) {
                        if (cur === "minimal") idx = 0
                        else idx = 0
                    }
                    item.variant = variants[(idx + 1) % variants.length]
                } else if (t === "weather") {
                    let variants = ["forecast", "pebble", "pill", "compact", "detailed", "pill_strip"]
                    let idx = variants.indexOf(cur)
                    if (idx === -1) idx = 0
                    item.variant = variants[(idx + 1) % variants.length]
                } else if (t === "vitals") {
                    let variants = ["pills_grid", "bars", "gauges"]
                    let idx = variants.indexOf(cur)
                    if (idx === -1) idx = 0
                    item.variant = variants[(idx + 1) % variants.length]
                } else if (t === "player") {
                    let variants = ["wavy", "compact", "vinyl_disc", "sleek_capsule"]
                    let idx = variants.indexOf(cur)
                    if (idx === -1) idx = 0
                    item.variant = variants[(idx + 1) % variants.length]
                } else if (t === "calendar") {
                    let variants = ["squircle", "month", "week_strip", "minimal_pill"]
                    let idx = variants.indexOf(cur)
                    if (idx === -1) idx = 0
                    item.variant = variants[(idx + 1) % variants.length]
                } else if (t === "storage") {
                    let variants = ["bars", "circles", "compact_capsules"]
                    let idx = variants.indexOf(cur)
                    if (idx === -1) idx = 0
                    item.variant = variants[(idx + 1) % variants.length]
                } else if (t === "notes") {
                    let variants = ["checklist", "classic", "bullet_journal", "sticky_card"]
                    let idx = variants.indexOf(cur)
                    if (idx === -1) idx = 0
                    item.variant = variants[(idx + 1) % variants.length]
                }
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    function toggleWidgetTransparent(id) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                item.transparentBg = !item.transparentBg
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    function removeWidget(id) {
        let list = desktopWidgets.filter(w => w.id !== id)
        desktopWidgets = list
        save()
    }

    function updateWidgetPos(id, nx, ny) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                item.x = Math.round(nx)
                item.y = Math.round(ny)
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    function updateWidgetDimensions(id, nw, nh) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                item.w = Math.round(Math.max(140, nw))
                item.h = Math.round(Math.max(70, nh))
                item.size = "custom"
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    function updateWidgetGeometry(id, nx, ny, nw, nh) {
        let list = desktopWidgets.slice()
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                let item = Object.assign({}, list[i])
                if (nx !== undefined) item.x = Math.round(nx)
                if (ny !== undefined) item.y = Math.round(ny)
                if (nw !== undefined) item.w = Math.round(Math.max(140, nw))
                if (nh !== undefined) item.h = Math.round(Math.max(70, nh))
                item.size = "custom"
                list[i] = item
                break
            }
        }
        desktopWidgets = list
        save()
    }

    // ================= 4. MATERIAL YOU (M3) ЦВЕТОВАЯ ПАЛИТРА =================
    property string fontFamily: "Rubik, sans-serif"
    property string currentTheme: "Monet Blue"
    property color bgSurface: "#1a1c22"
    property color bgPrimary: "#131418"
    property color bgElevated: "#252730"
    property color borderCol: "#323540"
    property color accent: "#a8c7fa"
    property color accentText: "#062e6f"
    property color accentContainer: "#1e3a5f"
    property color textPrimary: "#e2e4ec"
    property color textMuted: "#9ea2b2"
    property color danger: "#f38ba8"
    property color success: "#a6e3a1"

    // ================= 4.1 MATERIAL 3 MONET СИСТЕМНЫЕ ТОКЕНЫ =================
    property color surfaceContainerLowest: Qt.darker(bgPrimary, 1.15)
    property color surfaceContainerLow: Qt.darker(bgElevated, 1.12)
    property color surfaceContainer: bgElevated
    property color surfaceContainerHigh: Qt.lighter(bgElevated, 1.15)
    property color surfaceContainerHighest: Qt.lighter(bgElevated, 1.30)
    property color primaryContainer: accentContainer
    property color onPrimaryContainer: (accent === "#ffffff") ? "#e2e4ec" : accent
    property color onSurface: textPrimary
    property color onSurfaceVariant: "#c4c7d0"
    property color outlineVariant: borderCol

    property var customThemes: []

    function applyTheme(name) {
        currentTheme = name
        if (name === "Monet Blue") {
            bgSurface = "#1a1c22"; bgPrimary = "#131418"; bgElevated = "#252730"; borderCol = "#323540"
            accent = "#a8c7fa"; accentText = "#062e6f"; accentContainer = "#1e3a5f"
        } else if (name === "Pixel Lavender") {
            bgSurface = "#1c1a22"; bgPrimary = "#141318"; bgElevated = "#272532"; borderCol = "#353244"
            accent = "#d0bcff"; accentText = "#381e72"; accentContainer = "#4a4458"
        } else if (name === "Emerald Mint") {
            bgSurface = "#191c1b"; bgPrimary = "#121514"; bgElevated = "#232927"; borderCol = "#2f3734"
            accent = "#a6e3a1"; accentText = "#0c3b1a"; accentContainer = "#1f432d"
        } else if (name === "Graphite White") {
            bgSurface = "#212328"; bgPrimary = "#18191e"; bgElevated = "#2a2d36"; borderCol = "#30333d"
            accent = "#c8ccd8"; accentText = "#18191e"; accentContainer = "#383c48"
        } else if (name === "AMOLED Peach") {
            bgSurface = "#0f0f12"; bgPrimary = "#070709"; bgElevated = "#1b1b22"; borderCol = "#262632"
            accent = "#ffb4a2"; accentText = "#5c1d0f"; accentContainer = "#3e1e19"
        } else if (name === "Nordic Slate") {
            bgSurface = "#1e222a"; bgPrimary = "#161920"; bgElevated = "#282d38"; borderCol = "#373e4d"
            accent = "#88c0d0"; accentText = "#1a2a36"; accentContainer = "#294154"
        } else if (name === "Sunset Terracotta") {
            bgSurface = "#1c1615"; bgPrimary = "#130f0e"; bgElevated = "#271f1e"; borderCol = "#3b2c2a"
            accent = "#e07a5f"; accentText = "#3d130a"; accentContainer = "#4a231b"
        } else if (name === "Cyberpunk Cyan") {
            bgSurface = "#0f141a"; bgPrimary = "#080c10"; bgElevated = "#18202a"; borderCol = "#223242"
            accent = "#00f0ff"; accentText = "#002e33"; accentContainer = "#093d47"
        } else if (name === "Tokyo Night") {
            bgSurface = "#1a1b26"; bgPrimary = "#13141c"; bgElevated = "#24283b"; borderCol = "#343b58"
            accent = "#7aa2f7"; accentText = "#152042"; accentContainer = "#283457"
        } else if (name === "Rose Gold Pine") {
            bgSurface = "#191724"; bgPrimary = "#12101b"; bgElevated = "#26233a"; borderCol = "#393552"
            accent = "#ebbcba"; accentText = "#361c27"; accentContainer = "#443c53"
        } else if (name === "Gruvbox Amber") {
            bgSurface = "#282828"; bgPrimary = "#1d2021"; bgElevated = "#3c3836"; borderCol = "#504945"
            accent = "#fabd2f"; accentText = "#2d2003"; accentContainer = "#4f3c17"
        } else if (name === "Catppuccin Mocha") {
            bgSurface = "#1e1e2e"; bgPrimary = "#11111b"; bgElevated = "#313244"; borderCol = "#45475a"
            accent = "#cba6f7"; accentText = "#2c174d"; accentContainer = "#473466"
        } else if (name === "Catppuccin Macchiato") {
            bgSurface = "#24273a"; bgPrimary = "#181926"; bgElevated = "#363a4f"; borderCol = "#494d64"
            accent = "#8aadf4"; accentText = "#181926"; accentContainer = "#363a4f"
        } else if (name === "Dracula Purple") {
            bgSurface = "#282a36"; bgPrimary = "#1e1f29"; bgElevated = "#383a59"; borderCol = "#44475a"
            accent = "#bd93f9"; accentText = "#1e1f29"; accentContainer = "#4d3d70"
        } else if (name === "Sakura Blossom") {
            bgSurface = "#201a24"; bgPrimary = "#161219"; bgElevated = "#2e2534"; borderCol = "#41354a"
            accent = "#f5bde6"; accentText = "#2e122b"; accentContainer = "#4a2d45"
        } else if (name === "Synthwave Neon") {
            bgSurface = "#181224"; bgPrimary = "#0e0a16"; bgElevated = "#271e3a"; borderCol = "#3d2b59"
            accent = "#ff2a85"; accentText = "#1a0010"; accentContainer = "#4d0e2e"
        } else if (name === "Crimson Ruby") {
            bgSurface = "#1c1414"; bgPrimary = "#130c0c"; bgElevated = "#2a1d1d"; borderCol = "#3d2626"
            accent = "#ff5555"; accentText = "#2a0505"; accentContainer = "#4d1a1a"
        } else if (name === "Electric Violet") {
            bgSurface = "#171324"; bgPrimary = "#0e0b17"; bgElevated = "#241e38"; borderCol = "#392e54"
            accent = "#a855f7"; accentText = "#18052e"; accentContainer = "#432169"
        } else if (name === "Matcha Forest") {
            bgSurface = "#191c18"; bgPrimary = "#111410"; bgElevated = "#252b23"; borderCol = "#353d32"
            accent = "#859900"; accentText = "#121a08"; accentContainer = "#2d3b20"
        } else if (name === "Sunburst Gold") {
            bgSurface = "#1c1b14"; bgPrimary = "#14130d"; bgElevated = "#2b291d"; borderCol = "#3d3a28"
            accent = "#facc15"; accentText = "#2a2202"; accentContainer = "#4a3e14"
        } else if (name === "Solarized Cyan") {
            bgSurface = "#002b36"; bgPrimary = "#001e26"; bgElevated = "#073642"; borderCol = "#0d4857"
            accent = "#2aa198"; accentText = "#002129"; accentContainer = "#0e4a4d"
        } else if (name === "One Dark Pro") {
            bgSurface = "#21252b"; bgPrimary = "#181a1f"; bgElevated = "#282c34"; borderCol = "#3b4048"
            accent = "#61afef"; accentText = "#101f33"; accentContainer = "#253b59"
        } else if (name === "Monokai Pro") {
            bgSurface = "#221f22"; bgPrimary = "#19181a"; bgElevated = "#2d2a2e"; borderCol = "#403e41"
            accent = "#ffd866"; accentText = "#261e05"; accentContainer = "#4d3e12"
        } else if (name === "Deep Abyss") {
            bgSurface = "#0b171b"; bgPrimary = "#060f12"; bgElevated = "#13252c"; borderCol = "#1d3742"
            accent = "#2dd4bf"; accentText = "#042420"; accentContainer = "#0f423d"
        } else {
            // Проверка пользовательских тем
            applyCustomTheme(name)
            return
        }
        save()
    }

    function addCustomTheme(name, acc, surf, prim, elev, cont) {
        if (!name || name.trim() === "") return
        let list = customThemes.slice().filter(t => t.name !== name.trim())
        list.push({
            name: name.trim(),
            accent: acc,
            bgSurface: surf,
            bgPrimary: prim,
            bgElevated: elev,
            borderCol: "#383d4c",
            accentContainer: cont,
            accentText: "#ffffff"
        })
        customThemes = list
        applyCustomTheme(name.trim())
        save()
    }

    function removeCustomTheme(name) {
        customThemes = customThemes.filter(t => t.name !== name)
        if (currentTheme === name) applyTheme("Monet Blue")
        save()
    }

    function applyCustomTheme(name) {
        for (let i = 0; i < customThemes.length; i++) {
            let t = customThemes[i]
            if (t.name === name) {
                currentTheme = name
                accent = t.accent
                bgSurface = t.bgSurface
                bgPrimary = t.bgPrimary
                bgElevated = t.bgElevated
                borderCol = t.borderCol || "#383d4c"
                accentContainer = t.accentContainer || t.accent
                accentText = t.accentText || "#ffffff"
                save()
                return
            }
        }
    }

    // ================= 5. ЭКРАН БЛОКИРОВКИ (LOCKSCREEN) =================
    property bool isLocked: false
    property real lockTimestamp: 0
    property string avatarPath: "/home/stopnope/.face"
    property string currentWallpaper: homeDir + "/wallpaper/default.jpg"
    property bool lockShowAvatar: true
    property bool lockShowGauges: true
    property bool lockShowWeather: true
    property bool lockShowDate: true
    property bool weatherAutoLocation: true
    property string weatherCity: "Тюмень"
    property string weatherDesc: "Ясно"
    property string weatherIcon: "󰖙"
    property string weatherFeelsLike: "+6°C"
    property string weatherHumidity: "45%"
    property string weatherWind: "9 км/ч"
    property string weatherPrecip: "0%"
    property string lockPin: "1234"

    property Process lockSnapshotProc: Process {
        id: lockSnapProc
        command: ["sh", "-c", "grim -o HDMI-A-1 -t jpeg -q 80 /tmp/lock_HDMI-A-1.jpg & grim -o DP-2 -t jpeg -q 80 /tmp/lock_DP-2.jpg & wait"]
        onExited: {
            root.lockTimestamp = Date.now()
            root.isLocked = true
        }
    }

    function lock() {
        if (!lockSnapProc.running) {
            lockSnapProc.running = true
        }
    }

    property Process wpDetector: Process {
        id: wpDetector
        running: true
        command: ["sh", "-c", "wp=$(grep -E '^wallpaper\\s*=' ~/.config/waypaper/config.ini 2>/dev/null | head -n1 | cut -d'=' -f2 | xargs); full=$(eval echo $wp); if [ -f \"$full\" ]; then echo \"$full\"; elif [ -f \"$HOME/wallpaper/default.jpg\" ]; then echo \"$HOME/wallpaper/default.jpg\"; else echo \"$HOME/.config/quickshell/wallpaper/default.jpg\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && text.trim().length > 0) {
                    root.currentWallpaper = text.trim()
                }
            }
        }
    }

    // ================= 6. OSD И РЕЖИМЫ =================
    property bool osdVolume: true
    property bool osdLang: true
    property bool osdCaps: true
    property int osdBottomMargin: 120
    property int osdLeftMargin: 840
    property bool dndMode: false
    property bool nightLight: false
    property bool powerSaveMode: false

    property Process dndProc: Process { id: dndProc }
    property Process nightLightProc: Process { id: nightLightProc }
    property Process powerSaveProc: Process { id: powerSaveProc }

    onDndModeChanged: {
        if (!root.isConfigLoaded) return
        if (root.dndMode) {
            dndProc.exec(["swaync-client", "-dn"])
            root.pushNotification("Не беспокоить", "Режим «Не беспокоить» включен.", "Уведомления", "󰂛")
        } else {
            dndProc.exec(["swaync-client", "-df"])
            root.pushNotification("Не беспокоить", "Режим «Не беспокоить» выключен.", "Уведомления", "󰂛")
        }
    }

    onNightLightChanged: {
        if (!root.isConfigLoaded) return
        if (root.nightLight) {
            nightLightProc.exec(["sh", "-c", "hyprctl repl <<< 'hl.config({ decoration = { screen_shader = \"/home/stopnope/.config/hypr/shaders/nightlight.frag\" } })'"])
            root.pushNotification("Ночной свет", "Теплый светофильтр включен.", "Экран", "󰖔")
        } else {
            nightLightProc.exec(["sh", "-c", "hyprctl repl <<< 'hl.config({ decoration = { screen_shader = \"\" } })'"])
            root.pushNotification("Ночной свет", "Светофильтр отключен.", "Экран", "󰖔")
        }
    }

    onPowerSaveModeChanged: {
        if (!root.isConfigLoaded) return
        if (root.powerSaveMode) {
            powerSaveProc.exec(["sh", "-c", "hyprctl repl <<< 'hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } }, animations = { enabled = false } })'"])
            root.pushNotification("Режим энергосбережения", "Включен: эффекты размытия и анимации Hyprland отключены.", "Питание", "󰌪")
        } else {
            powerSaveProc.exec(["sh", "-c", "hyprctl repl <<< 'hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })'"])
            root.pushNotification("Режим производительности", "Включен: визуальные эффекты и анимации Hyprland восстановлены.", "Питание", "󰌪")
        }
    }

    // ================= 7. ЖИВЫЕ ДАННЫЕ СИСТЕМЫ =================
    property int cpuVal: 5
    property int ramVal: 35
    property int gpuVal: 2
    property string weatherText: "+8°C"
    property string currentLang: "RU"
    property int currentVolume: 80
    property bool isMuted: false
    property int currentBrightness: 100

    signal refreshWeather()

    property var notifications: [
        { title: "Система", body: "Material You оформление загружено и активно.", time: "Сейчас" }
    ]

    function pushNotification(title, body, app, icon) {
        let now = Qt.formatDateTime(new Date(), "hh:mm")
        let list = notifications.slice()
        list.unshift({
            title: title || "Уведомление",
            body: body || "",
            time: now,
            app: app || "Система",
            icon: icon || ""
        })
        if (list.length > 30) list.pop()
        notifications = list
    }

    function removeNotification(index) {
        if (index >= 0 && index < notifications.length) {
            let list = notifications.slice()
            list.splice(index, 1)
            notifications = list
        }
    }

    function clearNotifications() {
        notifications = []
    }

    // ================= НАДЕЖНАЯ ЗАГРУЗКА И СОХРАНЕНИЕ КОНФИГА =================
    function toJson() {
        return {
            barPosition: root.barPosition,
            swapBarSides: root.swapBarSides,
            barWidth: root.barWidth,
            barHeight: root.barHeight,
            barRadius: root.barRadius,
            barVerticalHeight: root.barVerticalHeight,
            showWorkspaces: root.showWorkspaces,
            showCpu: root.showCpu,
            showRam: root.showRam,
            showGpu: root.showGpu,
            showWeatherBar: root.showWeatherBar,
            showClockSeconds: root.showClockSeconds,
            showNetwork: root.showNetwork,
            showBluetooth: root.showBluetooth,
            showLang: root.showLang,
            showVolume: root.showVolume,
            showTray: root.showTray,
            sidePanelWidth: root.sidePanelWidth,
            sideShowHero: root.sideShowHero,
            sideShowTiles: root.sideShowTiles,
            sideShowSliders: root.sideShowSliders,
            sideShowMedia: root.sideShowMedia,
            sideShowGauges: root.sideShowGauges,
            sideShowNotifications: root.sideShowNotifications,
            sideShowPower: root.sideShowPower,
            sideSliderStyle: root.sideSliderStyle,
            playerProgressStyle: root.playerProgressStyle,
            activeShapeStyle: root.activeShapeStyle,
            showDesktopWidgets: root.showDesktopWidgets,
            widgetRadius: root.widgetRadius,
            desktopWidgets: root.desktopWidgets,
            dockEnabled: root.dockEnabled,
            dockAutohide: root.dockAutohide,
            dockIconSize: root.dockIconSize,
            dockPinnedApps: root.dockPinnedApps,
            userNotes: root.userNotes,
            currentTheme: root.currentTheme,
            avatarPath: root.avatarPath,
            lockShowAvatar: root.lockShowAvatar,
            lockShowGauges: root.lockShowGauges,
            lockShowWeather: root.lockShowWeather,
            lockShowDate: root.lockShowDate,
            weatherAutoLocation: root.weatherAutoLocation,
            weatherCity: root.weatherCity,
            lockPin: root.lockPin,
            osdVolume: root.osdVolume,
            osdLang: root.osdLang,
            osdCaps: root.osdCaps,
            osdBottomMargin: root.osdBottomMargin,
            osdLeftMargin: root.osdLeftMargin,
            customThemes: root.customThemes,
            dndMode: root.dndMode,
            nightLight: root.nightLight,
            powerSaveMode: root.powerSaveMode,
            barModulesLeft: root.barModulesLeft,
            barModulesCenter: root.barModulesCenter,
            barModulesRight: root.barModulesRight,
            barStyle: root.barStyle,
            barOpacity: root.barOpacity,
            barModuleBubbles: root.barModuleBubbles,
            barBubbleOpacity: root.barBubbleOpacity,
            barBubbleSpacing: root.barBubbleSpacing,
            barModuleRadius: root.barModuleRadius,
            barDragReorder: root.barDragReorder,
            sidePanelOrder: root.sidePanelOrder
        }
    }

    function loadFromJson(d) {
        if (!d || typeof d !== "object") return
        if (d.barPosition !== undefined) root.barPosition = d.barPosition
        if (d.swapBarSides !== undefined) root.swapBarSides = d.swapBarSides
        if (d.barWidth !== undefined) root.barWidth = d.barWidth
        if (d.barHeight !== undefined) root.barHeight = d.barHeight
        if (d.barRadius !== undefined) root.barRadius = d.barRadius
        if (d.barVerticalHeight !== undefined) root.barVerticalHeight = d.barVerticalHeight
        if (d.barStyle !== undefined) root.barStyle = d.barStyle
        if (d.barOpacity !== undefined) root.barOpacity = d.barOpacity
        if (d.barModuleBubbles !== undefined) root.barModuleBubbles = d.barModuleBubbles
        if (d.barBubbleOpacity !== undefined) root.barBubbleOpacity = d.barBubbleOpacity
        if (d.barBubbleSpacing !== undefined) root.barBubbleSpacing = d.barBubbleSpacing
        if (d.barModuleRadius !== undefined) root.barModuleRadius = d.barModuleRadius
        if (d.barDragReorder !== undefined) root.barDragReorder = d.barDragReorder
        if (d.showWorkspaces !== undefined) root.showWorkspaces = d.showWorkspaces
        if (d.showCpu !== undefined) root.showCpu = d.showCpu
        if (d.showRam !== undefined) root.showRam = d.showRam
        if (d.showGpu !== undefined) root.showGpu = d.showGpu
        if (d.showWeatherBar !== undefined) root.showWeatherBar = d.showWeatherBar
        if (d.showClockSeconds !== undefined) root.showClockSeconds = d.showClockSeconds
        if (d.showNetwork !== undefined) root.showNetwork = d.showNetwork
        if (d.showBluetooth !== undefined) root.showBluetooth = d.showBluetooth
        if (d.showLang !== undefined) root.showLang = d.showLang
        if (d.showVolume !== undefined) root.showVolume = d.showVolume
        if (d.showTray !== undefined) root.showTray = d.showTray
        if (d.sidePanelWidth !== undefined) root.sidePanelWidth = d.sidePanelWidth
        if (d.sideShowHero !== undefined) root.sideShowHero = d.sideShowHero
        if (d.sideShowTiles !== undefined) root.sideShowTiles = d.sideShowTiles
        if (d.sideShowSliders !== undefined) root.sideShowSliders = d.sideShowSliders
        if (d.sideShowMedia !== undefined) root.sideShowMedia = d.sideShowMedia
        if (d.sideShowGauges !== undefined) root.sideShowGauges = d.sideShowGauges
        if (d.sideShowNotifications !== undefined) root.sideShowNotifications = d.sideShowNotifications
        if (d.sideShowPower !== undefined) root.sideShowPower = d.sideShowPower
        if (d.sideSliderStyle !== undefined) root.sideSliderStyle = d.sideSliderStyle
        if (d.playerProgressStyle !== undefined) root.playerProgressStyle = d.playerProgressStyle
        if (d.activeShapeStyle !== undefined) root.activeShapeStyle = d.activeShapeStyle
        if (d.showDesktopWidgets !== undefined) root.showDesktopWidgets = d.showDesktopWidgets
        if (d.widgetRadius !== undefined) root.widgetRadius = d.widgetRadius
        if (d.desktopWidgets !== undefined) root.desktopWidgets = d.desktopWidgets
        if (d.dockEnabled !== undefined) root.dockEnabled = d.dockEnabled
        if (d.dockAutohide !== undefined) root.dockAutohide = d.dockAutohide
        if (d.dockIconSize !== undefined) root.dockIconSize = d.dockIconSize
        if (d.dockPinnedApps !== undefined) root.dockPinnedApps = d.dockPinnedApps
        if (d.userNotes !== undefined) root.userNotes = d.userNotes
        if (d.currentTheme !== undefined) root.applyTheme(d.currentTheme)
        if (d.avatarPath !== undefined) root.avatarPath = d.avatarPath
        if (d.lockShowAvatar !== undefined) root.lockShowAvatar = d.lockShowAvatar
        if (d.lockShowGauges !== undefined) root.lockShowGauges = d.lockShowGauges
        if (d.lockShowWeather !== undefined) root.lockShowWeather = d.lockShowWeather
        if (d.lockShowDate !== undefined) root.lockShowDate = d.lockShowDate
        if (d.weatherAutoLocation !== undefined) root.weatherAutoLocation = d.weatherAutoLocation
        if (d.weatherCity !== undefined) root.weatherCity = d.weatherCity
        if (d.lockPin !== undefined) root.lockPin = d.lockPin
        if (d.osdVolume !== undefined) root.osdVolume = d.osdVolume
        if (d.osdLang !== undefined) root.osdLang = d.osdLang
        if (d.osdCaps !== undefined) root.osdCaps = d.osdCaps
        if (d.osdBottomMargin !== undefined) root.osdBottomMargin = d.osdBottomMargin
        if (d.osdLeftMargin !== undefined) root.osdLeftMargin = d.osdLeftMargin
        if (d.customThemes !== undefined) root.customThemes = d.customThemes
        if (d.dndMode !== undefined) root.dndMode = d.dndMode
        if (d.nightLight !== undefined) root.nightLight = d.nightLight
        if (d.powerSaveMode !== undefined) root.powerSaveMode = d.powerSaveMode
        if (d.barModulesLeft !== undefined) root.barModulesLeft = d.barModulesLeft
        if (d.barModulesCenter !== undefined) root.barModulesCenter = d.barModulesCenter
        if (d.barModulesRight !== undefined) root.barModulesRight = d.barModulesRight
        if (d.sidePanelOrder !== undefined) root.sidePanelOrder = d.sidePanelOrder
    }

    property Process loadProc: Process {
        id: loadProc
        running: true
        command: ["sh", "-c", "cat ~/.config/quickshell/config.json 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "") {
                    root.isConfigLoaded = true
                    return
                }
                try {
                    let d = JSON.parse(text.trim())
                    root.loadFromJson(d)
                } catch(e) {
                    console.warn("[Quickshell Config] Error loading config.json:", e)
                }
                root.isConfigLoaded = true
                if (root.nightLight) {
                    nightLightProc.exec(["sh", "-c", "hyprctl repl <<< 'hl.config({ decoration = { screen_shader = \"/home/stopnope/.config/hypr/shaders/nightlight.frag\" } })'"])
                }
                if (root.powerSaveMode) {
                    powerSaveProc.exec(["sh", "-c", "hyprctl repl <<< 'hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } }, animations = { enabled = false } })'"])
                }
                if (root.dndMode) {
                    dndProc.exec(["swaync-client", "-dn"])
                }
            }
        }
    }

    property Process saveProc: Process {
        id: saveProc
    }

    property Timer saveDebounce: Timer {
        id: saveDebounce
        interval: 80
        repeat: false
        onTriggered: {
            if (!root.isConfigLoaded) return
            let jsonStr = JSON.stringify(root.toJson(), null, 2)
            saveProc.exec(["sh", "-c", "cat << 'EOF' > ~/.config/quickshell/config.json\n" + jsonStr + "\nEOF"])
        }
    }

    function save() {
        if (!root.isConfigLoaded) return
        saveDebounce.restart()
    }
}
