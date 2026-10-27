import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Io

Item {
    id: root
    anchors.fill: parent

    required property var cfg
    signal toggleMenu(string tab)
    signal toggleSidePanel()
    signal triggerOsd(string type, string icon, string title, int val)
    signal openTrayMenu(var item, real globalX, real globalY)

    // ================= ДИНАМИЧЕСКИЙ СПИСОК ВОРКСПЕЙСОВ =================
    // Храним стабильный currentWorkspaceId, чтобы пилюля не исчезала при переходе на пустые столы
    property int currentWorkspaceId: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ? Hyprland.focusedWorkspace.id : 1

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) {
                root.currentWorkspaceId = Hyprland.focusedWorkspace.id
            }
        }
    }

    Process {
        id: wsSwitchProc
    }

    function switchToWorkspace(wsId) {
        root.currentWorkspaceId = wsId
        wsSwitchProc.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = " + wsId + " }))"]
        wsSwitchProc.running = true
    }

    // Хелпер безопасного разрешения иконок трея (исключает битые file://image//icon/ ссылки)
    function resolveTrayIcon(icon) {
        if (!icon) return ""
        let s = icon.toString()
        if (s.startsWith("image://") || s.startsWith("file://")) return s
        if (s.startsWith("/")) return "file://" + s
        let p = Quickshell.iconPath(s)
        if (p) return "file://" + p
        return "image://icon/" + s
    }

    // Включает базовые 1..5, все открытые столы и ГАРАНТИРОВАННО текущий активный стол
    readonly property var activeWorkspaces: {
        let set = new Set()

        // Всегда показываем базовые столы 1..5
        for (let i = 1; i <= 5; i++) {
            set.add(i)
        }

        // Все открытые столы из Hyprland
        if (Hyprland.workspaces && Hyprland.workspaces.values) {
            for (let ws of Hyprland.workspaces.values) {
                if (ws && ws.id > 0) {
                    set.add(ws.id)
                }
            }
        }

        // Текущий стол ВСЕГДА в списке (даже если он новый и на нем еще нет окон)
        set.add(root.currentWorkspaceId)

        return Array.from(set).sort((a, b) => a - b)
    }

    // ================= НАСТРОЙКИ БАРА =================
    readonly property bool isVertical: cfg.barPosition === "left" || cfg.barPosition === "right"
    property int barWidth: cfg.barWidth
    property int barHeight: Math.max(26, Math.min(60, cfg.barHeight))
    property real barRadius: Math.min(cfg.barRadius, barHeight / 2)
    property color barColor: cfg.bgSurface
    property color borderColor: cfg.borderCol

    // Масштабируемые размеры шрифтов и иконок
    readonly property int fontSizePrimary: Math.max(11, Math.min(13, Math.round(barHeight * 0.36)))
    readonly property int fontSizeSmall: Math.max(9, Math.min(11, Math.round(barHeight * 0.30)))
    readonly property int iconSize: Math.max(13, Math.min(16, Math.round(barHeight * 0.42)))
    readonly property int dotHeight: Math.max(6, Math.min(9, Math.round(barHeight * 0.22)))
    readonly property int dotActiveWidth: Math.max(16, Math.min(26, Math.round(barHeight * 0.65)))

    // Фоновые процессы обновления датчиков
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true
            ramProc.running = true
            gpuProc.running = true
        }
    }

    Timer {
        interval: 600000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    // ================= СЛУШАТЕЛЬ ГРОМКОСТИ (КНОПКИ НАУШНИКОВ / PACTL / PIPEWIRE) =================
    property bool volInitialized: false
    property bool langInitialized: false

    // Мгновенный перехват изменения громкости кнопками наушников и клавиатуры
    Process {
        id: audioEventProc
        running: true
        command: ["sh", "-c", "pactl subscribe 2>/dev/null | grep --line-buffered \"'change' on sink\""]
        stdout: SplitParser {
            onRead: data => {
                volQueryProc.running = false
                volQueryProc.running = true
            }
        }
    }

    // Регулярный опрос громкости на случай внешних изменений
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            volQueryProc.running = false
            volQueryProc.running = true
        }
    }

    Process {
        id: volQueryProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100) \"|\" ($3==\"[MUTED]\"?\"MUT\":\"OK\")}'"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|")
                if (parts.length >= 2) {
                    let v = parseInt(parts[0]) || 0
                    let m = (parts[1] === "MUT")
                    let oldV = root.cfg.currentVolume
                    let oldM = root.cfg.isMuted
                    root.cfg.currentVolume = v
                    root.cfg.isMuted = m

                    if (!root.volInitialized) {
                        root.volInitialized = true
                    } else if (root.cfg.osdVolume && (oldV !== v || oldM !== m)) {
                        root.triggerOsd("volume", m ? "󰝟" : (v > 50 ? "󰕾" : "󰖀"), m ? "Без звука" : "Громкость", v)
                    }
                }
            }
        }
    }

    // Опрос Caps Lock
    property string lastCaps: "0"
    Timer {
        interval: 400; running: true; repeat: true
        onTriggered: capsProc.running = true
    }

    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*capslock*/brightness 2>/dev/null | head -n 1"]
        stdout: SplitParser {
            onRead: data => {
                let v = data.trim()
                if (v !== "" && v !== root.lastCaps) {
                    root.lastCaps = v
                    if (root.cfg.osdCaps) {
                        root.triggerOsd("caps", "󰪛", v === "1" ? "Caps Lock: ВКЛ" : "Caps Lock: ВЫКЛ", 0)
                    }
                }
            }
        }
    }

    Process {
        id: cpuProc
        command: ["python3", "-c", "import time; p1=[int(x) for x in open('/proc/stat').readline().split()[1:]]; time.sleep(0.08); p2=[int(x) for x in open('/proc/stat').readline().split()[1:]]; idle=p2[3]-p1[3]; total=sum(p2)-sum(p1); print(max(1, min(100, int(100*(1-idle/total)))))"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let v = data.trim()
                if (v !== "" && !isNaN(parseInt(v))) root.cfg.cpuVal = parseInt(v)
            }
        }
    }

    Process {
        id: ramProc
        command: ["sh", "-c", "free | awk '/Mem:/ {printf(\"%.0f\", $3/$2 * 100)}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let v = data.trim()
                if (v !== "" && !isNaN(parseInt(v))) root.cfg.ramVal = parseInt(v)
            }
        }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo '2'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let v = data.trim()
                if (v !== "" && !isNaN(parseInt(v))) root.cfg.gpuVal = parseInt(v)
            }
        }
    }

    Process {
        id: weatherProc
        running: true
        command: root.cfg.weatherAutoLocation
                 ? ["python3", root.cfg.qsDir + "/scripts/weather.py", "--auto"]
                 : ["python3", root.cfg.qsDir + "/scripts/weather.py", "--city", root.cfg.weatherCity]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim()
                if (!line || line === "") return
                try {
                    let j = JSON.parse(line)
                    if (j.temp) root.cfg.weatherText = j.temp
                    if (j.city) root.cfg.weatherCity = j.city
                    if (j.desc) root.cfg.weatherDesc = j.desc
                    if (j.icon) root.cfg.weatherIcon = j.icon
                    if (j.feels_like) root.cfg.weatherFeelsLike = j.feels_like
                    if (j.humidity) root.cfg.weatherHumidity = j.humidity
                    if (j.wind) root.cfg.weatherWind = j.wind
                    if (j.precip) root.cfg.weatherPrecip = j.precip
                } catch(e) {}
            }
        }
    }

    Connections {
        target: root.cfg
        function onRefreshWeather() {
            weatherProc.running = true
        }
    }

    // Слушатель раскладки клавиатуры
    Process {
        id: hyprSocketProc
        running: true
        command: ["python3", "-u", "-c", "import socket,os,glob,time,json,subprocess\nxdg=os.environ.get('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}')\nhis=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE','')\nsock=f'{xdg}/hypr/{his}/.socket2.sock' if his else ''\nif not sock or not os.path.exists(sock):\n    socks=glob.glob(f'{xdg}/hypr/*/.socket2.sock')\n    if socks: sock=sorted(socks,key=os.path.getmtime)[-1]\ntry:\n    devs=json.loads(subprocess.check_output(['hyprctl','devices','-j']).decode())\n    for k in devs.get('keyboards',[]):\n        if k.get('main'):\n            km=k.get('active_keymap','').lower()\n            print('RU' if 'rus' in km else 'EN',flush=True)\n            break\nexcept Exception:\n    pass\nwhile True:\n    try:\n        s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)\n        s.connect(sock)\n        for l in s.makefile('r'):\n            if l.startswith('activelayout>>'):\n                print(l.strip().split('>>')[1].split(',')[-1].strip()[:2].upper(),flush=True)\n    except Exception:\n        time.sleep(2)\n"]
        stdout: SplitParser {
            onRead: data => {
                let l = data.trim()
                if (l !== "") {
                    if (!root.langInitialized) {
                        root.langInitialized = true
                        root.cfg.currentLang = l
                    } else if (l !== root.cfg.currentLang) {
                        root.cfg.currentLang = l
                        if (root.cfg.osdLang) root.triggerOsd("lang", "󰌌", "Раскладка: " + l, 0)
                    }
                }
            }
        }
    }

    Process {
        id: switchLangProc
        command: ["sh", "-c", "hyprctl switchxkblayout all next"]
    }

    Process {
        id: volChangeProc
        property string cmdStr: ""
        command: ["sh", "-c", cmdStr]
        onExited: (code, status) => volQueryProc.running = true
    }

    function changeVolume(delta) {
        if (delta === "mute") {
            volChangeProc.cmdStr = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        } else {
            volChangeProc.cmdStr = "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + delta
        }
        volChangeProc.running = true
    }

    // ================= МОДУЛЬНЫЕ КОМПОНЕНТЫ ДЛЯ ГОРИЗОНТАЛЬНОГО РЕЖИМА =================
    Component {
        id: modLauncher
        Item {
            implicitWidth: root.iconSize + 10
            implicitHeight: root.iconSize + 10
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: lMouse.containsMouse ? root.cfg.accentContainer : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "󰀻"
                    color: root.cfg.accent
                    font.pixelSize: root.iconSize + 2
                }
                MouseArea {
                    id: lMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMenu("launcher")
                }
            }
        }
    }

    Component {
        id: modWorkspaces
        RowLayout {
            spacing: 6
            Repeater {
                model: root.activeWorkspaces
                Rectangle {
                    id: dot
                    required property int modelData
                    readonly property bool isActive: dot.modelData === root.currentWorkspaceId
                    Layout.preferredHeight: root.dotHeight
                    Layout.preferredWidth: isActive ? root.dotActiveWidth : root.dotHeight
                    radius: root.dotHeight / 2
                    color: isActive ? root.cfg.accent : (wsMouse.containsMouse ? root.cfg.accentContainer : "#545766")
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchToWorkspace(dot.modelData)
                    }
                }
            }
        }
    }

    Component {
        id: modClock
        Item {
            implicitWidth: hClock.implicitWidth + 12
            implicitHeight: 24
            Text {
                id: hClock
                anchors.centerIn: parent
                color: root.cfg.textPrimary
                font.pixelSize: root.fontSizePrimary
                font.bold: true
                function updateTime() {
                    hClock.text = Qt.formatDateTime(new Date(), root.cfg.showClockSeconds ? "hh:mm:ss" : "hh:mm")
                }
                Component.onCompleted: updateTime()
                Timer { interval: 1000; running: true; repeat: true; onTriggered: hClock.updateTime() }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleSidePanel()
            }
        }
    }

    Component {
        id: modWeather
        Item {
            implicitWidth: weatherRow.implicitWidth
            implicitHeight: weatherRow.implicitHeight
            RowLayout {
                id: weatherRow
                anchors.fill: parent
                spacing: 4
                Text { text: root.cfg.weatherIcon || "󰖐"; color: root.cfg.accent; font.pixelSize: root.iconSize }
                Text { text: root.cfg.weatherText; color: root.cfg.textPrimary; font.pixelSize: root.fontSizePrimary; font.bold: true }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: weatherProc.running = true
            }
        }
    }

    Component {
        id: modCpu
        RowLayout {
            spacing: 4
            Text { text: "󰍛"; color: root.cfg.accent; font.pixelSize: root.iconSize }
            Text { text: root.cfg.cpuVal + "%"; color: root.cfg.textPrimary; font.pixelSize: root.fontSizePrimary; font.bold: true }
        }
    }

    Component {
        id: modRam
        RowLayout {
            spacing: 4
            Text { text: "󰘚"; color: root.cfg.accent; font.pixelSize: root.iconSize }
            Text { text: root.cfg.ramVal + "%"; color: root.cfg.textPrimary; font.pixelSize: root.fontSizePrimary; font.bold: true }
        }
    }

    Component {
        id: modGpu
        RowLayout {
            spacing: 4
            Text { text: "󰢮"; color: root.cfg.accent; font.pixelSize: root.iconSize }
            Text { text: root.cfg.gpuVal + "%"; color: root.cfg.textPrimary; font.pixelSize: root.fontSizePrimary; font.bold: true }
        }
    }

    Component {
        id: modNet
        Text {
            text: "󰈀"
            color: netMouse.containsMouse ? root.cfg.accent : root.cfg.textMuted
            font.pixelSize: root.iconSize
            MouseArea {
                id: netMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMenu("eth")
            }
        }
    }

    Component {
        id: modBt
        Text {
            text: "󰂯"
            color: btMouse.containsMouse ? root.cfg.accent : root.cfg.textMuted
            font.pixelSize: root.iconSize
            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMenu("bt")
            }
        }
    }

    Component {
        id: modLang
        Text {
            text: root.cfg.currentLang
            color: langMouse.containsMouse ? root.cfg.accent : root.cfg.textPrimary
            font.pixelSize: root.fontSizePrimary
            font.bold: true
            MouseArea {
                id: langMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: switchLangProc.running = true
            }
        }
    }

    Component {
        id: modVol
        Item {
            implicitWidth: volRow.implicitWidth
            implicitHeight: volRow.implicitHeight
            RowLayout {
                id: volRow
                spacing: 4
                Text {
                    text: root.cfg.isMuted ? "󰝟" : (root.cfg.currentVolume > 50 ? "󰕾" : "󰖀")
                    color: root.cfg.isMuted ? root.cfg.danger : root.cfg.textMuted
                    font.pixelSize: root.iconSize
                }
                Text {
                    text: root.cfg.isMuted ? "MUT" : root.cfg.currentVolume + "%"
                    color: root.cfg.textPrimary
                    font.pixelSize: root.fontSizePrimary
                    font.bold: true
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onWheel: wheel => root.changeVolume(wheel.angleDelta.y > 0 ? "5%+" : "5%-")
                onClicked: root.changeVolume("mute")
            }
        }
    }

    Component {
        id: modTray
        RowLayout {
            visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0
            spacing: 6
            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: trayItemRoot
                    required property var modelData
                    width: root.iconSize + 6
                    height: root.iconSize + 6

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: trayMouse.containsMouse ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Image {
                            anchors.centerIn: parent
                            width: root.iconSize
                            height: root.iconSize
                            source: root.resolveTrayIcon(modelData.icon)
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !modelData.icon || modelData.icon === ""
                            text: "󰍜"
                            font.pixelSize: root.iconSize
                            color: root.cfg.textMuted
                        }
                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                let pos = trayItemRoot.mapToItem(null, 0, 0)
                                let cx = pos.x + trayItemRoot.width / 2
                                if (mouse.button === Qt.RightButton) {
                                    root.openTrayMenu(modelData, cx, pos.y)
                                } else if (mouse.button === Qt.LeftButton) {
                                    if (modelData.onlyMenu) {
                                        root.openTrayMenu(modelData, cx, pos.y)
                                    } else {
                                        modelData.activate(0, 0)
                                    }
                                } else if (mouse.button === Qt.MiddleButton) {
                                    modelData.secondaryActivate(0, 0)
                                }
                            }
                            onWheel: wheel => {
                                modelData.scroll(wheel.angleDelta.y, false)
                            }
                        }
                    }
                }
            }
        }
    }

    function getHorizontalModule(id) {
        if (id === "launcher") return modLauncher
        if (id === "workspaces") return modWorkspaces
        if (id === "clock") return modClock
        if (id === "weather") return modWeather
        if (id === "cpu") return modCpu
        if (id === "ram") return modRam
        if (id === "gpu") return modGpu
        if (id === "net") return modNet
        if (id === "bt") return modBt
        if (id === "lang") return modLang
        if (id === "vol") return modVol
        if (id === "tray") return modTray
        return null
    }

    // ================= МОДУЛЬНЫЕ КОМПОНЕНТЫ ДЛЯ ВЕРТИКАЛЬНОГО РЕЖИМА =================
    Component {
        id: vModLauncher
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: root.iconSize + 8
            height: width
            radius: width / 2
            color: vlMouse.containsMouse ? root.cfg.accentContainer : "transparent"
            Text { anchors.centerIn: parent; text: "󰀻"; color: root.cfg.accent; font.pixelSize: root.iconSize + 2 }
            MouseArea {
                id: vlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMenu("launcher")
            }
        }
    }

    Component {
        id: vModWorkspaces
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 5
            Repeater {
                model: root.activeWorkspaces
                Rectangle {
                    id: vDot
                    required property int modelData
                    readonly property bool isActive: vDot.modelData === root.currentWorkspaceId
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.dotHeight
                    Layout.preferredHeight: isActive ? root.dotActiveWidth : root.dotHeight
                    radius: root.dotHeight / 2
                    color: isActive ? root.cfg.accent : (vWsMouse.containsMouse ? root.cfg.accentContainer : "#545766")
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea {
                        id: vWsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.switchToWorkspace(vDot.modelData)
                    }
                }
            }
        }
    }

    Component {
        id: vModClock
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: parent ? parent.width : 38
            height: vClockCol.implicitHeight
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleSidePanel()
            }
            ColumnLayout {
                id: vClockCol
                anchors.centerIn: parent
                spacing: 2
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(new Date(), "hh")
                    color: root.cfg.textPrimary
                    font.pixelSize: Math.max(12, Math.min(15, Math.round(root.barHeight * 0.38)))
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(new Date(), "mm")
                    color: root.cfg.accent
                    font.pixelSize: Math.max(11, Math.min(13, Math.round(root.barHeight * 0.34)))
                    font.bold: true
                }
                Text {
                    visible: root.cfg.showClockSeconds
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(new Date(), "ss")
                    color: root.cfg.textMuted
                    font.pixelSize: Math.max(9, Math.min(10, Math.round(root.barHeight * 0.28)))
                }
            }
        }
    }

    Component {
        id: vModWeather
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 1
            Text { Layout.alignment: Qt.AlignHCenter; text: root.cfg.weatherIcon || "󰖐"; color: root.cfg.accent; font.pixelSize: 13 }
            Text { Layout.alignment: Qt.AlignHCenter; text: root.cfg.weatherText.replace("+", ""); color: root.cfg.textPrimary; font.pixelSize: 9; font.bold: true }
        }
    }

    Component {
        id: vModCpu
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 1
            Text { Layout.alignment: Qt.AlignHCenter; text: "󰍛"; color: root.cfg.accent; font.pixelSize: 13 }
            Text { Layout.alignment: Qt.AlignHCenter; text: root.cfg.cpuVal + "%"; color: root.cfg.textPrimary; font.pixelSize: 9; font.bold: true }
        }
    }

    Component {
        id: vModRam
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 1
            Text { Layout.alignment: Qt.AlignHCenter; text: "󰘚"; color: root.cfg.accent; font.pixelSize: 13 }
            Text { Layout.alignment: Qt.AlignHCenter; text: root.cfg.ramVal + "%"; color: root.cfg.textPrimary; font.pixelSize: 9; font.bold: true }
        }
    }

    Component {
        id: vModGpu
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 1
            Text { Layout.alignment: Qt.AlignHCenter; text: "󰢮"; color: root.cfg.accent; font.pixelSize: 13 }
            Text { Layout.alignment: Qt.AlignHCenter; text: root.cfg.gpuVal + "%"; color: root.cfg.textPrimary; font.pixelSize: 9; font.bold: true }
        }
    }

    Component {
        id: vModNet
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰈀"
            color: vNetMouse.containsMouse ? root.cfg.accent : root.cfg.textMuted
            font.pixelSize: 14
            MouseArea {
                id: vNetMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMenu("eth")
            }
        }
    }

    Component {
        id: vModBt
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰂯"
            color: vBtMouse.containsMouse ? root.cfg.accent : root.cfg.textMuted
            font.pixelSize: 14
            MouseArea {
                id: vBtMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMenu("bt")
            }
        }
    }

    Component {
        id: vModLang
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.cfg.currentLang
            color: vLangMouse.containsMouse ? root.cfg.accent : root.cfg.textPrimary
            font.pixelSize: 11
            font.bold: true
            MouseArea {
                id: vLangMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: switchLangProc.running = true
            }
        }
    }

    Component {
        id: vModVol
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: vVolCol.implicitWidth
            implicitHeight: vVolCol.implicitHeight
            ColumnLayout {
                id: vVolCol
                anchors.centerIn: parent
                spacing: 1
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.cfg.isMuted ? "󰝟" : (root.cfg.currentVolume > 50 ? "󰕾" : "󰖀")
                    color: root.cfg.isMuted ? root.cfg.danger : (vVolMouse.containsMouse ? root.cfg.accent : root.cfg.textMuted)
                    font.pixelSize: 13
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.cfg.isMuted ? "MUT" : root.cfg.currentVolume + "%"
                    color: root.cfg.textPrimary
                    font.pixelSize: 8
                    font.bold: true
                }
            }
            MouseArea {
                id: vVolMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onWheel: wheel => root.changeVolume(wheel.angleDelta.y > 0 ? "5%+" : "5%-")
                onClicked: root.changeVolume("mute")
            }
        }
    }

    Component {
        id: vModTray
        ColumnLayout {
            visible: SystemTray.items && SystemTray.items.values && SystemTray.items.values.length > 0
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: vTrayItemRoot
                    required property var modelData
                    width: root.iconSize + 4
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: vTrayMouse.containsMouse ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.2) : "transparent"
                        Image {
                            anchors.centerIn: parent
                            width: root.iconSize
                            height: root.iconSize
                            source: root.resolveTrayIcon(modelData.icon)
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }
                        MouseArea {
                            id: vTrayMouse; anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                let pos = vTrayItemRoot.mapToItem(null, 0, 0)
                                let cx = pos.x + vTrayItemRoot.width / 2
                                if (mouse.button === Qt.RightButton) {
                                    root.openTrayMenu(modelData, cx, pos.y)
                                } else if (mouse.button === Qt.LeftButton) {
                                    if (modelData.onlyMenu) {
                                        root.openTrayMenu(modelData, cx, pos.y)
                                    } else {
                                        modelData.activate(0, 0)
                                    }
                                } else if (mouse.button === Qt.MiddleButton) {
                                    modelData.secondaryActivate(0, 0)
                                }
                            }
                            onWheel: wheel => modelData.scroll(wheel.angleDelta.y, true)
                        }
                    }
                }
            }
        }
    }

    function getVerticalModule(id) {
        if (id === "launcher") return vModLauncher
        if (id === "workspaces") return vModWorkspaces
        if (id === "clock") return vModClock
        if (id === "weather") return vModWeather
        if (id === "cpu") return vModCpu
        if (id === "ram") return vModRam
        if (id === "gpu") return vModGpu
        if (id === "net") return vModNet
        if (id === "bt") return vModBt
        if (id === "lang") return vModLang
        if (id === "vol") return vModVol
        if (id === "tray") return vModTray
        return null
    }

    // ================= ПАЕТЕРН МОДУЛЬНОГО ПУЗЫРЬКА (BUBBLE / PILL) С DRAG & DROP =================
    component BubbleWrapper: Item {
        id: bubbleContainer
        required property string modelData
        required property int index
        required property string zone

        property bool isDragging: false

        implicitWidth: bubbleRect.implicitWidth
        implicitHeight: bubbleRect.implicitHeight
        z: isDragging ? 200 : 1

        Rectangle {
            id: bubbleRect
            anchors.verticalCenter: parent.verticalCenter
            x: 0

            readonly property bool isGroup: bubbleContainer.modelData.indexOf("+") !== -1
            readonly property int effectiveRadius: {
                if (!root.cfg.barModuleBubbles) return 6
                let r = (root.cfg.barModuleRadius !== undefined) ? root.cfg.barModuleRadius : 16
                if (r >= 20 || r < 0) return Math.round(implicitHeight / 2)
                return Math.min(Math.round(implicitHeight / 2), r)
            }

            implicitHeight: root.cfg.barModuleBubbles ? Math.max(26, root.barHeight - 6) : root.barHeight - 4
            implicitWidth: {
                let pad = root.cfg.barModuleBubbles ? 16 : 6
                if (isGroup) return groupRow.implicitWidth + pad
                return (modLoader.item ? modLoader.item.implicitWidth : 22) + pad
            }
            radius: effectiveRadius

            color: root.cfg.barModuleBubbles
                   ? (bubbleContainer.isDragging
                      ? root.cfg.primaryContainer
                      : (bubbleHoverM.containsMouse
                         ? root.cfg.bgElevated
                         : Qt.rgba(root.cfg.surfaceContainer.r, root.cfg.surfaceContainer.g, root.cfg.surfaceContainer.b, root.cfg.barBubbleOpacity)))
                   : (bubbleHoverM.containsMouse ? Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12) : "transparent")

            border.color: root.cfg.barModuleBubbles
                          ? (bubbleContainer.isDragging || bubbleHoverM.containsMouse ? root.cfg.accent : root.cfg.borderCol)
                          : "transparent"
            border.width: root.cfg.barModuleBubbles ? 1 : 0

            scale: bubbleContainer.isDragging ? 1.08 : (bubbleHoverM.pressed ? 0.94 : 1.0)
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            // Взаимодействие с фоном модуля
            MouseArea {
                id: bubbleHoverM
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.openModuleContextMenu(bubbleContainer.modelData, bubbleContainer.zone, bubbleContainer.index, bubbleRect)
                    } else if (mouse.button === Qt.LeftButton && !bubbleRect.isGroup) {
                        let id = bubbleContainer.modelData
                        if (id === "launcher") root.toggleMenu("launcher")
                        else if (id === "clock") root.toggleSidePanel()
                        else if (id === "weather") weatherProc.running = true
                        else if (id === "vol") root.toggleSidePanel()
                        else if (id === "net" || id === "bt") root.toggleMenu(id)
                    }
                }
            }

            // Контент: объединённая группа модулей
            RowLayout {
                id: groupRow
                anchors.centerIn: parent
                spacing: 8
                visible: bubbleRect.isGroup
                z: 5

                Repeater {
                    model: bubbleRect.isGroup ? bubbleContainer.modelData.split("+") : []
                    delegate: RowLayout {
                        required property string modelData
                        required property int index
                        spacing: 8

                        Loader {
                            sourceComponent: root.getHorizontalModule(modelData)
                        }

                        Rectangle {
                            visible: index < bubbleContainer.modelData.split("+").length - 1
                            width: 1
                            height: Math.max(10, root.barHeight - 16)
                            color: root.cfg.borderCol
                            opacity: 0.6
                        }
                    }
                }
            }

            // Контент: одиночный модуль
            Loader {
                id: modLoader
                anchors.centerIn: parent
                visible: !bubbleRect.isGroup
                sourceComponent: bubbleRect.isGroup ? null : root.getHorizontalModule(bubbleContainer.modelData)
                z: 5
            }
        }
    }

    // ================= ГЛАВНАЯ КАПСУЛА БАРА =================
    Rectangle {
        id: mainCapsule

        width: root.isVertical ? Math.max(38, root.barHeight) : (root.cfg.barStyle === "attached" ? Math.min(parent.width - 24, root.barWidth) : Math.min(parent.width - 24, root.barWidth))
        height: root.isVertical ? Math.min(parent.height - 24, root.cfg.barVerticalHeight) : root.barHeight

        // Скругления:
        // Для attached: скруглены ТОЛЬКО нижние углы (bottomLeft и bottomRight), верхние прямые (0)
        radius: root.barRadius
        topLeftRadius: (root.cfg.barStyle === "attached" && root.cfg.barPosition !== "bottom" && !root.isVertical) ? 0 : root.barRadius
        topRightRadius: (root.cfg.barStyle === "attached" && root.cfg.barPosition !== "bottom" && !root.isVertical) ? 0 : root.barRadius
        bottomLeftRadius: (root.cfg.barStyle === "attached" && root.cfg.barPosition === "bottom" && !root.isVertical) ? 0 : root.barRadius
        bottomRightRadius: (root.cfg.barStyle === "attached" && root.cfg.barPosition === "bottom" && !root.isVertical) ? 0 : root.barRadius

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: (root.cfg.barStyle === "attached" && root.cfg.barPosition !== "bottom" && !root.isVertical) ? parent.top : undefined
        anchors.bottom: (root.cfg.barStyle === "attached" && root.cfg.barPosition === "bottom" && !root.isVertical) ? parent.bottom : undefined
        anchors.verticalCenter: (root.cfg.barStyle !== "attached" || root.isVertical) ? parent.verticalCenter : undefined

        color: root.cfg.barStyle === "bubbles" ? "transparent" : Qt.rgba(root.barColor.r, root.barColor.g, root.barColor.b, root.cfg.barOpacity)
        border.color: root.cfg.barStyle === "bubbles" ? "transparent" : Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, root.cfg.barOpacity)
        border.width: root.cfg.barStyle === "bubbles" ? 0 : 1

        // ================= 1. ГОРИЗОНТАЛЬНЫЙ РЕЖИМ (Сверху / Снизу) =================
        Item {
            anchors.fill: parent
            anchors.margins: 4
            visible: !root.isVertical
            clip: false

            // ЦЕНТР: barModulesCenter
            RowLayout {
                id: centerClockBox
                anchors.centerIn: parent
                spacing: root.cfg.barBubbleSpacing || 8
                Repeater {
                    model: root.cfg.barModulesCenter
                    BubbleWrapper {
                        zone: "center"
                    }
                }
            }

            // ЛЕВЫЙ БЛОК: barModulesLeft
            Item {
                id: leftSection
                anchors.left: root.cfg.swapBarSides ? centerClockBox.right : parent.left
                anchors.right: root.cfg.swapBarSides ? parent.right : centerClockBox.left
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                clip: false

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: root.cfg.swapBarSides ? undefined : parent.left
                    anchors.right: root.cfg.swapBarSides ? parent.right : undefined
                    spacing: root.cfg.barBubbleSpacing || 8
                    Repeater {
                        model: root.cfg.swapBarSides ? root.cfg.barModulesRight : root.cfg.barModulesLeft
                        BubbleWrapper {
                            zone: root.cfg.swapBarSides ? "right" : "left"
                        }
                    }
                }
            }

            // ПРАВЫЙ БЛОК: barModulesRight
            Item {
                id: rightSection
                anchors.left: root.cfg.swapBarSides ? parent.left : centerClockBox.right
                anchors.right: root.cfg.swapBarSides ? centerClockBox.left : parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                clip: false

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: root.cfg.swapBarSides ? undefined : parent.right
                    anchors.left: root.cfg.swapBarSides ? parent.left : undefined
                    spacing: root.cfg.barBubbleSpacing || 8
                    Repeater {
                        model: root.cfg.swapBarSides ? root.cfg.barModulesLeft : root.cfg.barModulesRight
                        BubbleWrapper {
                            zone: root.cfg.swapBarSides ? "left" : "right"
                        }
                    }
                }
            }
        }

        // ================= 2. ВЕРТИКАЛЬНЫЙ РЕЖИМ (Слева / Справа) =================
        Item {
            anchors.fill: parent
            anchors.margins: 6
            visible: root.isVertical
            clip: true

            // ЦЕНТР ПО ВЕРТИКАЛИ: barModulesCenter
            ColumnLayout {
                id: vCenterClock
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: root.cfg.barModulesCenter
                    delegate: Loader {
                        required property string modelData
                        sourceComponent: root.getVerticalModule(modelData)
                    }
                }
            }

            // ВЕРХНИЙ БЛОК: barModulesLeft
            Item {
                anchors.top: parent.top
                anchors.bottom: vCenterClock.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottomMargin: 8
                clip: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    Repeater {
                        model: root.cfg.barModulesLeft
                        delegate: Loader {
                            required property string modelData
                            sourceComponent: root.getVerticalModule(modelData)
                        }
                    }
                }
            }

            // НИЖНИЙ БЛОК: barModulesRight
            Item {
                anchors.top: vCenterClock.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 8
                clip: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Repeater {
                        model: root.cfg.barModulesRight
                        delegate: Loader {
                            required property string modelData
                            sourceComponent: root.getVerticalModule(modelData)
                        }
                    }
                }
            }
        }
    }

    function openModuleContextMenu(modId, zone, idx, targetItem) {
        modContextPopup.currentModId = modId
        modContextPopup.currentZone = zone
        modContextPopup.currentIndex = idx

        let p = targetItem.mapToItem(root, 0, 0)
        let popupX = Math.max(10, Math.min(root.width - modContextPopup.width - 10, p.x + (targetItem.width - modContextPopup.width) / 2))
        let popupY = root.cfg.barPosition === "bottom" ? (p.y - modContextPopup.height - 8) : (p.y + targetItem.height + 8)

        modContextPopup.x = popupX
        modContextPopup.y = popupY
        modContextPopup.visible = true
    }

    // Фоновый перехватчик клика для закрытия контекстного меню
    MouseArea {
        anchors.fill: parent
        visible: modContextPopup.visible
        z: 998
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: modContextPopup.visible = false
    }

    // Всплывающее меню контекстных действий модуля
    Item {
        id: modContextPopup
        visible: false
        z: 999
        width: 176
        height: contextCol.implicitHeight + 16

        property string currentModId: ""
        property string currentZone: ""
        property int currentIndex: 0

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.outlineVariant
            border.width: 1

            ColumnLayout {
                id: contextCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: {
                        if (modContextPopup.currentModId.indexOf("+") !== -1) {
                            let parts = modContextPopup.currentModId.split("+")
                            let icons = parts.map(p => {
                                let f = root.cfg.allBarModules.find(x => x.id === p)
                                return f ? f.icon : "󰍛"
                            }).join(" ")
                            return "󰘖 " + icons + " (Группа)"
                        }
                        let m = root.cfg.allBarModules.find(x => x.id === modContextPopup.currentModId)
                        return (m ? (m.icon + " " + m.name) : "Модуль")
                    }
                    color: root.cfg.textMuted
                    font.pixelSize: 10
                    font.bold: true
                    font.family: root.cfg.fontFamily
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.cfg.borderCol }

                // Разъединить объединённую группу модулей
                Rectangle {
                    visible: modContextPopup.currentModId.indexOf("+") !== -1
                    Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 8
                    color: cSplitM.containsMouse ? root.cfg.bgElevated : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 6
                        Text { text: "✂"; color: root.cfg.accent; font.pixelSize: 11 }
                        Text { text: "Разъединить группу"; color: root.cfg.textPrimary; font.pixelSize: 11; font.family: root.cfg.fontFamily }
                    }
                    MouseArea {
                        id: cSplitM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cfg.splitBarModule(modContextPopup.currentZone, modContextPopup.currentIndex)
                            modContextPopup.visible = false
                        }
                    }
                }

                // Объединить со следующим модулем
                Rectangle {
                    readonly property int zoneLen: {
                        let z = modContextPopup.currentZone
                        let l = z === "left" ? root.cfg.barModulesLeft : (z === "center" ? root.cfg.barModulesCenter : root.cfg.barModulesRight)
                        return l ? l.length : 0
                    }
                    visible: modContextPopup.currentIndex < zoneLen - 1
                    Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 8
                    color: cCombM.containsMouse ? root.cfg.bgElevated : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 6
                        Text { text: "🔗"; color: root.cfg.accent; font.pixelSize: 11 }
                        Text { text: "Объединить со следующим"; color: root.cfg.textPrimary; font.pixelSize: 11; font.family: root.cfg.fontFamily }
                    }
                    MouseArea {
                        id: cCombM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cfg.combineBarModules(modContextPopup.currentZone, modContextPopup.currentIndex)
                            modContextPopup.visible = false
                        }
                    }
                }

                // 1. Сдвинуть влево
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 8
                    color: cM1.containsMouse ? root.cfg.bgElevated : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 6
                        Text { text: "⬅"; color: root.cfg.accent; font.pixelSize: 11 }
                        Text { text: "Сдвинуть влево"; color: root.cfg.textPrimary; font.pixelSize: 11; font.family: root.cfg.fontFamily }
                    }
                    MouseArea {
                        id: cM1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cfg.reorderBarModule(modContextPopup.currentZone, modContextPopup.currentIndex, -1)
                            modContextPopup.visible = false
                        }
                    }
                }

                // 2. Сдвинуть вправо
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 8
                    color: cM2.containsMouse ? root.cfg.bgElevated : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 6
                        Text { text: "➡"; color: root.cfg.accent; font.pixelSize: 11 }
                        Text { text: "Сдвинуть вправо"; color: root.cfg.textPrimary; font.pixelSize: 11; font.family: root.cfg.fontFamily }
                    }
                    MouseArea {
                        id: cM2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cfg.reorderBarModule(modContextPopup.currentZone, modContextPopup.currentIndex, 1)
                            modContextPopup.visible = false
                        }
                    }
                }

                // 3. Переместить в другую зону
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 8
                    color: cM3.containsMouse ? root.cfg.bgElevated : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 6
                        Text { text: "🔀"; color: root.cfg.accent; font.pixelSize: 11 }
                        Text {
                            text: modContextPopup.currentZone === "center" ? "Перенести вправо" : (modContextPopup.currentZone === "left" ? "Перенести в центр" : "Перенести влево")
                            color: root.cfg.textPrimary
                            font.pixelSize: 11
                            font.family: root.cfg.fontFamily
                        }
                    }
                    MouseArea {
                        id: cM3; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let nextZone = modContextPopup.currentZone === "left" ? "center" : (modContextPopup.currentZone === "center" ? "right" : "left")
                            root.cfg.moveBarModule(modContextPopup.currentModId, nextZone)
                            modContextPopup.visible = false
                        }
                    }
                }

                // 4. Скрыть модуль
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 26; radius: 8
                    color: cM4.containsMouse ? root.cfg.bgElevated : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 6
                        Text { text: "❌"; color: root.cfg.danger; font.pixelSize: 11 }
                        Text { text: "Скрыть модуль"; color: root.cfg.danger; font.pixelSize: 11; font.family: root.cfg.fontFamily }
                    }
                    MouseArea {
                        id: cM4; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cfg.removeBarModule(modContextPopup.currentModId)
                            modContextPopup.visible = false
                        }
                    }
                }
            }
        }
    }
}
