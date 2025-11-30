import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Estilo y datos
    property var palette: ({})
    property var points: []                  // puntos crudos (x,y,flag,break)
    property var drawPoints: []              // buffer copiado para pintar
    property color accentColor: palette.accent || "#0a84ff"
    property bool showAxes: true
    property color axisXColor: palette.axisX || palette.accent || "#ef4444"
    property color axisYColor: palette.axisY || palette.accent || "#10b981"
    property color canvasColor: palette.canvasBg || palette.cardBg || "#f9fafc"
    property color gridColor: palette.grid || Qt.darker(canvasColor, 1.08)
    property color unitColor: palette.text || palette.label || "#6b7280"

    // Ajustes de vista
    property real gridStep: 50
    property real marginRatio: 0.05
    property real padFactor: 0.2
    property bool showWorkArea: false
    property real axisMinX: -300
    property real axisMaxX: 300
    property real axisMinY: -300
    property real axisMaxY: 300
    property real rotationDeg: 0
    property real minSpan: 50

    Layout.fillWidth: true
    Layout.fillHeight: true

    onPointsChanged: setPoints(points)
    onCanvasColorChanged: canvas.requestPaint()
    onGridColorChanged: canvas.requestPaint()
    onAxisXColorChanged: canvas.requestPaint()
    onAxisYColorChanged: canvas.requestPaint()
    onUnitColorChanged: canvas.requestPaint()

    function setPoints(arr) {
        points = arr || []
        drawPoints = points.slice()
        if (drawPoints.length > 0) {
            var minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9
            for (var i = 0; i < drawPoints.length; i++) {
                var p = drawPoints[i]
                if (!p || p.break || p.x === undefined || p.y === undefined) continue
                if (p.x < minx) minx = p.x
                if (p.x > maxx) maxx = p.x
                if (p.y < miny) miny = p.y
                if (p.y > maxy) maxy = p.y
            }
            if (minx < 1e9) {
                var maxAbs = Math.max(Math.abs(minx), Math.abs(maxx), Math.abs(miny), Math.abs(maxy))
                var pad = Math.max(10, maxAbs * padFactor)
                var span = maxAbs + pad
                axisMinX = -span
                axisMaxX = span
                axisMinY = -span
                axisMaxY = span
                gridStep = niceStep((axisMaxX - axisMinX), 18)
            }
        } else {
            // reset a rango fijo
            axisMinX = -300
            axisMaxX = 300
            axisMinY = -300
            axisMaxY = 300
            gridStep = 50
        }
        canvas.requestPaint()
    }

    function fitToBounds(xmin, xmax, ymin, ymax) {
        if (xmin === undefined || xmax === undefined || ymin === undefined || ymax === undefined)
            return
        var maxAbs = Math.max(Math.abs(xmin), Math.abs(xmax), Math.abs(ymin), Math.abs(ymax))
        var pad = Math.max(10, maxAbs * padFactor)
        var span = maxAbs + pad
        axisMinX = -span
        axisMaxX = span
        axisMinY = -span
        axisMaxY = span
        gridStep = niceStep((axisMaxX - axisMinX), 18)
        canvas.requestPaint()
    }

    function niceStep(range, targetLines) {
        if (range <= 0) return gridStep
        var rough = range / targetLines
        var pow10 = Math.pow(10, Math.floor(Math.log10(rough)))
        var frac = rough / pow10
        var step
        if (frac < 1.5) step = 1
        else if (frac < 3.5) step = 2
        else if (frac < 7.5) step = 5
        else step = 10
        return step * pow10
    }

    function pan(dx, dy) {
        axisMinX += dx
        axisMaxX += dx
        axisMinY += dy
        axisMaxY += dy
        canvas.requestPaint()
    }

    function zoom(factor) {
        if (factor === 0) return
        var cx = (axisMinX + axisMaxX) / 2
        var cy = (axisMinY + axisMaxY) / 2
        var spanX = Math.max((axisMaxX - axisMinX) * factor, minSpan)
        var spanY = Math.max((axisMaxY - axisMinY) * factor, minSpan)
        axisMinX = cx - spanX / 2
        axisMaxX = cx + spanX / 2
        axisMinY = cy - spanY / 2
        axisMaxY = cy + spanY / 2
        gridStep = niceStep(Math.max(axisMaxX - axisMinX, axisMaxY - axisMinY), 18)
        canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = canvasColor
            ctx.fillRect(0, 0, width, height)

            ctx.save()
            ctx.translate(width / 2, height / 2)
            ctx.rotate(rotationDeg * Math.PI / 180)
            ctx.translate(-width / 2, -height / 2)

            var marginPx = Math.min(width, height) * marginRatio
            var innerW = width - 2 * marginPx
            var innerH = height - 2 * marginPx
            var rangeX = axisMaxX - axisMinX
            var rangeY = axisMaxY - axisMinY
            var centerX = (axisMinX + axisMaxX) / 2
            var centerY = (axisMinY + axisMaxY) / 2
            var step = gridStep > 0 ? gridStep : niceStep(Math.max(rangeX, rangeY), 18)
            var scale = Math.min(innerW / Math.max(rangeX, 1e-6), innerH / Math.max(rangeY, 1e-6))

            function xPx(wx) { return marginPx + (wx - (centerX - rangeX / 2)) * scale }
            function yPx(wy) { return marginPx + ((centerY + rangeY / 2) - wy) * scale }

            // Grilla
            ctx.save()
            ctx.strokeStyle = gridColor
            ctx.globalAlpha = 0.6
            ctx.lineWidth = 1.2
            var left = centerX - rangeX / 2
            var right = centerX + rangeX / 2
            var bottom = centerY - rangeY / 2
            var top = centerY + rangeY / 2

            var gxStart = Math.floor(left / step) * step
            var gxEnd = Math.ceil(right / step) * step
            for (var gx = gxStart; gx <= gxEnd + 0.001; gx += step) {
                var px = xPx(gx)
                ctx.beginPath()
                ctx.moveTo(px, 0)
                ctx.lineTo(px, height)
                ctx.stroke()
            }

            var gyStart = Math.floor(bottom / step) * step
            var gyEnd = Math.ceil(top / step) * step
            for (var gy = gyStart; gy <= gyEnd + 0.001; gy += step) {
                var py = yPx(gy)
                ctx.beginPath()
                ctx.moveTo(0, py)
                ctx.lineTo(width, py)
                ctx.stroke()
            }
            ctx.restore()

            // Etiquetas de grilla
            ctx.fillStyle = unitColor
            ctx.font = "10px sans-serif"
            for (var gxLab = gxStart; gxLab <= gxEnd + 0.001; gxLab += step) {
                var pxLab = xPx(gxLab)
                ctx.fillText(gxLab.toFixed(0), pxLab + 2, height - 6)
            }
            for (var gyLab = gyStart; gyLab <= gyEnd + 0.001; gyLab += step) {
                var pyLab = yPx(gyLab)
                ctx.fillText(gyLab.toFixed(0), 6, pyLab - 4)
            }

            // Ejes
            if (showAxes) {
                ctx.strokeStyle = axisXColor
                ctx.lineWidth = 1.8
                ctx.beginPath()
                ctx.moveTo(0, yPx(0))
                ctx.lineTo(width, yPx(0))
                ctx.stroke()

                ctx.strokeStyle = axisYColor
                ctx.beginPath()
                ctx.moveTo(xPx(0), 0)
                ctx.lineTo(xPx(0), height)
                ctx.stroke()

                ctx.fillStyle = unitColor
                ctx.font = "11px sans-serif"
                ctx.fillText(right.toFixed(0), width - 40, yPx(0) - 6)
                ctx.fillText(top.toFixed(0), xPx(0) + 6, 12)
            }

            // Polilíneas
            if (drawPoints && drawPoints.length > 0) {
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                var current = []
                var currentFlag = 1
                function flush() {
                    if (current.length < 2) return
                    ctx.beginPath()
                    ctx.moveTo(xPx(current[0].x), yPx(current[0].y))
                    for (var j = 1; j < current.length; j++) {
                        ctx.lineTo(xPx(current[j].x), yPx(current[j].y))
                    }
                    var isClosed = Math.hypot(
                        current[0].x - current[current.length - 1].x,
                        current[0].y - current[current.length - 1].y
                    ) < 1e-3
                    if (isClosed) ctx.closePath()
                    if (currentFlag === 1) {
                        ctx.fillStyle = Qt.rgba(0.0, 0.6, 0.0, 0.25)
                        ctx.strokeStyle = Qt.rgba(0.0, 0.5, 0.0, 0.8)
                    } else {
                        ctx.fillStyle = Qt.rgba(1.0, 0.6, 0.0, 0.2)
                        ctx.strokeStyle = Qt.rgba(1.0, 0.4, 0.0, 0.9)
                    }
                    ctx.lineWidth = 2
                    if (isClosed) ctx.fill()
                    ctx.stroke()
                }

                for (var i = 0; i < drawPoints.length; i++) {
                    var p = drawPoints[i]
                    if (!p) continue
                    if (p.break) {
                        flush()
                        current = []
                        currentFlag = 1
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
    }
}
