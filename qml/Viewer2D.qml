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
    property real rotationDeg: -90   // rota el plano: -90 => X hacia arriba, Y hacia la izquierda
    property real worldXMin: -100
    property real worldXMax: 1000
    property real worldYMin: -800
    property real worldYMax: 800
    property real gridStep: 100
    property real marginRatio: 0.08    // debe coincidir con backend.margin_ratio
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
                worldXMin: view2d.worldXMin
                worldXMax: view2d.worldXMax
                worldYMin: view2d.worldYMin
                worldYMax: view2d.worldYMax
                gridStep: view2d.gridStep
                marginRatio: view2d.marginRatio
                unitColor: view2d.unitColor
                canvasColor: view2d.canvasColor
                gridColor: view2d.gridColor
            }
        }
    }

    function setPoints(arr) {
        canvas.setPoints(arr)
    }
}
