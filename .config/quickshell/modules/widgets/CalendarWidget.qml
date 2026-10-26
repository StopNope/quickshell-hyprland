import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var cfg
    property var widgetData: ({})

    readonly property string variant: (widgetData && widgetData.variant) ? widgetData.variant : "month"
    readonly property string size: (widgetData && widgetData.size) ? widgetData.size : "M"

    readonly property date now: new Date()
    readonly property int currentYear: now.getFullYear()
    readonly property int currentMonth: now.getMonth() // 0-11
    readonly property int todayDate: now.getDate()

    // Генерация дней месяца
    function getDaysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    function getFirstDayOfWeek(year, month) {
        let day = new Date(year, month, 1).getDay() // 0 is Sunday
        return (day === 0) ? 6 : day - 1 // 0 is Monday
    }

    readonly property int totalDays: getDaysInMonth(currentYear, currentMonth)
    readonly property int prevMonthDays: getDaysInMonth(currentYear, currentMonth - 1)
    readonly property int startOffset: getFirstDayOfWeek(currentYear, currentMonth)

    function formatMonthYear(d) {
        let str = Qt.formatDateTime(d, "MMMM yyyy")
        if (!str) return ""
        return str.charAt(0).toUpperCase() + str.slice(1)
    }

    radius: (widgetData && widgetData.radius !== undefined) ? widgetData.radius : (root.cfg.widgetRadius || 28)
    color: root.cfg.surfaceContainer
    border.color: root.cfg.outlineVariant
    border.width: 1
    clip: true

    // ==========================================
    // ВАРИАНТ 0: PIXEL SQUIRCLE DAY (ИЗ РЕФЕРЕНСА ANDROID 14/15 'Tue 02')
    // ==========================================
    Item {
        id: squircleDayItem
        anchors.fill: parent
        visible: root.variant === "glance_day" || root.variant === "squircle"

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.94
            height: width
            radius: width * 0.35
            color: root.cfg.surfaceContainerHigh
            border.color: root.cfg.outlineVariant
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(root.now, "ddd")
                    color: root.cfg.onSurfaceVariant
                    font.pixelSize: Math.round(parent.parent.width * 0.22)
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(root.now, "dd")
                    color: root.cfg.textPrimary
                    font.pixelSize: Math.round(parent.parent.width * 0.36)
                    font.bold: true
                    font.family: "Fredoka"
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10
        visible: root.variant === "month"

        // Заголовок месяца в стиле Material 3
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Название месяца и год
            RowLayout {
                spacing: 6
                Text {
                    text: root.formatMonthYear(root.now)
                    color: root.cfg.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }

            Item { Layout.fillWidth: true }

            // Мягкий бейдж "Сегодня"
            Rectangle {
                height: 24
                width: todayBadgeLayout.implicitWidth + 16
                radius: 12
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.14)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.28)
                border.width: 1

                RowLayout {
                    id: todayBadgeLayout
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰸗"
                        color: root.cfg.accent
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Сегодня: " + root.todayDate
                        color: root.cfg.accent
                        font.pixelSize: 10
                        font.bold: true
                        font.family: root.cfg.fontFamily
                    }
                }
            }
        }

        // Дни недели с комфортными отступами
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
                Item {
                    Layout.fillWidth: true
                    height: 20

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: (index >= 5) ? root.cfg.danger : root.cfg.onSurfaceVariant
                        font.pixelSize: 10
                        font.bold: true
                        font.family: root.cfg.fontFamily
                    }
                }
            }
        }

        // Разделительная линия с очень мягкой прозрачностью
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.cfg.outlineVariant
            opacity: 0.5
        }

        // Сетка дней месяца (6 строк x 7 колонок) с воздухом
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 2

            Repeater {
                model: 42 // 6 недель
                Item {
                    id: dayCell
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property int dayNum: index - root.startOffset + 1
                    readonly property bool isCurrentMonthDay: dayNum >= 1 && dayNum <= root.totalDays
                    readonly property bool isToday: isCurrentMonthDay && dayNum === root.todayDate
                    readonly property int displayDay: {
                        if (dayNum < 1) return root.prevMonthDays + dayNum
                        if (dayNum > root.totalDays) return dayNum - root.totalDays
                        return dayNum
                    }
                    readonly property bool isWeekend: (index % 7 === 5) || (index % 7 === 6)

                    // Мягкая органическая пилюля (Capsule / Pill) для текущего дня в стиле Android 14/15
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 2, 34)
                        height: Math.min(parent.height - 2, 26)
                        radius: 13
                        color: dayCell.isToday ? root.cfg.accent : "transparent"
                        border.width: 0

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.displayDay
                            color: {
                                if (dayCell.isToday) return root.cfg.accentText || "#1a1c22"
                                if (!dayCell.isCurrentMonthDay) return Qt.rgba(root.cfg.onSurfaceVariant.r, root.cfg.onSurfaceVariant.g, root.cfg.onSurfaceVariant.b, 0.28)
                                if (dayCell.isWeekend) return root.cfg.danger
                                return root.cfg.textPrimary
                            }
                            font.pixelSize: 11
                            font.bold: dayCell.isToday || (dayCell.isCurrentMonthDay && dayCell.isWeekend)
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 2: WEEK STRIP (НЕДЕЛЬНАЯ СТРИП-ЛЕНТА)
    // ==========================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8
        visible: root.variant === "week_strip"

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.formatMonthYear(root.now)
                color: root.cfg.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.cfg.fontFamily
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                height: 20
                implicitWidth: wsTodayTxt.implicitWidth + 12
                radius: 10
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)
                border.width: 1
                Text {
                    id: wsTodayTxt
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(root.now, "dddd, d MMMM")
                    color: root.cfg.accent
                    font.pixelSize: 9
                    font.bold: true
                    font.family: root.cfg.fontFamily
                }
            }
        }

        // 7 дней текущей недели
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Repeater {
                // Дни недели: ПН..ВС
                model: [
                    { day: "ПН", d: (root.todayDate - ((root.now.getDay() + 6) % 7)) },
                    { day: "ВТ", d: (root.todayDate - ((root.now.getDay() + 6) % 7) + 1) },
                    { day: "СР", d: (root.todayDate - ((root.now.getDay() + 6) % 7) + 2) },
                    { day: "ЧТ", d: (root.todayDate - ((root.now.getDay() + 6) % 7) + 3) },
                    { day: "ПТ", d: (root.todayDate - ((root.now.getDay() + 6) % 7) + 4) },
                    { day: "СБ", d: (root.todayDate - ((root.now.getDay() + 6) % 7) + 5) },
                    { day: "ВС", d: (root.todayDate - ((root.now.getDay() + 6) % 7) + 6) }
                ]

                Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    readonly property bool isToday: modelData.d === root.todayDate
                    color: isToday ? root.cfg.accent : root.cfg.surfaceContainerHigh
                    border.color: isToday ? root.cfg.accent : root.cfg.outlineVariant
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.day
                            color: isToday ? root.cfg.accentText : (index >= 5 ? root.cfg.danger : root.cfg.onSurfaceVariant)
                            font.pixelSize: 9
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.max(1, Math.min(31, modelData.d))
                            color: isToday ? root.cfg.accentText : root.cfg.textPrimary
                            font.pixelSize: 12
                            font.bold: true
                            font.family: root.cfg.fontFamily
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // ВАРИАНТ 3: MINIMAL PILL (ЛАКОНИЧНАЯ ДАТА)
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
        visible: root.variant === "minimal_pill"

        Rectangle {
            Layout.preferredWidth: Math.min(parent.height - 8, 70)
            Layout.preferredHeight: Layout.preferredWidth
            radius: 20
            color: root.cfg.primaryContainer
            Text {
                anchors.centerIn: parent
                text: root.todayDate
                color: root.cfg.onPrimaryContainer
                font.pixelSize: Math.round(parent.width * 0.52)
                font.bold: true
                font.family: root.cfg.fontFamily
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                text: Qt.formatDateTime(root.now, "dddd")
                color: root.cfg.textPrimary
                font.pixelSize: 14
                font.bold: true
                font.family: root.cfg.fontFamily
            }

            Text {
                text: Qt.formatDateTime(root.now, "d MMMM yyyy")
                color: root.cfg.onSurfaceVariant
                font.pixelSize: 10
                font.family: root.cfg.fontFamily
            }

            Rectangle {
                height: 20
                implicitWidth: noEvTxt.implicitWidth + 12
                radius: 10
                color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.12)
                border.color: Qt.rgba(root.cfg.accent.r, root.cfg.accent.g, root.cfg.accent.b, 0.22)
                border.width: 1
                Text {
                    id: noEvTxt
                    anchors.centerIn: parent
                    text: "󰸗 Нет запланированных дел"
                    color: root.cfg.accent
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }
}
