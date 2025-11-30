import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import component 1.0

Item {
    id: view2d
    width: 480
    height: 480

    property alias points: canvas.points
    property color accentColor: "#0a84ff"
    property bool showAxes: true
    property color axisXColor: "#ef4444"
    property color axisYColor: "#10b981"
    property real rotationDeg: 0
    property string imageSource: ""
    property bool allowImage: false
    property bool autoFitBounds: true
    property real gridStep: 50
    property real marginRatio: 0.05
    property real padFactor: 0.2
    
    property var palette: ({})
    property color cardColor: palette.cardBg || "#ffffff"
    property color borderColor: palette.stroke || "#e4e8f0"
    property color titleColor: palette.text || "#0f172a"
    property color mutedColor: palette.muted || "#5f6b80"
    property color unitColor: palette.label || "#9ca3af"
    property color canvasColor: palette.canvasBg || "#f9fafc"
    property color gridColor: palette.grid || "#e7ebf3"

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: cardColor
        border.color: borderColor
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
                    color: titleColor
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
                    color: mutedColor
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "mm"
                    color: unitColor
                    font.pixelSize: 12
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: [
                        { icon: "↺", action: function() { fitCurrent() } },
                        { icon: "+", action: function() { canvas.zoom(0.8) } },
                        { icon: "-", action: function() { canvas.zoom(1.25) } },
                        { icon: "↑", action: function() { canvas.pan(0, 50) } },
                        { icon: "↓", action: function() { canvas.pan(0, -50) } },
                        { icon: "←", action: function() { canvas.pan(-50, 0) } },
                        { icon: "→", action: function() { canvas.pan(50, 0) } }
                    ]
                    delegate: Button {
                        text: modelData.icon
                        width: 36
                        height: 36
                        font.pixelSize: 14
                        background: Rectangle {
                            radius: 9
                            color: control.pressed
                                   ? (view2d.palette.panelBg || view2d.palette.cardBg || "#e5e7eb")
                                   : (view2d.palette.cardBg || "#f5f7fb")
                            border.color: control.hovered
                                         ? view2d.accentColor
                                         : (view2d.palette.stroke || "#cbd2dd")
                            scale: control.pressed ? 0.97 : 1
                        }
                        contentItem: Text {
                            text: modelData.icon
                            anchors.centerIn: parent
                            color: view2d.accentColor
                            font.pixelSize: 14
                            font.bold: true
                        }
                        onClicked: modelData.action()
                        id: control
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: (view2d.allowImage && view2d.imageSource !== "") ? 0 : 1

                Image {
                    id: previewImage
                    source: view2d.imageSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }

                View2DCanvas {
                    id: canvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    palette: view2d.palette
                    accentColor: view2d.accentColor
                    showAxes: view2d.showAxes
                    axisXColor: view2d.axisXColor
                    axisYColor: view2d.axisYColor
                    rotationDeg: view2d.rotationDeg
                    gridStep: view2d.gridStep
                    marginRatio: view2d.marginRatio
                    padFactor: view2d.padFactor
                    canvasColor: view2d.canvasColor
                    gridColor: view2d.gridColor
                    
                }
            }
        }
    }

    function niceStep(range, targetLines) {
        if (range <= 0) return 1
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

    function setBounds(xmin, xmax, ymin, ymax) {
        if (xmin === undefined || xmax === undefined || ymin === undefined || ymax === undefined)
            return
        autoFitBounds = false
        gridStep = niceStep(Math.max(xmax - xmin, ymax - ymin), 12)
        canvas.fitToBounds(xmin, xmax, ymin, ymax)
    }

    function toFileUrl(p) {
        var s = String(p || "")
        if (s.length === 0) return ""
        if (s.startsWith("file:/")) return s
        return "file:///" + s.replace(/\\/g, "/")
    }

    function setImage(path) {
        if (!allowImage) {
            imageSource = ""
            return
        }
        imageSource = toFileUrl(path)
    }

    function setPoints(arr) {
        if (autoFitBounds && arr && arr.length > 0) {
            var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity
            for (var i = 0; i < arr.length; i++) {
                var p = arr[i]
                if (!p || p.break || p.x === undefined || p.y === undefined)
                    continue
                if (p.x < minX) minX = p.x
                if (p.x > maxX) maxX = p.x
                if (p.y < minY) minY = p.y
                if (p.y > maxY) maxY = p.y
            }
            if (minX < Infinity && minY < Infinity) {
                canvas.fitToBounds(minX, maxX, minY, maxY)
            }
        }
        if (canvas.setPoints)
            canvas.setPoints(arr)
        else
            canvas.points = arr
    }

    function fitCurrent() {
        var arr = canvas.points || []
        var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity
        for (var i = 0; i < arr.length; i++) {
            var p = arr[i]
            if (!p || p.break || p.x === undefined || p.y === undefined) continue
            if (p.x < minX) minX = p.x
            if (p.x > maxX) maxX = p.x
            if (p.y < minY) minY = p.y
            if (p.y > maxY) maxY = p.y
        }
        if (minX < Infinity) {
            canvas.fitToBounds(minX, maxX, minY, maxY)
        } else {
            // reset fijo
            canvas.fitToBounds(-300, 300, -300, 300)
        }
    }
}
