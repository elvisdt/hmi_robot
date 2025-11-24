import QtQuick
import QtQuick.Layouts

Canvas {
    id: canvas

    property var palette: ({})
    property var points: []
    property color accentColor: palette.accent || "#0a84ff"
    property bool showAxes: true
    property color axisXColor: "#ef4444"
    property color axisYColor: "#10b981"
    property real rotationDeg: -90
    property real worldXMin: 0
    property real worldXMax: 600
    property real worldYMin: -600
    property real worldYMax: 600
    property real gridStep: 100
    property real marginRatio: 0.08
    property bool showWorkArea: true

    // area de trbajo
    property real workXMin: -1200
    property real workXMax: 1200
    property real workYMin: -1200
    property real workYMax: 1200
    property color workAreaFill: palette.workAreaFill || Qt.rgba(0.31, 0.62, 1, 0.09)
    property color workAreaStroke: palette.workAreaStroke || Qt.rgba(0.65, 0.21, 33, 0.31)
    
    property color unitColor: palette.label || "#9ca3af"
    property color canvasColor: palette.canvasBg || "#f9fafc"
    property color gridColor: palette.grid || "#e7ebf3"

    Layout.fillWidth: true
    Layout.fillHeight: true
    antialiasing: true

    onPointsChanged: requestPaint()
    onPaletteChanged: requestPaint()
    onAccentColorChanged: requestPaint()
    onCanvasColorChanged: requestPaint()
    onGridColorChanged: requestPaint()
    onUnitColorChanged: requestPaint()
    onAxisXColorChanged: requestPaint()
    onAxisYColorChanged: requestPaint()
    onShowAxesChanged: requestPaint()
    onRotationDegChanged: requestPaint()
    onMarginRatioChanged: requestPaint()
    onWorldXMinChanged: requestPaint()
    onWorldXMaxChanged: requestPaint()
    onWorldYMinChanged: requestPaint()
    onWorldYMaxChanged: requestPaint()
    onGridStepChanged: requestPaint()
    onShowWorkAreaChanged: requestPaint()
    onWorkXMinChanged: requestPaint()
    onWorkXMaxChanged: requestPaint()
    onWorkYMinChanged: requestPaint()
    onWorkYMaxChanged: requestPaint()
    onWorkAreaFillChanged: requestPaint()
    onWorkAreaStrokeChanged: requestPaint()

    function setPoints(arr) {
        points = arr || []
        requestPaint()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = canvasColor
        ctx.fillRect(0, 0, width, height)

        // ajustar rotacion y escala para que el contenido rote sin recortes
        var angle = rotationDeg * Math.PI / 180
        var cosA = Math.cos(angle)
        var sinA = Math.sin(angle)
        var rotW = Math.abs(width * cosA) + Math.abs(height * sinA)
        var rotH = Math.abs(width * sinA) + Math.abs(height * cosA)
        var fit = Math.min(width / rotW, height / rotH)
        ctx.save()
        ctx.translate(width / 2, height / 2)
        ctx.scale(fit, fit)
        ctx.rotate(angle)
        ctx.translate(-width / 2, -height / 2)

        // escalado a espacio de trabajo fijo (mm)
        var margin = Math.min(width, height) * marginRatio
        var innerW = width - 2 * margin
        var innerH = height - 2 * margin
        var rangeX = Math.max(worldXMax - worldXMin, 1e-6)
        var rangeY = Math.max(worldYMax - worldYMin, 1e-6)
        var scale = Math.min(innerW / rangeX, innerH / rangeY)
        var extraX = Math.max(0, (innerW - rangeX * scale) / 2)
        var extraY = Math.max(0, (innerH - rangeY * scale) / 2)
        function xPx(wx) { return margin + extraX + (wx - worldXMin) * scale }
        function yPx(wy) { return margin + extraY + (worldYMax - wy) * scale }

        function invX(px) { return (px - margin - extraX) / scale + worldXMin }
        function invY(py) { return worldYMax - (py - margin - extraY) / scale }

        // grid con etiquetas en mm (constante, extendido a toda el area visible)
        ctx.strokeStyle = gridColor
        ctx.lineWidth = 1
        ctx.beginPath()
        var step = gridStep
        var visMinX = Math.min(worldXMin, worldXMax, invX(0), invX(width))
        var visMaxX = Math.max(worldXMin, worldXMax, invX(0), invX(width))
        var visMinY = Math.min(worldYMin, worldYMax, invY(0), invY(height))
        var visMaxY = Math.max(worldYMin, worldYMax, invY(0), invY(height))
        var startX = Math.floor(visMinX / step) * step
        var endX = Math.ceil(visMaxX / step) * step
        for (var gx = startX; gx <= endX + 0.001; gx += step) {
            var px = xPx(gx) + 0.5
            ctx.moveTo(px, 0)
            ctx.lineTo(px, height)
        }
        var startY = Math.floor(visMinY / step) * step
        var endY = Math.ceil(visMaxY / step) * step
        for (var gy = startY; gy <= endY + 0.001; gy += step) {
            var py = yPx(gy) + 0.5
            ctx.moveTo(0, py)
            ctx.lineTo(width, py)
        }
        ctx.stroke()

        ctx.fillStyle = unitColor
        ctx.font = "10px sans-serif"
        for (var gxLab = startX; gxLab <= endX + 0.001; gxLab += step) {
            var pxLab = xPx(gxLab)
            if (pxLab >= -20 && pxLab <= width + 20)
                ctx.fillText(gxLab.toFixed(0), pxLab + 2, margin - 6)
        }
        for (var gyLab = startY; gyLab <= endY + 0.001; gyLab += step) {
            var pyLab = yPx(gyLab)
            if (pyLab >= -20 && pyLab <= height + 20)
                ctx.fillText(gyLab.toFixed(0), margin - 26, pyLab + 3)
        }

        if (showWorkArea) {
            var left = xPx(workXMin)
            var right = xPx(workXMax)
            var top = yPx(workYMax)
            var bottom = yPx(workYMin)
            var wArea = right - left
            var hArea = bottom - top
            ctx.fillStyle = workAreaFill
            ctx.strokeStyle = workAreaStroke
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.rect(left, top, wArea, hArea)
            ctx.fill()
            ctx.stroke()
        }

        if (showAxes) {
            var arrow = 7
            var xAxisY = yPx(0)
            var xStart = xPx(visMinX)
            var xEnd = xPx(visMaxX)
            ctx.strokeStyle = axisXColor
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(xStart, xAxisY + 0.5)
            ctx.lineTo(xEnd, xAxisY + 0.5)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(xEnd, xAxisY + 0.5)
            ctx.lineTo(xEnd - arrow, xAxisY - arrow * 0.6)
            ctx.moveTo(xEnd, xAxisY + 0.5)
            ctx.lineTo(xEnd - arrow, xAxisY + arrow * 0.6)
            ctx.stroke()
            ctx.fillStyle = axisXColor
            ctx.font = "11px sans-serif"
            ctx.fillText("X", xEnd - 12, xAxisY - 8)
            //ctx.fillText("X", 0, 0)
            

            var yAxisX = xPx(0)
            var yStart = yPx(visMinY)
            var yEnd = yPx(visMaxY)
            ctx.strokeStyle = axisYColor
            ctx.beginPath()
            ctx.moveTo(yAxisX + 0.5, yStart)
            ctx.lineTo(yAxisX + 0.5, yEnd)
            ctx.stroke()
            
            var yTip = yEnd
            ctx.beginPath()
            ctx.moveTo(yAxisX + 0.5, yTip)
            ctx.lineTo(yAxisX - arrow * 0.6, yTip + arrow)
            ctx.moveTo(yAxisX + 0.5, yTip)
            ctx.lineTo(yAxisX + arrow * 0.6, yTip + arrow)
            ctx.stroke()
            ctx.fillStyle = axisYColor
            // ctx.fillText("Y", yAxisX + 8, yTip - 10)
            ctx.fillText("Y", yAxisX, yTip)
            // print(yTip, yAxisX)
        }

        ctx.lineWidth = 2
        ctx.strokeStyle = accentColor
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        if (points && points.length > 0) {
            ctx.beginPath()
            var started = false
            for (var i = 0; i < points.length; i++) {
                var q = points[i]
                if (!q || q.break) {
                    started = false
                    continue
                }
                if (!started) {
                    ctx.moveTo(q.x, q.y)
                    started = true
                } else {
                    ctx.lineTo(q.x, q.y)
                }
            }
            ctx.stroke()
        }

        ctx.restore()
    }
}
