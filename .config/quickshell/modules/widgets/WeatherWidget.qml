import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    required property var cfg
    property var widgetData: ({})

    readonly property string variant: (widgetData && widgetData.variant) ? widgetData.variant : "forecast"
    readonly property string size: (widgetData && widgetData.size) ? widgetData.size : "M"

    // Метео-свойства Material You
    readonly property string displayTemp: {
        let raw = root.cfg.weatherText || "12°"
        let clean = raw.replace("+", "").replace("C", "").trim()
        return clean.endsWith("°") ? clean : clean + "°"
    }
    readonly property int currentTempNum: {
        let n = parseInt(displayTemp)
        return isNaN(n) ? 12 : n
    }
    readonly property string displayCity: root.cfg.weatherCity || "Тюмень"
    readonly property string displayDesc: root.cfg.weatherDesc || "Ясно"
    readonly property string displayFeelsLike: {
        let fl = root.cfg.weatherFeelsLike || root.cfg.weatherText || "11°"
        let clean = fl.replace("+", "").replace("C", "").trim()
        return clean.endsWith("°") ? clean : clean + "°"
    }
    readonly property string displayHumidity: root.cfg.weatherHumidity || "46%"
    readonly property string displayWind: root.cfg.weatherWind || "9 км/ч"
    readonly property string displayPrecip: root.cfg.weatherPrecip || "0%"

    readonly property var forecastDays: {
        let now = new Date()
        let dayNames = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        let res = []
        for (let i = 0; i < 3; i++) {
            let d = new Date(now.getTime() + i * 24 * 3600 * 1000)
            let name = (i === 0) ? "Сегодня" : dayNames[d.getDay()]
            res.push(name)
        }
        return res
    }

    radius: (widgetData && widgetData.radius !== undefined) ? widgetData.radius : (root.cfg.widgetRadius || 28)
    color: (widgetData && widgetData.transparentBg) || root.variant === "pebble" ? "transparent" : root.cfg.surfaceContainer
    border.color: (widgetData && widgetData.transparentBg) || root.variant === "pebble" ? "transparent" : root.cfg.outlineVariant
    border.width: (widgetData && widgetData.transparentBg) || root.variant === "pebble" ? 0 : 1
    clip: false

    // ==========================================
    // ВАРИАНТ 0: PIXEL ORGANIC PEBBLE (100% АУТЕНТИЧНЫЙ GOOGLE PIXEL ИЗ РЕФЕРЕНСА)
    // ==========================================
    readonly property bool isPastel: (widgetData && widgetData.pastelTheme !== undefined) ? widgetData.pastelTheme : true
    readonly property color pebbleBg: {
        if (root.isPastel) return "#d2dfeb"
        return (root.cfg.accentContainer && root.cfg.accentContainer !== "transparent")
               ? root.cfg.accentContainer
               : "#294154"
    }
    readonly property color pebbleTextColor: {
        if (root.isPastel) return "#055c86"
        return root.cfg.textPrimary
    }

    // Точные 72 нормализованные точки контура органического камушка Google Pixel
    readonly property var pebbleContour: [
        [0.9934,0.5000], [0.9850,0.5424], [0.9709,0.5830], [0.9534,0.6215],
        [0.9329,0.6576], [0.9096,0.6910], [0.8838,0.7216], [0.8559,0.7492],
        [0.8295,0.7765], [0.8041,0.8041], [0.7765,0.8295], [0.7492,0.8559],
        [0.7216,0.8838], [0.6910,0.9096], [0.6576,0.9329], [0.6215,0.9534],
        [0.5830,0.9709], [0.5424,0.9850], [0.5000,0.9934], [0.4562,1.0003],
        [0.4117,1.0010], [0.3672,0.9956], [0.3230,0.9863], [0.2795,0.9729],
        [0.2369,0.9557], [0.1969,0.9328], [0.1590,0.9064], [0.1264,0.8736],
        [0.0936,0.8410], [0.0672,0.8031], [0.0462,0.7620], [0.0271,0.7205],
        [0.0137,0.6770], [0.0044,0.6328], [-0.0010,0.5883], [-0.0003,0.5438],
        [0.0066,0.5000], [0.0150,0.4576], [0.0291,0.4170], [0.0466,0.3785],
        [0.0671,0.3424], [0.0904,0.3090], [0.1162,0.2784], [0.1441,0.2508],
        [0.1705,0.2235], [0.1959,0.1959], [0.2235,0.1705], [0.2508,0.1441],
        [0.2784,0.1162], [0.3090,0.0904], [0.3424,0.0671], [0.3785,0.0466],
        [0.4170,0.0291], [0.4576,0.0150], [0.5000,0.0066], [0.5436,0.0019],
        [0.5883,-0.0010], [0.6328,0.0044], [0.6770,0.0137], [0.7205,0.0271],
        [0.7620,0.0462], [0.8031,0.0672], [0.8396,0.0952], [0.8736,0.1264],
        [0.9048,0.1604], [0.9328,0.1969], [0.9538,0.2380], [0.9729,0.2795],
        [0.9863,0.3230], [0.9956,0.3672], [1.0010,0.4117], [1.0003,0.4562]
    ]

    Item {
        id: pebbleWeatherItem
        anchors.fill: parent
        visible: root.variant === "pebble"

        readonly property real pebbleSize: Math.min(parent.width - 8, parent.height - 8)

        // 1. Органический контур камушка Google Pixel
        Canvas {
            id: pebbleCanvas
            anchors.centerIn: parent
            width: pebbleWeatherItem.pebbleSize
            height: pebbleWeatherItem.pebbleSize

            property color bgCol: root.pebbleBg
            onBgColChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            Connections {
                target: pebbleWeatherItem
                function onVisibleChanged() {
                    if (pebbleWeatherItem.visible) pebbleCanvas.requestPaint()
                }
            }

            onPaint: {
                let ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                let pts = root.pebbleContour
                if (!pts || pts.length === 0) return

                ctx.beginPath()
                ctx.moveTo(pts[0][0] * width, pts[0][1] * height)
                for (let i = 1; i < pts.length; i++) {
                    ctx.lineTo(pts[i][0] * width, pts[i][1] * height)
                }
                ctx.closePath()
                ctx.fillStyle = bgCol
                ctx.fill()

                ctx.strokeStyle = root.isPastel ? Qt.rgba(0.02, 0.36, 0.52, 0.18) : root.cfg.outlineVariant
                ctx.lineWidth = 1.5
                ctx.stroke()
            }
        }

        // 2. Элементы виджета строго в пропорциях референса
        Item {
            anchors.centerIn: parent
            width: pebbleWeatherItem.pebbleSize
            height: pebbleWeatherItem.pebbleSize

            // 1) ТЕКСТ ТЕМПЕРАТУРЫ (вверху справа, рисуется ПЕРВЫМ)
            Text {
                x: Math.round(parent.width * 0.61 - width / 2)
                y: Math.round(parent.height * 0.33 - height / 2)
                text: root.displayTemp
                color: root.pebbleTextColor
                font.pixelSize: Math.round(parent.width * 0.39)
                font.bold: true
                font.family: "Noto Sans"
            }

            // 2) ЗОЛОТОЕ СОЛНЦЕ GOOGLE PIXEL (внизу слева, рисуется ПОВЕРХ текста)
            Rectangle {
                x: Math.round(parent.width * 0.36 - width / 2)
                y: Math.round(parent.height * 0.65 - height / 2)
                width: Math.round(parent.width * 0.33)
                height: width
                radius: width / 2
                color: "#ecb40f"
                antialiasing: true
            }
        }

        // Переключение темы (светлый Pixel Pastel #d2dfeb vs системный Monet) по клику
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (widgetData) {
                    widgetData.pastelTheme = !root.isPastel
                    root.cfg.save()
                    pebbleCanvas.requestPaint()
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 1: GOOGLE PIXEL WEATHER CARD (ИЗ РЕФЕРЕНСОВ MATERIAL YOU & POCKET-LINT)
    // ==========================================
    Item {
        id: pixelWeatherCardItem
        anchors.fill: parent
        anchors.margins: 14
        visible: root.variant === "forecast" || root.variant === "pixel_card"

        RowLayout {
            anchors.fill: parent
            spacing: 12

            // ЛЕВАЯ КОЛОНКА (~48% ширины): Город + Температура с Солнцем + 3-дневный прогноз
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 48
                spacing: 4

                // 1. Название города
                Text {
                    text: root.displayCity
                    color: root.cfg.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: root.cfg.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // 2. Крупная температура + Золотистый солнечный диск
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.displayTemp
                        color: root.cfg.textPrimary
                        font.pixelSize: Math.max(30, Math.min(Math.round(root.height * 0.26), 40))
                        font.bold: true
                        font.family: "Fredoka"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Золотистый диск солнца Google Pixel
                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignVCenter
                        radius: 17
                        color: "#fbc02d"

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 4
                            width: 12
                            height: 12
                            radius: 6
                            color: Qt.rgba(255, 255, 255, 0.45)
                        }

                        // Облачко, если пасмурно
                        Item {
                            anchors.fill: parent
                            visible: root.displayDesc.toLowerCase().indexOf("облач") !== -1 || root.displayDesc.toLowerCase().indexOf("пасмур") !== -1

                            Rectangle {
                                x: 10; y: 12; width: 24; height: 16; radius: 8
                                color: "#ffffff"
                            }
                            Rectangle {
                                x: 14; y: 6; width: 16; height: 16; radius: 8
                                color: "#ffffff"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.fillHeight: true }

                // 3. 3-дневный прогноз (Пн  +8° +15°)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: [
                            { day: root.forecastDays[0], low: (root.currentTempNum - 3) + "°", high: (root.currentTempNum + 3) + "°" },
                            { day: root.forecastDays[1], low: (root.currentTempNum - 5) + "°", high: (root.currentTempNum + 2) + "°" },
                            { day: root.forecastDays[2], low: (root.currentTempNum - 4) + "°", high: (root.currentTempNum + 4) + "°" }
                        ]

                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.day
                                color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                                font.pixelSize: 10
                                font.family: root.cfg.fontFamily
                                Layout.preferredWidth: 44
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: modelData.low + "  " + modelData.high
                                color: root.cfg.textPrimary
                                font.pixelSize: 10
                                font.bold: true
                                font.family: root.cfg.fontFamily
                            }
                        }
                    }
                }
            }

            // ТОНКИЙ ВЕРТИКАЛЬНЫЙ РАЗДЕЛИТЕЛЬ M3
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                color: root.cfg.outlineVariant
                opacity: 0.45
            }

            // ПРАВАЯ КОЛОНКА (~52% ширины): Состояние и подробные метеоданные
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 52
                spacing: 3

                // Состояние погоды ("Sunny" / "Ясно")
                Text {
                    text: root.displayDesc
                    color: root.cfg.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: root.cfg.fontFamily
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }

                // Подробный список показателей как на референсе
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    // Feels like
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Ощущается:"
                            color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                            font.pixelSize: 10
                            font.family: root.cfg.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.displayFeelsLike
                            color: root.cfg.textPrimary
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }

                    // Low / High
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Мин / Макс:"
                            color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                            font.pixelSize: 10
                            font.family: root.cfg.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (root.currentTempNum - 4) + "° / " + (root.currentTempNum + 4) + "°"
                            color: root.cfg.textPrimary
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }

                    // Precipitation
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Осадки:"
                            color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                            font.pixelSize: 10
                            font.family: root.cfg.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.displayPrecip
                            color: root.cfg.textPrimary
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }

                    // Humidity
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Влажность:"
                            color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                            font.pixelSize: 10
                            font.family: root.cfg.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.displayHumidity
                            color: root.cfg.textPrimary
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }

                    // Wind
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Ветер:"
                            color: root.cfg.onSurfaceVariant || root.cfg.textMuted
                            font.pixelSize: 10
                            font.family: root.cfg.fontFamily
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.displayWind
                            color: root.cfg.textPrimary
                            font.pixelSize: 10
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 1.5: PIXEL WEATHER PILL (АТ-Э-ГЛАНС ПИЛЮЛЯ)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        visible: root.variant === "pill"

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: 22
            color: root.cfg.accentContainer || Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)

            Text {
                anchors.centerIn: parent
                text: "󰖐"
                color: root.cfg.accent
                font.pixelSize: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.cfg.weatherText || "12°"
                color: root.cfg.textPrimary
                font.pixelSize: 22
                font.bold: true
                font.family: "Fredoka"
            }

            Text {
                text: (root.cfg.weatherCity || "Тюмень") + " · Облачно"
                color: root.cfg.textMuted
                font.pixelSize: 11
                font.family: root.cfg.fontFamily
                elide: Text.ElideRight
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 2: COMPACT (МИНИМАЛИСТИЧНЫЙ ВИДЖЕТ)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14
        visible: root.variant === "compact"

        Rectangle {
            Layout.preferredWidth: root.size === "S" ? 44 : 54
            Layout.preferredHeight: Layout.preferredWidth
            radius: Layout.preferredWidth / 2
            color: root.cfg.primaryContainer

            Text {
                anchors.centerIn: parent
                text: "󰖐"
                color: root.cfg.onPrimaryContainer
                font.pixelSize: root.size === "S" ? 24 : 30
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: root.cfg.weatherText
                color: root.cfg.textPrimary
                font.pixelSize: root.size === "S" ? 28 : (root.size === "L" ? 44 : 34)
                font.bold: true
                font.family: root.cfg.fontFamily
            }

            Rectangle {
                height: 22
                width: cityCompactText.implicitWidth + 14
                radius: 11
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)
                border.width: 1

                Text {
                    id: cityCompactText
                    anchors.centerIn: parent
                    text: root.cfg.weatherCity || "Тюмень"
                    color: root.cfg.accent
                    font.pixelSize: 10
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 3: DETAILED (ПОЛНАЯ МЕТЕОСВОДКА С ДАТЧИКАМИ)
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.size === "S" ? 12 : 16
        spacing: 8
        visible: root.variant === "detailed"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                radius: 16
                color: root.cfg.primaryContainer

                Text {
                    anchors.centerIn: parent
                    text: "󰖐"
                    color: root.cfg.onPrimaryContainer
                    font.pixelSize: 26
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    spacing: 8
                    Text {
                        text: root.cfg.weatherText
                        color: root.cfg.textPrimary
                        font.pixelSize: 26
                        font.bold: true
                        font.family: root.cfg.fontFamily
                    }

                    Rectangle {
                        height: 20
                        implicitWidth: detCityTxt.implicitWidth + 12
                        radius: 10
                        color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                        border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                        border.width: 1
                        Text {
                            id: detCityTxt
                            anchors.centerIn: parent
                            text: root.cfg.weatherCity || "Тюмень"
                            color: root.cfg.accent
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }

                Text {
                    text: (root.cfg.weatherDesc || "Ясно") + " • Ощущается как " + root.cfg.weatherText
                    color: root.cfg.onSurfaceVariant
                    font.pixelSize: 10
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // Капсулы показателей (Влажность, Ветер, Давление)
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 12
                color: root.cfg.surfaceContainerHigh
                border.color: root.cfg.outlineVariant
                border.width: 1
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰖌"; color: root.cfg.accent; font.pixelSize: 10 }
                    Text { text: "72%"; color: root.cfg.textPrimary; font.pixelSize: 9; font.bold: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 12
                color: root.cfg.surfaceContainerHigh
                border.color: root.cfg.outlineVariant
                border.width: 1
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰖝"; color: root.cfg.accent; font.pixelSize: 10 }
                    Text { text: "3.8 м/с"; color: root.cfg.textPrimary; font.pixelSize: 9; font.bold: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 12
                color: root.cfg.surfaceContainerHigh
                border.color: root.cfg.outlineVariant
                border.width: 1
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰍛"; color: root.cfg.accent; font.pixelSize: 10 }
                    Text { text: "755 мм"; color: root.cfg.textPrimary; font.pixelSize: 9; font.bold: true }
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 4: PILL STRIP (ГОРИЗОНТАЛЬНАЯ СТРИП-ПИЛЮЛЯ)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        visible: root.variant === "pill_strip"

        Rectangle {
            Layout.preferredWidth: Math.min(parent.height - 16, 52)
            Layout.preferredHeight: Layout.preferredWidth
            radius: Layout.preferredWidth / 2
            color: root.cfg.primaryContainer

            Text {
                anchors.centerIn: parent
                text: "󰖐"
                color: root.cfg.onPrimaryContainer
                font.pixelSize: Math.round(parent.width * 0.5)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            RowLayout {
                spacing: 8
                Text {
                    text: root.cfg.weatherText
                    color: root.cfg.textPrimary
                    font.pixelSize: root.size === "S" ? 22 : 30
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }

                Rectangle {
                    height: 22
                    implicitWidth: psBadgeTxt.implicitWidth + 12
                    radius: 11
                    color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                    border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.25)
                    border.width: 1
                    Text {
                        id: psBadgeTxt
                        anchors.centerIn: parent
                        text: "Комфортно"
                        color: root.cfg.accent
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }

            Text {
                text: (root.cfg.weatherCity || "Тюмень") + " • Облачно с прояснениями"
                color: root.cfg.onSurfaceVariant
                font.pixelSize: 10
                font.family: root.cfg.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
