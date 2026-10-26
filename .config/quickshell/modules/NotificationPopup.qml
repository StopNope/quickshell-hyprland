import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Item {
    id: root

    required property var cfg
    required property var server

    readonly property bool hasPopups: toastsModel.count > 0
    implicitWidth: 360
    implicitHeight: toastCol.implicitHeight

    ListModel {
        id: toastsModel
    }

    Connections {
        target: root.server
        function onNotification(notif) {
            root.handleNotification(notif)
        }
    }

    Connections {
        target: root.cfg
        function onDndModeChanged() {
            if (root.cfg.dndMode) {
                toastsModel.clear()
            }
        }
    }

    function handleNotification(notif) {
        if (!notif) return

        let app = notif.appName || "Приложение"
        let sum = notif.summary || "Уведомление"
        let bod = notif.body || ""
        let icon = notif.appIcon || ""
        let timeout = (notif.expireTimeout > 0) ? notif.expireTimeout : 5000

        // 1. Сохраняем в историю боковой панели (SidePanel)
        root.cfg.pushNotification(sum, bod, app, icon)

        // 2. Если включен режим «Не беспокоить», всплывающие окна не показываем
        if (root.cfg.dndMode) return

        // 2. Проверяем, существует ли уже тост с таким ID (обновление)
        for (let i = 0; i < toastsModel.count; i++) {
            if (toastsModel.get(i).notifId === notif.id) {
                toastsModel.setProperty(i, "summary", sum)
                toastsModel.setProperty(i, "body", bod)
                toastsModel.setProperty(i, "app", app)
                toastsModel.setProperty(i, "icon", icon)
                toastsModel.setProperty(i, "time", Qt.formatDateTime(new Date(), "hh:mm"))
                return
            }
        }

        // Если больше 4 тостов, убираем самый старый
        if (toastsModel.count >= 4) {
            toastsModel.remove(0)
        }

        // Добавляем новый тост
        toastsModel.append({
            notifId: notif.id,
            app: app,
            summary: sum,
            body: bod,
            icon: icon,
            time: Qt.formatDateTime(new Date(), "hh:mm"),
            timeoutMs: timeout,
            rawNotif: notif
        })
    }

    function removeToast(notifId) {
        for (let i = 0; i < toastsModel.count; i++) {
            if (toastsModel.get(i).notifId === notifId) {
                toastsModel.remove(i)
                break
            }
        }
    }

    // Вспомогательный определитель иконок приложений
    function getAppGlyph(app) {
        if (!app) return "󰂚"
        let a = app.toLowerCase()
        if (a.includes("telegram")) return "󰒱"
        if (a.includes("discord") || a.includes("vesktop") || a.includes("webcord")) return "󰙯"
        if (a.includes("firefox") || a.includes("chrome") || a.includes("chromium") || a.includes("brave") || a.includes("browser")) return "󰈹"
        if (a.includes("spotify")) return "󰓇"
        if (a.includes("steam")) return "󰓓"
        if (a.includes("term") || a.includes("kitty") || a.includes("alacritty") || a.includes("foot")) return "󰞷"
        if (a.includes("screen") || a.includes("grim") || a.includes("slurp")) return "󰄄"
        if (a.includes("hypr") || a.includes("system") || a.includes("система")) return "󰍛"
        if (a.includes("volume") || a.includes("audio") || a.includes("звук")) return "󰕾"
        return "󰂚"
    }

    function resolveIconUrl(icon, app) {
        if (icon) {
            let s = icon.toString()
            if (s.startsWith("image://") || s.startsWith("file://")) return s
            if (s.startsWith("/")) return "file://" + s
            let p = Quickshell.iconPath(s)
            if (p) return "file://" + p
            return "image://icon/" + s
        }
        if (app) {
            let p = Quickshell.iconPath(app.toLowerCase())
            if (p) return "file://" + p
        }
        return ""
    }

    ColumnLayout {
        id: toastCol
        width: 360
        spacing: 8

        Repeater {
            model: toastsModel

            delegate: Rectangle {
                id: toastCard
                Layout.fillWidth: true
                implicitHeight: cardInnerLayout.implicitHeight + 24
                radius: 20
                color: root.cfg.surfaceContainer
                border.color: root.cfg.outlineVariant
                border.width: 1
                clip: true

                property bool isDismissing: false
                property real animX: 80
                property real animOpacity: 0

                transform: Translate {
                    x: toastCard.animX
                }
                opacity: toastCard.animOpacity

                Component.onCompleted: {
                    animX = 0
                    animOpacity = 1.0
                }

                Behavior on animX {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on animOpacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                function dismiss() {
                    if (isDismissing) return
                    isDismissing = true
                    animX = 100
                    animOpacity = 0
                    if (model.rawNotif) {
                        try { model.rawNotif.dismiss() } catch(e) {}
                    }
                    dismissTimer.start()
                }

                Timer {
                    id: dismissTimer
                    interval: 220
                    onTriggered: root.removeToast(model.notifId)
                }

                // Таймер авто-закрытия (ставится на паузу при наведении мыши)
                Timer {
                    id: autoCloseTimer
                    interval: Math.max(3000, model.timeoutMs || 5000)
                    running: !toastMouse.containsMouse && !toastCard.isDismissing
                    onTriggered: toastCard.dismiss()
                }

                // Индикатор оставшегося времени (мягкая линия внизу)
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    height: 2
                    color: root.cfg.accent
                    opacity: 0.6
                    width: autoCloseTimer.running ? 0 : parent.width

                    Behavior on width {
                        enabled: autoCloseTimer.running
                        NumberAnimation { duration: Math.max(3000, model.timeoutMs || 5000); easing.type: Easing.Linear }
                    }
                }

                ColumnLayout {
                    id: cardInnerLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // 1. Верхний ряд: Иконка приложения + Название + Время + Кнопка закрытия
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                            border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                            border.width: 1

                            Image {
                                id: appImg
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: root.resolveIconUrl(model.icon, model.app)
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !appImg.visible
                                text: root.getAppGlyph(model.app)
                                color: root.cfg.accent
                                font.pixelSize: 13
                            }
                        }

                        Text {
                            text: model.app
                            color: root.cfg.accent
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.cfg.fontFamily
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: model.time
                            color: root.cfg.onSurfaceVariant
                            font.pixelSize: 10
                            font.family: root.cfg.fontFamily
                        }

                        // Кнопка закрытия карточки
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: closeMouse.containsMouse ? root.cfg.surfaceContainerHigh : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: closeMouse.containsMouse ? root.cfg.textPrimary : root.cfg.onSurfaceVariant
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toastCard.dismiss()
                            }
                        }
                    }

                    // 2. Заголовок уведомления
                    Text {
                        text: model.summary
                        color: root.cfg.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                        font.family: root.cfg.fontFamily
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    // 3. Тело сообщения
                    Text {
                        visible: model.body !== ""
                        text: model.body
                        color: root.cfg.onSurfaceVariant
                        font.pixelSize: 11
                        font.family: root.cfg.fontFamily
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }

                    // 4. Кнопки действий (Actions)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: model.rawNotif && model.rawNotif.actions && model.rawNotif.actions.length > 0
                        spacing: 8

                        Repeater {
                            model: (model.rawNotif && model.rawNotif.actions) ? model.rawNotif.actions : []

                            delegate: Rectangle {
                                required property var modelData
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: actionTxt.implicitWidth + 20
                                radius: 14
                                color: actMouse.containsMouse ? root.cfg.primaryContainer : Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)
                                border.width: 1

                                Text {
                                    id: actionTxt
                                    anchors.centerIn: parent
                                    text: modelData.text || "Действие"
                                    color: root.cfg.accent
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: root.cfg.fontFamily
                                }

                                MouseArea {
                                    id: actMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        try { modelData.invoke() } catch(e) {}
                                        toastCard.dismiss()
                                    }
                                }
                            }
                        }
                    }
                }

                // Интерактивная зона карточки (клик для скрытия/фокуса)
                MouseArea {
                    id: toastMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                    onClicked: toastCard.dismiss()
                }
            }
        }
    }
}
