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
                text: "Interfaz de control"
                font.pixelSize: 22
                font.bold: true
                font.family: "SF Pro Display"
                color: "#0f172a"
                Layout.alignment: Qt.AlignVCenter
            }

            Label {
                text: "Robot SCARA"
                color: mutedText
                font.pixelSize: 14
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

            ControlsPanel {
                id: controlsPanel
                SplitView.preferredWidth: 360   // ~1 part
                SplitView.minimumWidth: 320
                SplitView.maximumWidth: 420
                Layout.fillHeight: true
                accentColor: app.accentColor
                onDxfSelected: function(fileUrl) { loadDxfFile(fileUrl) }
            }

            Rectangle {
                color: "transparent"
                SplitView.fillWidth: true      // ~4 parts
                SplitView.preferredWidth: 1040

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 14

                        Viewer2D {
                            id: viewer2d
                            objectName: "viewer2d"
                            Layout.fillWidth: true   // ~2 parts
                            Layout.fillHeight: true
                            Layout.minimumWidth: 400
                            Layout.minimumHeight: 360
                            Layout.preferredWidth: 520
                            Layout.preferredHeight: 520
                            Layout.maximumWidth: 600
                            accentColor: app.accentColor
                        }

                        RobotView {
                            id: robotView
                            objectName: "robotView"
                            Layout.fillWidth: true   // ~2 parts
                            Layout.fillHeight: true
                            Layout.minimumWidth: 400
                            Layout.minimumHeight: 360
                            Layout.preferredWidth: 520
                            Layout.preferredHeight: 520
                            Layout.maximumWidth: 700
                            accentColor: app.accentColor
                        }
                    }

                    RowLayout {
                        spacing: 10
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        Layout.minimumWidth: 360

                        Button {
                            id: playButton
                            text: "Play"
                            Layout.preferredWidth: 110
                            background: Rectangle {
                                radius: 14
                                color: accentColor
                            }
                            contentItem: Text {
                                text: playButton.text
                                font: playButton.font
                                color: "#ffffff"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Button {
                            id: pauseButton
                            text: "Pausa"
                            Layout.preferredWidth: 110
                            background: Rectangle {
                                radius: 14
                                color: "#dfe3ec"
                            }
                            contentItem: Text {
                                text: pauseButton.text
                                font: pauseButton.font
                                color: "#0f172a"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Button {
                            id: stopButton
                            text: "Stop"
                            Layout.preferredWidth: 110
                            background: Rectangle {
                                radius: 14
                                color: "#f4c7c3"
                            }
                            contentItem: Text {
                                text: stopButton.text
                                font: stopButton.font
                                color: "#0f172a"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
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
