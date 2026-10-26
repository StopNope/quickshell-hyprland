import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import "./modules"

ShellRoot {
    id: root

    Config {
        id: appConfig
    }

    IpcHandler {
        target: "shell"

        function toggleSide(): void {
            if (sideWindow.visible) sideWindow.closePanel()
            else sideWindow.openPanel()
        }

        function toggleSettings(): void {
            if (settingsOverlay.visible) settingsOverlay.close()
            else settingsOverlay.open()
        }

        function openSettingsWidgets(): void {
            settingsOverlay.open("widgets")
        }

        function openSettingsBar(): void {
            settingsOverlay.open("bar")
        }

        function toggleWidgetEditor(): void {
            if (widgetEditorWin.visible) widgetEditorWin.close()
            else widgetEditorWin.open("widgets")
        }

        function openOsdEditor(): void {
            widgetEditorWin.open("osd")
        }

        function openBarEditor(): void {
            widgetEditorWin.open("bar")
        }

        function toggleBarEditor(): void {
            if (widgetEditorWin.visible && widgetEditorView.mode === "bar") widgetEditorWin.close()
            else widgetEditorWin.open("bar")
        }

        function setSettingsTab(t: string): void {
            if (!settingsOverlay.visible) settingsOverlay.open()
            settingsView.tab = t
        }

        function scrollSettings(y: int): void {
            if (settingsOverlay.visible) settingsView.scrollContent(y)
        }

        function cycleWidget(id: string): void {
            appConfig.cycleWidgetVariant(id)
        }

        function setWidgetSize(id: string, s: string): void {
            appConfig.setWidgetSize(id, s)
        }

        function showOsd(type: string, icon: string, title: string, val: int): void {
            osdPopup.trigger(type, icon, title, val)
        }

        function setBarModuleBubbles(enabled: bool): void {
            appConfig.barModuleBubbles = enabled
            appConfig.save()
        }

        function combineBarModules(zone: string, idx: int): void {
            appConfig.combineBarModules(zone, idx)
        }

        function splitBarModule(zone: string, idx: int): void {
            appConfig.splitBarModule(zone, idx)
        }

        function setBarPreset(p: string): void {
            if (p === "island_groups") {
                appConfig.barStyle = "bubbles"
                appConfig.barModuleBubbles = true
                appConfig.barModulesLeft = ["launcher", "workspaces"]
                appConfig.barModulesCenter = ["clock+weather"]
                appConfig.barModulesRight = ["cpu+ram+gpu", "net+bt+vol", "tray"]
                appConfig.save()
            } else if (p === "islands") {
                appConfig.barStyle = "bubbles"
                appConfig.barModuleBubbles = true
                appConfig.barModulesLeft = ["workspaces", "ram"]
                appConfig.barModulesCenter = ["clock"]
                appConfig.barModulesRight = ["tray", "vol", "lang"]
                appConfig.save()
            } else if (p === "monolith") {
                appConfig.barStyle = "monolith"
                appConfig.barModuleBubbles = false
                appConfig.barModulesLeft = ["workspaces", "ram", "weather"]
                appConfig.barModulesCenter = ["clock"]
                appConfig.barModulesRight = ["tray", "net", "bt", "lang", "vol"]
                appConfig.save()
            }
        }
    }

    // Автоматически включаем blur для слоев quickshell, lockscreen и notifications в Hyprland
    Process {
        running: true
        command: ["sh", "-c", "hyprctl eval \"hl.layer_rule({ match = { namespace = 'quickshell' }, blur = true, ignore_alpha = 0.1 }); hl.layer_rule({ match = { namespace = 'quickshell-dock' }, no_anim = true }); hl.layer_rule({ match = { namespace = 'lockscreen' }, blur = true, ignore_alpha = 0.1 }); hl.layer_rule({ match = { namespace = 'notifications' }, blur = true, ignore_alpha = 0.1 })\" 2>/dev/null || true"]
    }

    // Фоновый демон для снятия миниатюр окон (Windows 11 Alt-Tab previews)
    Process {
        id: thumbWatcherProc
        running: true
        command: ["/home/stopnope/.config/quickshell/thumb_watcher.py"]
    }

    Process {
        id: vxwmProc
        running: false
        command: ["/home/stopnope/.config/quickshell/scripts/vxwm_controller.py", "toggle"]
    }

    Process {
        id: vxwmClampProc
        running: false
        command: ["/home/stopnope/.config/quickshell/scripts/vxwm_controller.py", "toggle_clamp"]
    }

    // ==========================================
    // IPC ПАЙП ДЛЯ ХОТКЕЕВ
    // ==========================================
    Process {
        id: ipcServer
        running: true
        command: ["/home/stopnope/.config/quickshell/ipc_server.py"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let cmd = data.trim()
                if (cmd === "toggle_settings") {
                    if (settingsOverlay.visible) settingsOverlay.close()
                    else settingsOverlay.open()
                } else if (cmd.startsWith("open_settings")) {
                    let parts = cmd.split(":")
                    let t = parts.length > 1 ? parts[1] : "bar"
                    settingsOverlay.open(t)
                } else if (cmd.startsWith("scroll_settings")) {
                    let parts = cmd.split(":")
                    let y = parts.length > 1 ? parseInt(parts[1]) : 0
                    if (settingsOverlay.visible) settingsView.scrollContent(y)
                } else if (cmd === "toggle_side") {
                    if (sideWindow.visible) sideWindow.closePanel()
                    else sideWindow.openPanel()
                } else if (cmd === "lock") {
                    appConfig.lock()
                } else if (cmd === "unlock") {
                    appConfig.isLocked = false
                } else if (cmd === "switcher_next") {
                    switcherOverlay.openNext()
                } else if (cmd === "switcher_prev") {
                    switcherOverlay.openPrev()
                } else if (cmd === "switcher_commit") {
                    switcherOverlay.commit()
                } else if (cmd === "switcher_close") {
                    switcherOverlay.close()
                } else if (cmd === "toggle_launcher") {
                    launcherOverlay.toggle()
                } else if (cmd === "open_launcher") {
                    launcherOverlay.open()
                } else if (cmd === "close_launcher") {
                    launcherOverlay.close()
                } else if (cmd === "toggle_clipboard") {
                    clipboardOverlay.toggle()
                } else if (cmd === "open_clipboard") {
                    clipboardOverlay.open()
                } else if (cmd === "close_clipboard") {
                    clipboardOverlay.close()
                } else if (cmd.startsWith("open_screenshot") || cmd.startsWith("start_screenshot")) {
                    let parts = cmd.split(":")
                    let sName = parts.length > 1 ? parts[1] : ""
                    screenshotOverlay.open(sName)
                } else if (cmd === "close_screenshot") {
                    screenshotOverlay.close()
                } else if (cmd.startsWith("toggle_menu")) {
                    let parts = cmd.split(":")
                    let tab = parts.length > 1 ? parts[1] : "wifi"
                    if (menuWindow.visible && controlMenu.activeTab === tab) menuWindow.closeMenu()
                    else menuWindow.openMenu(tab)
                } else if (cmd === "toggle_widget_editor") {
                    if (widgetEditorWin.visible) widgetEditorWin.close()
                    else widgetEditorWin.open("widgets")
                } else if (cmd === "open_widget_editor") {
                    widgetEditorWin.open("widgets")
                } else if (cmd === "close_widget_editor") {
                    widgetEditorWin.close()
                } else if (cmd === "open_osd_editor") {
                    widgetEditorWin.open("osd")
                } else if (cmd === "open_bar_editor" || cmd === "toggle_bar_editor") {
                    widgetEditorWin.open("bar")
                } else if (cmd === "toggle_dock") {
                    appConfig.dockEnabled = !appConfig.dockEnabled
                    appConfig.save()
                    osdPopup.trigger("dock", "󰀻", appConfig.dockEnabled ? "Док-бар: Включен" : "Док-бар: Выключен", 0)
                } else if (cmd === "toggle_dock_autohide") {
                    appConfig.dockAutohide = !appConfig.dockAutohide
                    appConfig.save()
                    osdPopup.trigger("dock", "󰀻", appConfig.dockAutohide ? "Автоскрытие дока: Вкл" : "Автоскрытие дока: Выкл", 0)
                } else if (cmd === "toggle_vxwm") {
                    vxwmProc.running = true
                } else if (cmd === "toggle_vxwm_clamp") {
                    vxwmClampProc.running = true
                } else if (cmd === "toggle_dnd") {
                    appConfig.dndMode = !appConfig.dndMode
                    appConfig.save()
                } else if (cmd === "toggle_nightlight") {
                    appConfig.nightLight = !appConfig.nightLight
                    appConfig.save()
                } else if (cmd === "toggle_powersave") {
                    appConfig.powerSaveMode = !appConfig.powerSaveMode
                    appConfig.save()
                } else if (cmd.startsWith("osd:")) {
                    let p = cmd.split(":")
                    if (p.length >= 4) {
                        osdPopup.trigger(p[1], p[2], p.slice(3).join(":"), 0)
                    } else if (p.length === 3) {
                        osdPopup.trigger(p[1], "󰍹", p[2], 0)
                    } else if (p.length === 2) {
                        osdPopup.trigger("vxwm", "󰍹", p[1], 0)
                    }
                } else if (cmd.startsWith("notify:")) {
                    let p = cmd.split(":")
                    if (p.length >= 3) {
                        appConfig.pushNotification(p[1], p.slice(2).join(":"))
                        if (!appConfig.dndMode) osdPopup.trigger("lang", "󰂚", p[1] + ": " + p[2], 0)
                    }
                }
            }
        }
    }

    // ==========================================
    // 1. ОКНО БАРА (С РАВНЫМИ ЗАЗОРАМИ СВЕРХУ И СНИЗУ)
    // ==========================================
    PanelWindow {
        id: barWindow

        color: "transparent"
        visible: !appConfig.isLocked
        WlrLayershell.namespace: "quickshell"

        readonly property bool isVert: appConfig.barPosition === "left" || appConfig.barPosition === "right"

        anchors {
            top: appConfig.barPosition !== "bottom"
            bottom: appConfig.barPosition !== "top"
            left: appConfig.barPosition !== "right"
            right: appConfig.barPosition !== "left"
        }

        margins {
            top: appConfig.barPosition === "top" ? 10 : 0
            bottom: appConfig.barPosition === "bottom" ? 10 : 0
            left: appConfig.barPosition === "left" ? 10 : 0
            right: appConfig.barPosition === "right" ? 10 : 0
        }

        // Высота/ширина окна бара
        implicitHeight: isVert ? appConfig.barVerticalHeight : appConfig.barHeight
        implicitWidth: isVert ? Math.max(38, appConfig.barHeight) : 1920

        // Зазор над баром и под баром строго равны (по 10px, учитывая gaps_out Hyprland)
        exclusiveZone: isVert ? Math.max(38, appConfig.barHeight) : appConfig.barHeight
        exclusionMode: ExclusionMode.Normal

        Bar {
            id: barView
            anchors.fill: parent
            cfg: appConfig
            onToggleMenu: tab => {
                if (menuWindow.visible && controlMenu.activeTab === tab) menuWindow.closeMenu()
                else menuWindow.openMenu(tab)
            }
            onToggleSidePanel: {
                if (sideWindow.visible) sideWindow.closePanel()
                else sideWindow.openPanel()
            }
            onTriggerOsd: (type, icon, title, val) => osdPopup.trigger(type, icon, title, val)
        }
    }

    // ==========================================
    // 2. OSD ОКНО (ПОЛНОЦЕННОЕ 2D ПОЗИЦИОНИРОВАНИЕ)
    // ==========================================
    PanelWindow {
        id: osdWindow
        screen: Quickshell.screens[1] || Quickshell.screens[0]

        color: "transparent"
        visible: osdPopup.opacity > 0 && !appConfig.isLocked
        WlrLayershell.namespace: "quickshell"

        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: appConfig.osdBottomMargin
            left: appConfig.osdLeftMargin
        }

        implicitWidth: osdPopup.width
        implicitHeight: osdPopup.height
        exclusionMode: ExclusionMode.Normal

        Osd {
            id: osdPopup
            cfg: appConfig
        }
    }

    // ==========================================
    // 3. ПОЛНОЭКРАННАЯ ПРАВАЯ ШТОРКА (SidePanel)
    // ==========================================
    PanelWindow {
        id: sideWindow

        color: "transparent"
        visible: false
        WlrLayershell.namespace: "quickshell"

        anchors {
            top: true
            bottom: true
            right: true
        }
        margins {
            top: 10
            bottom: 10
            right: 10
        }

        implicitWidth: appConfig.sidePanelWidth
        implicitHeight: 1080
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        function openPanel() {
            visible = true
            sidePanel.isOpen = true
            sidePanel.forceActiveFocus()
        }

        function closePanel() {
            sidePanel.isOpen = false
            sideCloseTimer.start()
        }

        Timer {
            id: sideCloseTimer
            interval: 220
            onTriggered: sideWindow.visible = false
        }

        SidePanel {
            id: sidePanel
            anchors.fill: parent
            cfg: appConfig
            onCloseRequested: sideWindow.closePanel()
            onOpenNetworkMenu: tab => menuWindow.openMenu(tab)
            onOpenSettings: settingsOverlay.open()
        }
    }

    // Клик мимо шторки автоматически закрывает её
    HyprlandFocusGrab {
        active: sideWindow.visible
        windows: [sideWindow]
        onCleared: sideWindow.closePanel()
    }

    // ==========================================
    // 4. МЕНЮ СЕТИ (ControlMenu)
    // ==========================================
    PanelWindow {
        id: menuWindow

        color: "transparent"
        visible: false
        WlrLayershell.namespace: "quickshell"

        anchors { top: true; right: true }
        margins {
            top: (appConfig.barPosition === "top") ? appConfig.barHeight + 16 : 16
            right: 16
        }

        implicitWidth: 400
        implicitHeight: 520
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        function openMenu(tab) {
            visible = true
            controlMenu.activeTab = tab
            controlMenu.isOpen = true
            controlMenu.checkHardwareStatus()
            controlMenu.refreshCurrentTab()
            controlMenu.forceActiveFocus()
        }

        function closeMenu() {
            controlMenu.isOpen = false
            closeTimer.start()
        }

        Timer {
            id: closeTimer
            interval: 180
            onTriggered: menuWindow.visible = false
        }

        ControlMenu {
            id: controlMenu
            anchors.fill: parent
            cfg: appConfig
            onCloseRequested: menuWindow.closeMenu()
        }
    }

    // Клик мимо меню сети автоматически закрывает его
    HyprlandFocusGrab {
        active: menuWindow.visible
        windows: [menuWindow]
        onCleared: menuWindow.closeMenu()
    }

    // ==========================================
    // 5. ОКНО НАСТРОЕК (SettingsWindow)
    // ==========================================
    PanelWindow {
        id: settingsOverlay

        color: "transparent"
        visible: false
        WlrLayershell.namespace: "quickshell"

        anchors { top: true; bottom: true; left: true; right: true }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        function open(targetTab) {
            visible = true
            if (targetTab) settingsView.tab = targetTab
            settingsView.forceActiveFocus()
        }

        function close() {
            visible = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: settingsOverlay.close()
        }

        SettingsWindow {
            id: settingsView
            cfg: appConfig
            anchors.centerIn: parent
            onCloseRequested: settingsOverlay.close()
            onRequestWidgetEditor: mode => {
                settingsOverlay.close()
                widgetEditorWin.open(mode)
            }
        }
    }

    // ==========================================
    // 6. WINDOW SWITCHER (ALT + TAB В СТИЛЕ WINDOWS)
    // ==========================================
    PanelWindow {
        id: switcherOverlay

        color: "transparent"
        visible: false
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore

        function openNext() {
            visible = true
            windowSwitcherView.selectNext()
            windowSwitcherView.forceActiveFocus()
        }

        function openPrev() {
            visible = true
            windowSwitcherView.selectPrev()
            windowSwitcherView.forceActiveFocus()
        }

        function commit() {
            if (visible) {
                windowSwitcherView.commit()
            }
        }

        function close() {
            visible = false
        }

        WindowSwitcher {
            id: windowSwitcherView
            anchors.fill: parent
            cfg: appConfig
            onCloseRequested: switcherOverlay.close()
        }
    }

    // ==========================================
    // 7. APPLICATION LAUNCHER (SPOTLIGHT ПОИСК В СТИЛЕ MATERIAL YOU)
    // ==========================================
    PanelWindow {
        id: launcherOverlay

        color: "transparent"
        visible: false
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore

        function toggle() {
            if (visible) close()
            else open()
        }

        function open() {
            visible = true
            launcherView.openLauncher()
        }

        function close() {
            if (!visible) return
            visible = false
            launcherView.closeLauncher()
        }

        AppLauncher {
            id: launcherView
            anchors.fill: parent
            cfg: appConfig
            onCloseRequested: launcherOverlay.close()
        }
    }

    // ==========================================
    // 8. CLIPBOARD MANAGER (БУФЕР ОБМЕНА В СТИЛЕ MATERIAL YOU С ПРЕДПРОСМОТРОМ СКРИНШОТОВ)
    // ==========================================
    PanelWindow {
        id: clipboardOverlay

        color: "transparent"
        visible: false
        WlrLayershell.namespace: "quickshell"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore

        function toggle() {
            if (visible) close()
            else open()
        }

        function open() {
            visible = true
            clipboardView.openClipboard()
        }

        function close() {
            if (!visible) return
            visible = false
            clipboardView.closeClipboard()
        }

        ClipboardManager {
            id: clipboardView
            anchors.fill: parent
            cfg: appConfig
            onCloseRequested: clipboardOverlay.close()
        }
    }

    // ==========================================
    // 9. MATERIAL YOU СИСТЕМА СКРИНШОТОВ (SCREENSHOT OVERLAY)
    // ==========================================
    PanelWindow {
        id: screenshotOverlay

        color: "transparent"
        visible: false
        WlrLayershell.namespace: "screenshot"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore

        function open(screenName) {
            console.log("Screenshot open called, target screenName:", screenName)
            if (Quickshell.screens) {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    console.log("Quickshell screen", i, Quickshell.screens[i].name)
                    if (Quickshell.screens[i].name === screenName) {
                        screenshotOverlay.screen = Quickshell.screens[i]
                    }
                }
            }
            visible = true
            screenshotView.openOverlay()
        }

        function close() {
            visible = false
        }

        ScreenshotOverlay {
            id: screenshotView
            anchors.fill: parent
            cfg: appConfig
            onCloseRequested: screenshotOverlay.close()
        }
    }

    // Прогрев Screencopy бэкенда для мгновенного захвата окон на локскрине
    Loader {
        asynchronous: true
        active: true
        onLoaded: active = false
        sourceComponent: ScreencopyView {
            captureSource: Quickshell.screens[0]
        }
    }

    // ==========================================
    // 8. ЭКРАН БЛОКИРОВКИ (WAYLAND EXT-SESSION-LOCK-V1)
    // ==========================================
    WlSessionLock {
        id: sessionLock
        locked: appConfig.isLocked

        WlSessionLockSurface {
            id: lockSurface
            color: "#121316"

            LockScreen {
                id: lockView
                anchors.fill: parent
                cfg: appConfig
                targetScreen: lockSurface.screen
                isPrimaryScreen: lockSurface.screen === Quickshell.screens[0]
                onUnlockRequested: appConfig.isLocked = false
            }
        }
    }

    // ==========================================
    // 7. АППАРАТНОЕ ЗАТЕМНЕНИЕ ЯРКОСТИ (БЕЗ МЕРЦАНИЯ И ШЕЙДЕРОВ)
    // ==========================================
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dimmerWin
            required property var modelData
            screen: modelData

            color: Qt.rgba(0, 0, 0, (100 - appConfig.currentBrightness) / 100.0 * 0.85)
            visible: appConfig.currentBrightness < 100 && !appConfig.isLocked
            WlrLayershell.namespace: "dimmer"

            anchors { top: true; bottom: true; left: true; right: true }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            mask: Region {}

            Behavior on color { ColorAnimation { duration: 40 } }
        }
    }

    // ==========================================
    // 10. ВИДЖЕТЫ РАБОЧЕГО СТОЛА (DESKTOP WIDGETS)
    // ==========================================
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: desktopWidgetsWin
            required property var modelData
            screen: modelData

            color: "transparent"
            visible: appConfig.showDesktopWidgets && !appConfig.isLocked
            WlrLayershell.namespace: "quickshell-widgets"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Ignore

            anchors { top: true; bottom: true; left: true; right: true }

            DesktopWidgets {
                cfg: appConfig
                currentScreen: desktopWidgetsWin.screen
            }
        }
    }

    // ==========================================
    // 11. ИНТЕРАКТИВНЫЙ РЕДАКТОР ВИДЖЕТОВ И OSD (MULTI-MONITOR)
    // ==========================================
    property bool isWidgetEditorOpen: false
    property string widgetEditorCurrentMode: "widgets"

    function openWidgetEditor(editMode) {
        widgetEditorCurrentMode = editMode || "widgets"
        isWidgetEditorOpen = true
    }

    function closeWidgetEditor() {
        isWidgetEditorOpen = false
    }

    // Proxy для обратной совместимости вызовов widgetEditorWin.open(...) / widgetEditorWin.close()
    QtObject {
        id: widgetEditorWin
        readonly property bool visible: isWidgetEditorOpen
        property alias mode: root.widgetEditorCurrentMode
        function open(editMode) { openWidgetEditor(editMode) }
        function close() { closeWidgetEditor() }
    }

    QtObject {
        id: widgetEditorView
        property alias mode: root.widgetEditorCurrentMode
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: widgetEditorPerScreenWin
            required property var modelData
            screen: modelData

            color: "transparent"
            visible: isWidgetEditorOpen
            WlrLayershell.namespace: "quickshell-editor"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            onVisibleChanged: {
                if (visible) {
                    widgetEditorPerScreenView.openEditor(widgetEditorCurrentMode)
                }
            }

            WidgetEditorOverlay {
                id: widgetEditorPerScreenView
                anchors.fill: parent
                cfg: appConfig
                currentScreen: widgetEditorPerScreenWin.screen
                onCloseRequested: closeWidgetEditor()
            }
        }
    }

    // ==========================================
    // 12. D-BUS СЕРВЕР И ВСПЛЫВАЮЩИЕ УВЕДОМЛЕНИЯ (NOTIFICATIONS)
    // ==========================================
    NotificationServer {
        id: notifServer
    }

    PanelWindow {
        id: notifWindow
        color: "transparent"
        visible: notifPopupView.hasPopups
        WlrLayershell.namespace: "notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }
        margins {
            top: 52
            right: 16
        }

        implicitWidth: notifPopupView.implicitWidth
        implicitHeight: notifPopupView.implicitHeight

        NotificationPopup {
            id: notifPopupView
            cfg: appConfig
            server: notifServer
        }
    }

    // ==========================================
    // 13. ПЛАВАЮЩИЙ ДОК-БАР ПРИЛОЖЕНИЙ (APPLICATION DOCK)
    // ==========================================
    PanelWindow {
        id: dockWindow
        screen: Quickshell.screens[1] || Quickshell.screens[0]

        color: "transparent"
        visible: appConfig.dockEnabled && !appConfig.isLocked
        WlrLayershell.namespace: "quickshell-dock"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: appConfig.dockAutohide ? ExclusionMode.Ignore : ExclusionMode.Normal

        anchors {
            bottom: true
            left: true
            right: true
        }

        implicitHeight: 280

        mask: Region {
            // 1. Если открыто контекстное меню: окно полностью активно (для меню и закрытия по клику мимо)
            Region {
                x: 0
                y: 0
                width: dockView.contextMenuOpen ? dockWindow.width : 0
                height: dockView.contextMenuOpen ? dockWindow.height : 0
            }
            // 2. Интерактивная капсула дока (когда меню закрыто)
            Region {
                item: dockView.contextMenuOpen ? null : dockView.dockCapsuleItem
            }
            // 3. Тонкая полоска (6px) у самого нижнего края для вытягивания спрятанного дока
            Region {
                item: (!dockView.contextMenuOpen && !dockView.dockVisible) ? dockView.triggerItem : null
            }
        }

        Dock {
            id: dockView
            anchors.fill: parent
            cfg: appConfig
            currentScreen: dockWindow.screen
        }
    }
}
