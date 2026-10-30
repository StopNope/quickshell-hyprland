import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

RowLayout {
    id: root
    spacing: 7

    readonly property var activeWorkspaces: {
        let currentId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ? Hyprland.focusedWorkspace.id : 1
        let set = new Set()
        for (let i = 1; i <= 5; i++) set.add(i)
        if (Hyprland.workspaces && Hyprland.workspaces.values) {
            for (let ws of Hyprland.workspaces.values) {
                if (ws && ws.id > 0) set.add(ws.id)
            }
        }
        set.add(currentId)
        return Array.from(set).sort((a, b) => a - b)
    }

    Repeater {
        model: root.activeWorkspaces

        Rectangle {
            antialiasing: true
            id: dot
            required property int modelData
            readonly property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData

            implicitHeight: 7
            implicitWidth: isActive ? 22 : 7
            radius: 3.5

            // Активный — белый/светлый, неактивный — темный графит
            color: isActive ? "#e6e8ee" : (mouseArea.containsMouse ? "#636674" : "#434551")

            Behavior on implicitWidth {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace", dot.modelData.toString())
            }
        }
    }
}
