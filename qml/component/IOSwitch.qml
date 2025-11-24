import QtQuick
import QtQuick.Controls

Switch {
    id: root
    property color trackOn: "#0a84ff"
    property color trackOff: "#c7ccd6"
    property color thumbColor: "#ffffff"
    property color textColor: "#0f172a"

    width: implicitWidth
    height: Math.max(indicator.height, contentItem.implicitHeight)

    indicator: Rectangle {
        id: track
        width: 36
        height: 20
        radius: height / 2
        color: root.checked ? root.trackOn : root.trackOff

        Rectangle {
            id: thumb
            width: 18
            height: 18
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 1 : 1
            color: root.thumbColor

            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.InOutQuad }
            }
        }
    }

    contentItem: Text {
        text: root.text
        color: root.textColor
        font.pixelSize: 10
        verticalAlignment: Text.AlignVCenter
        leftPadding: track.width + 5
    }
}
