import QtQuick

Item {
    id: root

    property color color: "#a8c7fa"
    property string shape: "blossom" // "blossom", "scallop", "pebble", "flower12", "squircle", "circle"
    property real rotationAngle: 0
    property real scaleFactor: 1.0
    property real morphProgress: shape === "circle" ? 0.0 : 1.0

    Behavior on morphProgress {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    implicitWidth: 48
    implicitHeight: 48

    Canvas {
        antialiasing: true
        id: shapeCanvas
        anchors.fill: parent

        onPaint: {
            let ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            let w = width
            let h = height
            let cx = w / 2
            let cy = h / 2
            let rMax = Math.min(cx, cy) * 0.94 * root.scaleFactor

            ctx.save()
            ctx.translate(cx, cy)
            ctx.rotate(root.rotationAngle * Math.PI / 180)
            ctx.translate(-cx, -cy)

            ctx.beginPath()
            ctx.fillStyle = root.color

            if (root.shape === "circle" && root.morphProgress <= 0.001) {
                ctx.arc(cx, cy, rMax, 0, 2 * Math.PI)
            } else if (root.shape === "pebble") {
                // Organic Material You Pebble / Potato shape (Android 14/15 weather widget)
                let rx = (w / 2) * 0.92 * root.scaleFactor
                let ry = (h / 2) * 0.92 * root.scaleFactor
                ctx.beginPath()
                ctx.moveTo(cx - rx * 0.7, cy - ry)
                ctx.bezierCurveTo(cx + rx * 0.5, cy - ry * 1.05, cx + rx * 1.05, cy - ry * 0.4, cx + rx, cy + ry * 0.2)
                ctx.bezierCurveTo(cx + rx * 0.95, cy + ry * 0.9, cx + rx * 0.2, cy + ry * 1.05, cx - rx * 0.4, cy + ry * 0.95)
                ctx.bezierCurveTo(cx - rx * 1.05, cy + ry * 0.8, cx - rx * 1.05, cy - ry * 0.3, cx - rx * 0.7, cy - ry)
            } else if (root.shape === "blossom" || root.shape === "flower12") {
                // Material You Expressive 12-lobe organic flower (Pixel Clock)
                let rMin = rMax * 0.86
                let amplitude = ((rMax - rMin) / 2) * root.morphProgress
                let baseR = rMax - amplitude
                let steps = 144
                for (let i = 0; i <= steps; i++) {
                    let theta = i * 2 * Math.PI / steps
                    let r = baseR + amplitude * Math.cos(12 * theta)
                    let px = cx + r * Math.cos(theta)
                    let py = cy + r * Math.sin(theta)
                    if (i === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                }
            } else if (root.shape === "scallop") {
                // Material You 8-lobe scalloped flower
                let rMin = rMax * 0.82
                let amplitude = ((rMax - rMin) / 2) * root.morphProgress
                let baseR = rMax - amplitude
                let steps = 128
                for (let i = 0; i <= steps; i++) {
                    let theta = i * 2 * Math.PI / steps
                    let r = baseR + amplitude * Math.cos(8 * theta)
                    let px = cx + r * Math.cos(theta)
                    let py = cy + r * Math.sin(theta)
                    if (i === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                }
            } else if (root.shape === "squircle") {
                let rad = rMax * 0.65
                ctx.roundRect(cx - rMax, cy - rMax, rMax * 2, rMax * 2, rad)
            } else {
                ctx.arc(cx, cy, rMax, 0, 2 * Math.PI)
            }

            ctx.closePath()
            ctx.fill()
            ctx.restore()
        }

        Connections {
            target: root
            function onColorChanged() { shapeCanvas.requestPaint() }
            function onShapeChanged() { shapeCanvas.requestPaint() }
            function onRotationAngleChanged() { shapeCanvas.requestPaint() }
            function onScaleFactorChanged() { shapeCanvas.requestPaint() }
            function onMorphProgressChanged() { shapeCanvas.requestPaint() }
            function onWidthChanged() { shapeCanvas.requestPaint() }
            function onHeightChanged() { shapeCanvas.requestPaint() }
        }
    }
}
