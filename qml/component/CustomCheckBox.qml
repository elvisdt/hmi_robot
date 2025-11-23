import QtQuick
import QtQuick.Controls

CheckBox {
    id: root
    property var palette: ({})
    property color accentColor: palette.accent || "#0a84ff"
    property color labelColor: palette.text || "#0f172a"
    property color borderColor: palette.panelBorder || "#e5e7eb"
    property color bgColor: palette.cardBg || "#ffffff"

    implicitHeight: Math.max(indicator.implicitHeight, contentItem.implicitHeight)

    indicator: Rectangle {
        implicitWidth: 22
        implicitHeight: 22
        radius: 6
        border.color: root.checked ? root.accentColor : root.borderColor
        border.width: 2
        color: root.checked ? root.accentColor : root.bgColor

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (root.checked) {
                    ctx.strokeStyle = "#ffffff"
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(width * 0.25, height * 0.55)
                    ctx.lineTo(width * 0.45, height * 0.75)
                    ctx.lineTo(width * 0.78, height * 0.3)
                    ctx.stroke()
                }
            }
        }
    }

    contentItem: Text {
        text: root.text
        color: root.labelColor
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        leftPadding: root.indicator.width + 6
    }
}
