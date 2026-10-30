import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    required property var cfg
    property var activeWorkspaces: [1, 2, 3, 4, 5]
    property int currentWorkspaceId: 1
    property bool isVertical: false

    signal workspaceSelected(int wsId)

    readonly property real slotSize: isVertical ? 18 : 18
    readonly property real slotSpacing: 4
    readonly property real pacmanSize: 16

    readonly property int activeIdx: {
        if (!activeWorkspaces || activeWorkspaces.length === 0) return 0
        let idx = activeWorkspaces.indexOf(currentWorkspaceId)
        return idx >= 0 ? idx : 0
    }

    property int prevIdx: 0
    property bool facingLeft: false
    property real mouthAngle: 0.20

    SequentialAnimation {
        id: chompAnim
        loops: 3
        NumberAnimation {
            target: root
            property: "mouthAngle"
            to: 0.03
            duration: 75
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "mouthAngle"
            to: 0.22
            duration: 75
            easing.type: Easing.InOutQuad
        }
    }

    onActiveIdxChanged: {
        if (activeIdx < prevIdx) {
            facingLeft = true
        } else if (activeIdx > prevIdx) {
            facingLeft = false
        }
        prevIdx = activeIdx
        chompAnim.restart()
    }

    readonly property color pacmanColor: root.cfg.accent || "#e0b0ff"
    readonly property color ghostColor: root.cfg.surfaceContainerHighest || "#444856"
    readonly property color dotColor: root.cfg.outlineVariant || "#363945"

    readonly property real stepSize: slotSize + slotSpacing
    readonly property real targetPacmanPos: activeIdx * stepSize
    property real currentPacmanPos: targetPacmanPos

    Behavior on currentPacmanPos {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
    }

    implicitWidth: isVertical ? slotSize : (activeWorkspaces.length * slotSize + Math.max(0, activeWorkspaces.length - 1) * slotSpacing)
    implicitHeight: isVertical ? (activeWorkspaces.length * slotSize + Math.max(0, activeWorkspaces.length - 1) * slotSpacing) : slotSize

    // 1. Сетка пеллет (точек) и привидений
    Row {
        id: horizontalSlots
        visible: !root.isVertical
        anchors.fill: parent
        spacing: root.slotSpacing

        Repeater {
            model: root.activeWorkspaces

            delegate: Item {
                id: slotItem
                width: root.slotSize
                height: root.slotSize
                required property int modelData
                required property int index

                readonly property bool isActive: slotItem.modelData === root.currentWorkspaceId
                readonly property bool isPowerPellet: slotItem.index % 2 === 1

                // Точка (Pellet)
                Rectangle {
                    anchors.centerIn: parent
                    visible: !slotItem.isActive
                    width: slotItem.isPowerPellet ? 6 : 4
                    height: width
                    radius: width / 2
                    color: pMouse.containsMouse ? root.cfg.accent : root.dotColor
                    opacity: slotItem.isActive ? 0.0 : (pMouse.containsMouse ? 1.0 : 0.8)
                    scale: pMouse.containsMouse ? 1.3 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // Маленькое ретро-привидение на некоторых воркспейсах
                Canvas {
                    id: ghostCanvas
                    anchors.centerIn: parent
                    visible: !slotItem.isActive && (slotItem.index % 2 === 1)
                    width: 11
                    height: 11
                    opacity: slotItem.isActive ? 0.0 : (pMouse.containsMouse ? 1.0 : 0.75)

                    onPaint: {
                        let ctx = getContext("2d")
                        ctx.reset()
                        let w = width
                        let h = height
                        let r = w / 2

                        // Тело привидения
                        ctx.beginPath()
                        ctx.moveTo(0, r)
                        ctx.arc(r, r, r, Math.PI, 0, false)
                        ctx.lineTo(w, h)
                        // Волнообразный низ
                        ctx.lineTo(w * 0.75, h - 2)
                        ctx.lineTo(w * 0.50, h)
                        ctx.lineTo(w * 0.25, h - 2)
                        ctx.lineTo(0, h)
                        ctx.closePath()
                        ctx.fillStyle = pMouse.containsMouse ? root.cfg.accent : root.ghostColor
                        ctx.fill()

                        // Глаза
                        let eyeR = 1.8
                        let eye1X = w * 0.35
                        let eye2X = w * 0.65
                        let eyeY = r * 0.95
                        ctx.beginPath()
                        ctx.arc(eye1X, eyeY, eyeR, 0, 2 * Math.PI, false)
                        ctx.arc(eye2X, eyeY, eyeR, 0, 2 * Math.PI, false)
                        ctx.fillStyle = "#ffffff"
                        ctx.fill()

                        // Зрачки смотрят на Пакмана
                        let shift = (root.activeIdx > slotItem.index) ? 0.8 : -0.8
                        ctx.beginPath()
                        ctx.arc(eye1X + shift, eyeY, eyeR * 0.55, 0, 2 * Math.PI, false)
                        ctx.arc(eye2X + shift, eyeY, eyeR * 0.55, 0, 2 * Math.PI, false)
                        ctx.fillStyle = "#11111b"
                        ctx.fill()
                    }

                    Connections {
                        target: root
                        function onActiveIdxChanged() { ghostCanvas.requestPaint() }
                    }
                }

                MouseArea {
                    id: pMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.workspaceSelected(slotItem.modelData)
                }
            }
        }
    }

    // Вертикальная сетка пеллет
    Column {
        id: verticalSlots
        visible: root.isVertical
        anchors.fill: parent
        spacing: root.slotSpacing

        Repeater {
            model: root.activeWorkspaces

            delegate: Item {
                id: vSlotItem
                width: root.slotSize
                height: root.slotSize
                required property int modelData
                required property int index

                readonly property bool isActive: vSlotItem.modelData === root.currentWorkspaceId

                Rectangle {
                    anchors.centerIn: parent
                    visible: !vSlotItem.isActive
                    width: 5
                    height: 5
                    radius: 2.5
                    color: vpMouse.containsMouse ? root.cfg.accent : root.dotColor
                    opacity: vSlotItem.isActive ? 0.0 : 0.8
                }

                MouseArea {
                    id: vpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.workspaceSelected(vSlotItem.modelData)
                }
            }
        }
    }

    // 2. Анимированный актер Пакман
    Item {
        id: pacmanActor
        z: 3
        width: root.pacmanSize
        height: root.pacmanSize

        x: root.isVertical ? (parent.width - width) / 2 : (root.currentPacmanPos + (root.slotSize - width) / 2)
        y: root.isVertical ? (root.currentPacmanPos + (root.slotSize - height) / 2) : (parent.height - height) / 2

        transform: Scale {
            origin.x: pacmanActor.width / 2
            origin.y: pacmanActor.height / 2
            xScale: (!root.isVertical && root.facingLeft) ? -1 : 1
        }

        Canvas {
            id: pacmanCanvas
            anchors.fill: parent

            onPaint: {
                let ctx = getContext("2d")
                ctx.reset()
                let r = width / 2
                let cx = r
                let cy = r
                let mouth = root.mouthAngle * Math.PI

                // Тело Пакмана со ртом
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, r - 1.0, mouth, 2 * Math.PI - mouth, false)
                ctx.closePath()
                ctx.fillStyle = root.pacmanColor
                ctx.fill()

                // Глаз Пакмана
                let eyeR = r * 0.16
                let eyeX = cx + r * 0.15
                let eyeY = cy - r * 0.45
                ctx.beginPath()
                ctx.arc(eyeX, eyeY, eyeR, 0, 2 * Math.PI, false)
                ctx.fillStyle = "#11111b"
                ctx.fill()
            }

            Connections {
                target: root
                function onMouthAngleChanged() { pacmanCanvas.requestPaint() }
                function onPacmanColorChanged() { pacmanCanvas.requestPaint() }
            }
        }
    }
}
