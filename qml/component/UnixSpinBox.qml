import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property int decimals: 0
    property bool editable: true

    signal valueEdited(real newValue)

    width: 100
    height: 28

    function clamp(v) {
        return Math.min(root.to, Math.max(root.from, v))
    }

    function format(v) {
        var factor = Math.pow(10, root.decimals)
        return (Math.round(v * factor) / factor).toFixed(root.decimals)
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "#0f172a"
        border.color: "#1f2937"

        RowLayout {
            anchors.fill: parent
            anchors.margins:2 
            spacing: 2

            ToolButton {
                text: "-"
                font.pixelSize: 12
                Layout.preferredWidth: 22
                Layout.fillHeight: true
                onClicked: {
                    root.value = root.clamp(root.value - root.step)
                    input.text = root.format(root.value)
                    root.valueEdited(root.value)
                }
            }

            TextField {
                id: input
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
                font.family: "Consolas"
                color: "#e5e7eb"
                selectByMouse: true
                enabled: editable
                text: root.format(root.value)
                background: Rectangle {
                    radius: 4
                    color: "#111827"
                    border.color: "#1f2937"
                }

                onEditingFinished: {
                    var parsed = Number(text)
                    if (!isNaN(parsed)) {
                        root.value = root.clamp(parsed)
                    }
                    text = root.format(root.value)
                    root.valueEdited(root.value)
                }
            }

            ToolButton {
                text: "+"
                font.pixelSize: 12
                Layout.preferredWidth: 22
                Layout.fillHeight: true
                onClicked: {
                    root.value = root.clamp(root.value + root.step)
                    input.text = root.format(root.value)
                    root.valueEdited(root.value)
                }
            }
        }
    }

    onValueChanged: {
        input.text = root.format(root.value)
    }
}
