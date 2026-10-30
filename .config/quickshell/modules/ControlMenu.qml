import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    antialiasing: true
    id: root

    required property var cfg
    signal closeRequested()

    property bool isOpen: false
    property string activeTab: "wifi" // "wifi", "eth", "bt"

    // Статусы модулей
    property bool wifiEnabled: true
    property bool ethEnabled: true
    property bool btEnabled: true

    readonly property bool isCurrentEnabled: {
        if (activeTab === "wifi") return wifiEnabled
        if (activeTab === "eth") return ethEnabled
        if (activeTab === "bt") return btEnabled
        return false
    }

    // Данные Ethernet
    property string ethDev: "..."
    property string ethState: "disconnected"
    property string ethIp: "..."
    property string ethGateway: "..."
    property string ethSpeed: "..."

    // Списки сетей и устройств
    property var wifiList: []
    property var btList: []
    property bool isRefreshing: false

    implicitWidth: 400
    implicitHeight: 520
    width: implicitWidth
    height: implicitHeight
    radius: 32
    color: root.cfg.bgSurface
    border.color: root.cfg.borderCol
    border.width: 1
    clip: true

    opacity: isOpen ? 1 : 0
    scale: isOpen ? 1 : 0.94

    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    focus: true
    Keys.onEscapePressed: root.closeRequested()
    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    Timer {
        id: scanTimeoutTimer
        interval: 3500
        repeat: false
        onTriggered: root.isRefreshing = false
    }

    // Фоновый таймер для подгрузки обновленного списка после фонового рескана
    Timer {
        id: postRescanTimer
        interval: 2200
        repeat: false
        onTriggered: {
            if (root.activeTab === "wifi") {
                wifiQuickListProc.exec(["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null"])
            }
        }
    }

    function checkHardwareStatus() {
        wifiCheckProc.exec(["sh", "-c", "nmcli radio wifi 2>/dev/null || echo 'enabled'"])
        btCheckProc.exec(["sh", "-c", "timeout 1 bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}' || echo 'no'"])
        refreshCurrentTab()
    }

    function refreshCurrentTab() {
        if (!root.isCurrentEnabled && root.activeTab !== "eth") {
            root.isRefreshing = false
            return
        }

        root.isRefreshing = true
        scanTimeoutTimer.restart()

        if (root.activeTab === "wifi") {
            // Мгновенно читаем кеш (0.05 сек), запуская rescan в фоне!
            wifiQuickListProc.exec(["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null; nmcli dev wifi rescan 2>/dev/null &"])
            postRescanTimer.restart()
        } else if (root.activeTab === "bt") {
            btScanProc.exec([
                "sh", "-c",
                "timeout 1.5 bluetoothctl devices 2>/dev/null | cut -d ' ' -f 3- | head -n 14"
            ])
        } else if (root.activeTab === "eth") {
            ethInfoProc.exec([
                "sh", "-c",
                "ETH=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2==\"ethernet\"{print $1; exit}'); " +
                "if [ -z \"$ETH\" ]; then ETH=$(ip -o link show 2>/dev/null | awk -F': ' '$2 ~ /^(en|eth)/{print $2; exit}'); fi; " +
                "if [ -n \"$ETH\" ]; then " +
                "  STATE=$(nmcli -t -f DEVICE,STATE dev 2>/dev/null | awk -F: -v dev=\"$ETH\" '$1==dev{print $2}'); " +
                "  IP=$(ip -4 -o addr show dev \"$ETH\" 2>/dev/null | awk '{print $4}'); " +
                "  GW=$(ip route 2>/dev/null | awk \"/default/ && /dev $ETH/ {print \\$3; exit}\"); " +
                "  SPEED=$(cat /sys/class/net/\"$ETH\"/speed 2>/dev/null); " +
                "  echo \"$ETH|$STATE|$IP|$GW|$SPEED\"; " +
                "else echo \"none|disconnected|||\"; fi"
            ])
        }
    }

    onActiveTabChanged: refreshCurrentTab()

    Process {
        id: wifiCheckProc
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = (text.trim() === "enabled")
        }
    }

    Process {
        id: btCheckProc
        stdout: StdioCollector {
            onStreamFinished: root.btEnabled = (text.trim() === "yes")
        }
    }

    Process {
        id: wifiQuickListProc
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                let parsed = []
                let seen = {}
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (!line) continue
                    let parts = line.split(":")
                    if (parts.length >= 2) {
                        let inUse = parts[0].trim() === "*"
                        let ssid = parts[1].trim()
                        let signal = parts.length >= 3 ? parseInt(parts[2]) || 50 : 50
                        if (ssid.length > 0 && !seen[ssid]) {
                            seen[ssid] = true
                            parsed.push({ active: inUse, ssid: ssid, signal: signal })
                        }
                    }
                }
                if (parsed.length > 0) root.wifiList = parsed
                root.isRefreshing = false
                scanTimeoutTimer.stop()
            }
        }
    }

    Process {
        id: btScanProc
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n")
                let parsed = []
                for (let i = 0; i < lines.length; i++) {
                    let name = lines[i].trim()
                    if (name.length > 0) parsed.push(name)
                }
                root.btList = parsed
                root.isRefreshing = false
                scanTimeoutTimer.stop()
            }
        }
    }

    Process {
        id: ethInfoProc
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split("|")
                if (parts.length >= 5) {
                    root.ethDev = parts[0]
                    root.ethState = parts[1]
                    root.ethEnabled = (parts[1] === "connected")
                    root.ethIp = parts[2] ? parts[2] : "Не назначен"
                    root.ethGateway = parts[3] ? parts[3] : "—"
                    root.ethSpeed = (parts[4] && parts[4] !== "") ? parts[4] + " Мбит/с" : "—"
                }
                root.isRefreshing = false
                scanTimeoutTimer.stop()
            }
        }
    }

    Process {
        id: wifiToggleProc
        onExited: (code, status) => wifiToggleTimer.restart()
    }

    Timer {
        id: wifiToggleTimer
        interval: 400
        onTriggered: {
            if (root.wifiEnabled) root.refreshCurrentTab()
            else root.wifiList = []
        }
    }

    Process {
        id: btToggleProc
        onExited: (code, status) => btToggleTimer.restart()
    }

    Timer {
        id: btToggleTimer
        interval: 400
        onTriggered: {
            if (root.btEnabled) root.refreshCurrentTab()
            else root.btList = []
        }
    }

    Process {
        id: ethToggleProc
        onExited: (code, status) => root.refreshCurrentTab()
    }

    Process { id: actionProc }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ================= 1. ШАПКА =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                antialiasing: true
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 19
                color: root.cfg.accentContainer

                Text {
                    anchors.centerIn: parent
                    text: root.activeTab === "wifi" ? "󰤨" : (root.activeTab === "eth" ? "󰈀" : "󰂯")
                    color: root.cfg.accent
                    font.pixelSize: 18
                }
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                Text {
                    text: root.activeTab === "wifi" ? "Беспроводная связь" : (root.activeTab === "eth" ? "Проводное подключение" : "Bluetooth устройства")
                    color: root.cfg.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: root.isCurrentEnabled ? "Интерфейс активен" : "Отключен"
                    color: root.isCurrentEnabled ? root.cfg.accent : root.cfg.textMuted
                    font.pixelSize: 10
                }
            }

            Rectangle {
                antialiasing: true
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: closeM.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                scale: closeM.pressed ? 0.92 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                Text { anchors.centerIn: parent; text: "󰅖"; color: root.cfg.textMuted; font.pixelSize: 15 }
                MouseArea {
                    id: closeM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ================= 2. СЕГМЕНТИРОВАННЫЙ M3 СЕЛЕКТОР ВКЛАДОК =================
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 22
            color: root.cfg.bgPrimary

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 4

                Repeater {
                    model: [
                        { id: "wifi", icon: "󰤨", label: "Wi-Fi" },
                        { id: "eth", icon: "󰈀", label: "Ethernet" },
                        { id: "bt", icon: "󰂯", label: "Bluetooth" }
                    ]

                    Rectangle {
                        antialiasing: true
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 19
                        color: root.activeTab === modelData.id ? root.cfg.accent : "transparent"
                        scale: tabMouse.pressed ? 0.95 : 1.0
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: modelData.icon
                                color: root.activeTab === modelData.id ? root.cfg.accentText : root.cfg.textMuted
                                font.pixelSize: 14
                            }
                            Text {
                                text: modelData.label
                                color: root.activeTab === modelData.id ? root.cfg.accentText : root.cfg.textPrimary
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = modelData.id
                                root.refreshCurrentTab()
                            }
                        }
                    }
                }
            }
        }

        // ================= 3. MASTER ПЕРЕКЛЮЧАТЕЛЬ =================
        Rectangle {
            antialiasing: true
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 20
            color: root.isCurrentEnabled ? root.cfg.accentContainer : root.cfg.bgPrimary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                ColumnLayout {
                    spacing: 1
                    Text {
                        text: root.activeTab === "wifi" ? "Питание Wi-Fi" : (root.activeTab === "eth" ? "Интерфейс " + root.ethDev : "Питание Bluetooth")
                        color: root.cfg.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        text: root.isCurrentEnabled ? "Включено" : "Выключено"
                        color: root.isCurrentEnabled ? root.cfg.accent : root.cfg.textMuted
                        font.pixelSize: 10
                    }
                }

                Item { Layout.fillWidth: true }

                // M3 Switch
                Rectangle {
                    antialiasing: true
                    width: 48
                    height: 26
                    radius: 13
                    color: root.isCurrentEnabled ? root.cfg.accent : root.cfg.bgElevated
                    Behavior on color { ColorAnimation { duration: 180 } }

                    Rectangle {
                        antialiasing: true
                        width: 20
                        height: 20
                        radius: 10
                        color: root.isCurrentEnabled ? root.cfg.accentText : "#ffffff"
                        y: 3
                        x: root.isCurrentEnabled ? 25 : 3
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activeTab === "wifi") {
                                root.wifiEnabled = !root.wifiEnabled
                                wifiToggleProc.exec(["nmcli", "radio", "wifi", root.wifiEnabled ? "on" : "off"])
                            } else if (root.activeTab === "eth") {
                                root.ethEnabled = !root.ethEnabled
                                ethToggleProc.exec(["sh", "-c", root.ethEnabled ? "nmcli device connect " + root.ethDev : "nmcli device disconnect " + root.ethDev])
                            } else if (root.activeTab === "bt") {
                                root.btEnabled = !root.btEnabled
                                btToggleProc.exec(["bluetoothctl", "power", root.btEnabled ? "on" : "off"])
                            }
                        }
                    }
                }
            }
        }

        // ================= 4. КОНТЕНТ СЕТЕЙ / УСТРОЙСТВ =================
        // А) Ethernet
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeTab === "eth"
            spacing: 8

            Rectangle {
                antialiasing: true
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 20
                color: root.cfg.bgPrimary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Text { text: "IPv4 адрес:"; color: root.cfg.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                        Text { text: root.ethIp; color: root.cfg.textPrimary; font.pixelSize: 12; font.bold: true }
                    }

                    RowLayout {
                        Text { text: "Основной шлюз:"; color: root.cfg.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                        Text { text: root.ethGateway; color: root.cfg.textPrimary; font.pixelSize: 11 }
                    }

                    RowLayout {
                        Text { text: "Скорость соединения:"; color: root.cfg.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                        Text { text: root.ethSpeed; color: root.cfg.accent; font.pixelSize: 12; font.bold: true }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        antialiasing: true
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 21
                        color: reconnectMouse.containsMouse ? root.cfg.accent : root.cfg.bgElevated
                        scale: reconnectMouse.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐  Переподключить интерфейс"
                            color: reconnectMouse.containsMouse ? root.cfg.accentText : root.cfg.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: reconnectMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actionProc.exec(["sh", "-c", "nmcli device reapply " + root.ethDev + " 2>/dev/null || nmcli device connect " + root.ethDev])
                                root.refreshCurrentTab()
                            }
                        }
                    }
                }
            }
        }

        // Б) Списки Wi-Fi и Bluetooth
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeTab !== "eth"
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.activeTab === "wifi" ? "Доступные сети" : "Устройства"
                    color: root.cfg.textMuted
                    font.pixelSize: 11
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    antialiasing: true
                    width: 30
                    height: 30
                    radius: 15
                    color: refreshMouse.containsMouse ? root.cfg.bgElevated : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: root.isRefreshing ? root.cfg.accent : root.cfg.textMuted
                        font.pixelSize: 15
                        rotation: root.isRefreshing ? 360 : 0
                        Behavior on rotation { NumberAnimation { duration: 600 } }
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshCurrentTab()
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6

                model: {
                    if (root.activeTab === "wifi") {
                        if (!root.wifiEnabled) return ["Беспроводная сеть отключена"]
                        return root.wifiList.length > 0 ? root.wifiList : (root.isRefreshing ? ["Поиск сетей..."] : ["Сети не найдены"])
                    } else {
                        if (!root.btEnabled) return ["Bluetooth адаптер отключен"]
                        return root.btList.length > 0 ? root.btList : (root.isRefreshing ? ["Поиск устройств..."] : ["Нет устройств"])
                    }
                }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 50
                    radius: 16
                    color: itemMouse.containsMouse ? root.cfg.bgElevated : root.cfg.bgPrimary
                    scale: itemMouse.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    readonly property bool isString: typeof modelData === "string"
                    readonly property string itemName: isString ? modelData : modelData.ssid
                    readonly property bool isConnected: !isString && modelData.active
                    readonly property int sig: !isString && modelData.signal ? modelData.signal : 50

                    readonly property string sigIcon: {
                        if (sig > 75) return "󰤨"
                        if (sig > 50) return "󰤥"
                        if (sig > 25) return "󰤢"
                        return "󰤟"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Rectangle {
                            antialiasing: true
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 17
                            color: isConnected ? root.cfg.accentContainer : root.cfg.bgElevated

                            Text {
                                anchors.centerIn: parent
                                text: root.activeTab === "wifi" ? (isConnected ? "󰤨" : sigIcon) : "󰂱"
                                color: isConnected ? root.cfg.accent : root.cfg.textMuted
                                font.pixelSize: 16
                            }
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true

                            Text {
                                text: itemName
                                color: isConnected ? root.cfg.accent : root.cfg.textPrimary
                                font.pixelSize: 12
                                font.bold: isConnected
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: !isString
                                text: isConnected ? "Подключено • Отличный сигнал" : sig + "% сигнал"
                                color: isConnected ? root.cfg.accent : root.cfg.textMuted
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            antialiasing: true
                            visible: isConnected || (itemMouse.containsMouse && !isString)
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 26
                            radius: 13
                            color: isConnected ? root.cfg.accent : root.cfg.accentContainer

                            Text {
                                anchors.centerIn: parent
                                text: isConnected ? "✓ Активно" : "Подключить"
                                color: isConnected ? root.cfg.accentText : root.cfg.accent
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: isString ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (isString) return
                            if (root.activeTab === "wifi") {
                                actionProc.exec(["nmcli", "dev", "wifi", "connect", modelData.ssid])
                            } else {
                                actionProc.exec(["sh", "-c", "bluetoothctl connect $(bluetoothctl devices 2>/dev/null | grep -m1 '" + modelData + "' | awk '{print $2}')"])
                            }
                        }
                    }
                }
            }
        }
    }
}
