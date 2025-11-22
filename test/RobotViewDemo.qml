import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../qml"

ApplicationWindow {
    id: app
    visible: true
    width: 900
    height: 700
    title: "Demo RobotView"

    RobotView {
        anchors.fill: parent
        anchors.margins: 12
    }
}
