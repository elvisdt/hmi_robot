import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../qml"

ApplicationWindow {
    id: app
    visible: true
    width: 420
    height: 720
    title: "Demo ControlsPanel"

    ControlsPanel {
        anchors.fill: parent
        anchors.margins: 12
        accentColor: "#0a84ff"
    }
}
