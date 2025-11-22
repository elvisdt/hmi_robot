import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: view2d
    width: 480
    height: 480

    property var points: []
    property color accentColor: "#0a84ff"

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

                    // grid
                    ctx.strokeStyle = "#e7ebf3"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    var step = 40
                    for (var x = 0; x < width; x += step) {
                        ctx.moveTo(x + 0.5, 0)
                        ctx.lineTo(x + 0.5, height)
                    }
                    for (var y = 0; y < height; y += step) {
                        ctx.moveTo(0, y + 0.5)
                        ctx.lineTo(width, y + 0.5)
                    }
                    ctx.stroke()

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
                }
            }
        }
    }

    function setPoints(arr) {
        points = arr
        canvas.requestPaint()
    }
}
