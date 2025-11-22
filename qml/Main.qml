import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick3D

ApplicationWindow {
    id: app
    visible: true
    width: 1200
    height: 800
    title: "Interfaz de control del Robot"
    color: "#f5f7fb"

    property color accentColor: "#0a84ff"
    property color cardColor: "#ffffff"
    property color mutedText: "#5f6b80"
    property color strokeColor: "#e4e8f0"

    // Recibe señales desde backend Python para poblar vistas
    Connections {
        target: backend
        function onPointsReady(points) {
            viewer2d.setPoints(points)
        }
        function onStatusMessage(text) {
            console.log(text)
        }
    }

    header: ToolBar {
        contentHeight: 68
        padding: 12
        background: Rectangle {
            color: "#ffffff"
            border.color: strokeColor
        }
        RowLayout {
            anchors.fill: parent
            spacing: 10
            
            Label {
                padding: 10
                text: "Interfaz de control"
                font.pixelSize: 20
                font.bold: true
                font.family: "SF Pro Display"
                color: "#0f172a"
                Layout.alignment: Qt.AlignVCenter
            }

            Label {
                text: "Robot SCARA"
                color: mutedText
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // RoundButton {
            //     id: addButton
            //     text: "+"
            //     font.pixelSize: 18
            //     implicitWidth: 42
            //     implicitHeight: 42
            //     Layout.alignment: Qt.AlignVCenter
            //     background: Rectangle {
            //         radius: height / 2
            //         color: accentColor
            //     }
            //     contentItem: Text {
            //         text: addButton.text
            //         font: addButton.font
            //         color: "#ffffff"
            //         horizontalAlignment: Text.AlignHCenter
            //         verticalAlignment: Text.AlignVCenter
            //     }
            //     onClicked: importClicked()
            // }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 16
        color: "transparent"

        
        SplitView {
            id: mainSplit
            anchors.fill: parent
            spacing: 8
            orientation: Qt.Horizontal
            handle: Rectangle {
                implicitWidth: 6
                radius: 3
                color: "#dfe4ee"
            }


            // ================= CENTRO + DERECHA (contenedor) ==================
            Rectangle {
                color: "transparent"
                SplitView.preferredWidth: 8      // ← 2 partes + 2 partes
                SplitView.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 14

                    
                    ControlsPanel {
                        id: controlsPanel
                        objectName: "ControlsPanel"
                        SplitView.preferredWidth: 2
                        Layout.fillHeight: true
                        accentColor: app.accentColor
                        onDxfSelected: function(fileUrl) { loadDxfFile(fileUrl) }
                    }

                    // ======================== VISTA 2D ========================
                    Viewer2D {
                        id: viewer2d
                        objectName: "viewer2d"
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: 3    // ← 2 partes
                        Layout.minimumWidth: 350
                        Layout.minimumHeight: 360
                        accentColor: app.accentColor
                    }

                    // ======================== VISTA 3D ========================
                    RobotView {
                        id: robotView
                        objectName: "robotView"
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: 3    // ← 2 partes
                        Layout.minimumWidth: 350
                        Layout.minimumHeight: 360
                        accentColor: app.accentColor
                    }
                }
            }
        }
    }

    // function importClicked() {
    //     console.log("Importar archivo CAD")
    // }

    function loadDxfFile(url) {
        if (!url || url.toString().length === 0)
            return
        console.log("DXF seleccionado:", url)
        if (backend && backend.loadDxf) {
            backend.loadDxf(url, viewer2d.width, viewer2d.height)
        } else {
            viewer2d.setPoints([])
        }
    }

    Component.onCompleted: viewer2d.setPoints([])
}
