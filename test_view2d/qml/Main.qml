import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: root
    visible: true
    width: 1200
    height: 800
    title: "Visor DXF 2D - RoboticHMI"

    FileDialog {
        id: fileDialog
        nameFilters: ["Archivos DXF (*.dxf)", "Archivos CSV (*.csv)", "Todos (*.*)"]
        onAccepted: backend.loadFile(selectedFile)
    }

    // Contenedor con margenes manuales (compatible con todas las versiones de Qt/PySide6)
    Item {
        anchors.fill: parent
        anchors.margins: 8

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Button {
                    text: "Cargar archivo DXF/CSV"
                    onClicked: fileDialog.open()
                }

                Button {
                    text: "Centrar Vista"
                    onClicked: canvas.fitView()
                }

                Button {
                    text: "Limpiar"
                    onClicked: canvas.points = []
                }

                Label {
                    text: canvas.points.length + " puntos"
                    color: "#555"
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            View2DCanvas {
                id: canvas
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Connections {
        target: backend

        function onPointsReady(pts) {
            console.log("Main.qml: Recibidos", pts.length, "puntos")
            canvas.points = pts
            canvas.fitView()
        }

        function onStatusMessage(msg) {
            console.log("Status:", msg)
            errorDialog.text = msg
            errorDialog.open()
        }
    }

    MessageDialog {
        id: errorDialog
        title: "Visor DXF 2D - RoboticHMI"
    }
}
