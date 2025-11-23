import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: view2d
    width: 480
    height: 480

    property var points: []
    property color accentColor: "#0a84ff"
    property bool showAxes: true
    property color axisXColor: "#ef4444"
    property color axisYColor: "#10b981"
    property real rotationDeg: -90   // rota el plano: -90 => X hacia arriba, Y hacia la izquierda
    property real worldXMin: 0
    property real worldXMax: 600
    property real worldYMin: -600
    property real worldYMax: 600
    property real gridStep: 100
    property real marginRatio: 0.08    // debe coincidir con backend.margin_ratio

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "#ffffff"
        border.color: "#e4e8f0"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label {
                    text: "Plano 2D"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#0f172a"
                }
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: accentColor
                    Layout.alignment: Qt.AlignVCenter
                }
                Label {
                    text: "Trayectoria"
                    color: "#5f6b80"
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "mm"
                    color: "#9ca3af"
                    font.pixelSize: 12
                }
            }

            Canvas {
                id: canvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                antialiasing: true

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "#f9fafc"
                    ctx.fillRect(0, 0, width, height)

                    // ajustar rotacion y escala para que el contenido rote sin recortes
                    var angle = view2d.rotationDeg * Math.PI / 180
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
                    var margin = Math.min(width, height) * view2d.marginRatio
                    var innerW = width - 2 * margin
                    var innerH = height - 2 * margin
                    var rangeX = Math.max(view2d.worldXMax - view2d.worldXMin, 1e-6)
                    var rangeY = Math.max(view2d.worldYMax - view2d.worldYMin, 1e-6)
                    var scale = Math.min(innerW / rangeX, innerH / rangeY)
                    var extraX = Math.max(0, (innerW - rangeX * scale) / 2)
                    var extraY = Math.max(0, (innerH - rangeY * scale) / 2)
                    function xPx(wx) { return margin + extraX + (wx - view2d.worldXMin) * scale }
                    function yPx(wy) { return margin + extraY + (view2d.worldYMax - wy) * scale }

                    function invX(px) { return (px - margin - extraX) / scale + view2d.worldXMin }
                    function invY(py) { return view2d.worldYMax - (py - margin - extraY) / scale }

                    // grid con etiquetas en mm (constante, extendido a toda el area visible)
                    ctx.strokeStyle = "#e7ebf3"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    var step = view2d.gridStep
                    var visMinX = Math.min(view2d.worldXMin, view2d.worldXMax, invX(0), invX(width))
                    var visMaxX = Math.max(view2d.worldXMin, view2d.worldXMax, invX(0), invX(width))
                    var visMinY = Math.min(view2d.worldYMin, view2d.worldYMax, invY(0), invY(height))
                    var visMaxY = Math.max(view2d.worldYMin, view2d.worldYMax, invY(0), invY(height))
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

                    ctx.fillStyle = "#9ca3af"
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

                    if (view2d.showAxes) {
                        var arrow = 7
                        var xAxisY = yPx(0)
                        var xStart = xPx(view2d.worldXMin)
                        var xEnd = xPx(view2d.worldXMax)
                        ctx.strokeStyle = view2d.axisXColor
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
                        ctx.fillStyle = view2d.axisXColor
                        ctx.font = "11px sans-serif"
                        ctx.fillText("X", xEnd - 12, xAxisY - 8)

                        var yAxisX = xPx(0)
                        var yStart = yPx(view2d.worldYMin)
                        var yEnd = yPx(view2d.worldYMax)
                        ctx.strokeStyle = view2d.axisYColor
                        ctx.beginPath()
                        ctx.moveTo(yAxisX + 0.5, yStart)
                        ctx.lineTo(yAxisX + 0.5, yEnd)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(yAxisX + 0.5, yEnd)
                        ctx.lineTo(yAxisX - arrow * 0.6, yEnd - arrow)
                        ctx.moveTo(yAxisX + 0.5, yEnd)
                        ctx.lineTo(yAxisX + arrow * 0.6, yEnd - arrow)
                        ctx.stroke()
                        ctx.fillStyle = view2d.axisYColor
                        ctx.fillText("Y", yAxisX + 8, yEnd - 10)
                    }

                    ctx.lineWidth = 2
                    ctx.strokeStyle = accentColor
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    if (view2d.points && view2d.points.length > 0) {
                        ctx.beginPath()
                        var started = false
                        for (var i = 0; i < view2d.points.length; i++) {
                            var q = view2d.points[i]
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
        }
    }

    function setPoints(arr) {
        points = arr
        canvas.requestPaint()
    }
}
