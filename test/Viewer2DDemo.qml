import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../qml"

ApplicationWindow {
    id: app
    visible: true
    width: 520
    height: 600
    title: "Demo Viewer2D"

    Viewer2D {
        id: viewer
        anchors.fill: parent
        anchors.margins: 12
        accentColor: "#0a84ff"
    }

    Component.onCompleted: {
        var w = viewer.width
        var h = viewer.height
        var m = 60
        var pts = [
            { x: m,     y: h/2 },
            { x: w/2,   y: m },
            { x: w - m, y: h/2 },
            { x: w/2,   y: h - m },
            { x: m,     y: h/2 }
        ]
        viewer.setPoints(pts)
    }
}
