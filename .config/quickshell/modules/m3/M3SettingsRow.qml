import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool showDivider: true
    property bool clickable: false
    property color iconColor: (typeof Config !== "undefined" && Config.accent) ? Config.accent : "#a8c7fa"
    property color iconBgColor: (typeof Config !== "undefined" && Config.surfaceContainerHighest) ? Config.surfaceContainerHighest : "#32353c"
    property color titleColor: (typeof Config !== "undefined" && Config.onSurface) ? Config.onSurface : "#e2e4ec"
    property color subtitleColor: (typeof Config !== "undefined" && Config.onSurfaceVariant) ? Config.onSurfaceVariant : "#9ea2b2"

    signal clicked()
    default property alias control: controlSlot.children

    Layout.fillWidth: true
    implicitHeight: Math.max(56, contentRow.implicitHeight + 16)

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: (root.clickable && rowMouse.containsMouse) ? Qt.rgba(255, 255, 255, 0.04) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14

        // Контейнер иконки (Squircle 36x36)
        Rectangle {
            visible: root.icon !== ""
            width: 36
            height: 36
            radius: 12
            color: root.iconBgColor

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.iconColor
                font.pixelSize: 17
            }
        }

        // Текстовый блок
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.title
                color: root.titleColor
                font.pixelSize: 13
                font.bold: true
                font.family: "Rubik, sans-serif"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                visible: root.subtitle !== ""
                text: root.subtitle
                color: root.subtitleColor
                font.pixelSize: 11
                font.family: "Rubik, sans-serif"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // Слот для переключателя / контрола
        Item {
            id: controlSlot
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: Math.max(implicitWidth, childrenRect.width)
            Layout.preferredHeight: Math.max(implicitHeight, childrenRect.height)
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    // Inset Divider
    Rectangle {
        visible: root.showDivider
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.icon !== "" ? 60 : 16
        anchors.rightMargin: 12
        height: 1
        color: (typeof Config !== "undefined" && Config.outlineVariant) ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.05)
    }
}
