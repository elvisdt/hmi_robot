import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var points: []                  // puntos recibidos del backend
    property var drawPoints: []              // puntos listos para pintar (sin normalizar)
    property real scale: 1.0                 // zoom actual
    property real centerX: 0                 // centro de la vista en coords mundo
    property real centerY: 0
    property real minScale: 0.1
    property real maxScale: 8.0
    property color bgColor: "#ffffff"
    property color gridColor: "#e0e0e0"
    property color axisColor: "#222"
    property real gridStep: 50

    onPointsChanged: {
        console.log("Canvas recibio", points.length, "puntos")
        drawPoints = points.slice()      // copia directa, sin invertir
        canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = bgColor
            ctx.fillRect(0, 0, width, height)

            // helper de conversion (origen en centro de viewport, Y hacia arriba)
            function xPx(wx) { return width / 2 + (wx - centerX) * scale }
            function yPx(wy) { return height / 2 - (wy - centerY) * scale }

            // ===== GRID =====
            ctx.strokeStyle = gridColor
            ctx.lineWidth = Math.max(0.5, 1 / scale)

            var step = gridStep
            var left = centerX - (width / 2) / scale
            var right = centerX + (width / 2) / scale
            var bottom = centerY - (height / 2) / scale
            var top = centerY + (height / 2) / scale

            var gxStart = Math.floor(left / step) * step
            var gxEnd = Math.ceil(right / step) * step
            for (var gx = gxStart; gx <= gxEnd; gx += step) {
                var xx = xPx(gx) + 0.5 / scale
                if (xx < 0 || xx > width) continue
                ctx.beginPath()
                ctx.moveTo(xx, 0)
                ctx.lineTo(xx, height)
                ctx.stroke()
            }

            var gyStart = Math.floor(bottom / step) * step
            var gyEnd = Math.ceil(top / step) * step
            for (var gy = gyStart; gy <= gyEnd; gy += step) {
                var yy = yPx(gy) + 0.5 / scale
                if (yy < 0 || yy > height) continue
                ctx.beginPath()
                ctx.moveTo(0, yy)
                ctx.lineTo(width, yy)
                ctx.stroke()
            }

            // ===== AXES =====
            ctx.strokeStyle = axisColor
            ctx.lineWidth = 2 / scale

            ctx.beginPath()
            ctx.moveTo(xPx(left), yPx(0))
            ctx.lineTo(xPx(right), yPx(0))
            ctx.moveTo(xPx(0), yPx(top))
            ctx.lineTo(xPx(0), yPx(bottom))
            ctx.stroke()

            // ===== DIBUJAR PUNTOS / POLILÍNEAS =====
            if (drawPoints.length > 0) {
                ctx.lineJoin = "round"
                ctx.lineCap = "round"

                var current = []
                var currentFlag = 0
                function flush() {
                    if (current.length < 2) return
                    ctx.beginPath()
                    ctx.moveTo(xPx(current[0].x), yPx(current[0].y))
                    for (var j = 1; j < current.length; j++) {
                        ctx.lineTo(xPx(current[j].x), yPx(current[j].y))
                    }
                    ctx.strokeStyle = currentFlag === 1 ? "#22c55e" : "#f59e0b"
                    ctx.lineWidth = 2 / scale
                    ctx.stroke()
                }

                for (var i = 0; i < drawPoints.length; i++) {
                    var p = drawPoints[i]
                    if (!p) continue

                    if (p.break) {
                        flush()
                        current = []
                        currentFlag = 0
                        continue
                    }

                    if (p.x === undefined || p.y === undefined)
                        continue

                    currentFlag = p.flag !== undefined ? p.flag : currentFlag
                    current.push(p)
                }
                flush()
            }

            ctx.restore()
        }

        // ===== MOUSE PANNING =====
        MouseArea {
            anchors.fill: parent
            property real lastX
            property real lastY

            onPressed: function(mouse) {
                lastX = mouse.x
                lastY = mouse.y
            }

            onPositionChanged: function(mouse) {
                if (mouse.buttons & Qt.LeftButton) {
                    offsetX += mouse.x - lastX
                    offsetY += mouse.y - lastY
                    lastX = mouse.x
                    lastY = mouse.y
                    clampView()
                    canvas.requestPaint()
                }
            }

            // ===== ZOOM CON RUEDA =====
            onWheel: function(wheel) {
                var zoomFactor = wheel.angleDelta.y > 0 ? 1.1 : 0.9
                var oldScale = scale
                var newScale = Math.max(minScale, Math.min(maxScale, scale * zoomFactor))

                if (newScale === oldScale)
                    return

                // mantener punto del mouse estable al hacer zoom
                var mx = wheel.x
                var my = wheel.y
                var wx = centerX + (mx - width / 2) / scale
                var wy = centerY - (my - height / 2) / scale

                scale = newScale

                centerX = wx - (mx - width / 2) / scale
                centerY = wy + (my - height / 2) / scale
                canvas.requestPaint()
            }
        }
    }

    // ===== BOTÓN PARA AJUSTAR VISTA =====
    function fitView() {
        if (drawPoints.length === 0) return

        var minx = Infinity, maxx = -Infinity
        var miny = Infinity, maxy = -Infinity

        for (var i = 0; i < drawPoints.length; i++) {
            var q = drawPoints[i]
            if (!q || q.break) continue
            if (q.x < minx) minx = q.x
            if (q.x > maxx) maxx = q.x
            if (q.y < miny) miny = q.y
            if (q.y > maxy) maxy = q.y
        }

        var w = maxx - minx
        var h = maxy - miny
        if (w <= 0 || h <= 0) return

        var s1 = width / (w * 1.2)
        var s2 = height / (h * 1.2)

        scale = Math.min(s1, s2)

        centerX = minx + w / 2
        centerY = miny + h / 2
        canvas.requestPaint()
    }
}
