import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root

    property string sectionTitle: ""
    property color titleColor: (typeof Config !== "undefined" && Config.accent) ? Config.accent : "#a8c7fa"
    property color cardColor: (typeof Config !== "undefined" && Config.surfaceContainer) ? Config.surfaceContainer : "#202228"
    property color borderColor: (typeof Config !== "undefined" && Config.outlineVariant) ? Config.outlineVariant : "#353842"
    property int cardRadius: 24

    default property alias content: cardLayout.children

    spacing: 8
    Layout.fillWidth: true

    Text {
        visible: root.sectionTitle !== ""
        text: root.sectionTitle
        color: root.titleColor
        font.pixelSize: 12
        font.bold: true
        font.family: "Rubik, sans-serif"
        Layout.leftMargin: 10
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + 16
        Layout.preferredHeight: implicitHeight
        radius: root.cardRadius
        color: root.cardColor
        border.color: root.borderColor
        border.width: 1
        clip: true

        ColumnLayout {
            id: cardLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 0
        }
    }
}
