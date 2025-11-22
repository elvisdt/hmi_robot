import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Pane {
    id: panel
    width: 240
    padding: 0
    property color accentColor: "#0a84ff"
    signal dxfSelected(url url)

    background: Rectangle {
        radius: 20
        color: "#ffffff"
        border.color: "#e4e8f0"
    }

    ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Item {
            width: scrollArea.availableWidth

            ColumnLayout {
                x: 18
                width: scrollArea.availableWidth - 36
                spacing: 14

                Label {
                    text: "Panel de control"
                    font.pixelSize: 20
                    font.bold: true
                    font.family: "SF Pro Display"
                    color: "#0f172a"
                    Layout.bottomMargin: 4
                }

                // === PANEL CAD ===
                Frame {
                    Layout.fillWidth: true
                    padding: 14
                    background: Rectangle {
                        radius: 18
                        color: "#f9fafc"
                        border.color: "#e8ecf5"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        Label {
                            text: "Importar CAD"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#101828"
                        }

                        Label {
                            text: "Carga un DXF para visualizar el plano 2D."
                            color: "#667085"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Button {
                            id: loadDxfButton
                            text: "Elegir DXF"
                            Layout.fillWidth: true
                            background: Rectangle {
                                radius: 14
                                color: accentColor
                            }
                            contentItem: Text {
                                text: loadDxfButton.text
                                font: loadDxfButton.font
                                color: "#ffffff"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: dxfDialog.open()
                        }

                        CheckBox {
                            text: "Auto-centrar dibujo al cargar"
                            checked: true
                        }
                    }
                }

                // === PANEL PROCESAMIENTO ===
                Frame {
                    Layout.fillWidth: true
                    padding: 14
                    background: Rectangle {
                        radius: 18
                        color: "#ffffff"
                        border.color: "#e7eaf2"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "Procesamiento"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#101828"
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Item { Layout.fillWidth: true }
                            Switch {
                                checked: true
                                text: "Optimizar trayectorias"
                            }
                        }

                        Label {
                            text: "Tolerancia de muestreo"
                            color: "#4b5563"
                        }

                        Slider {
                            id: toleranceSlider
                            from: 0
                            to: 5
                            value: 1
                            stepSize: 0.1
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Tolerancia: " + toleranceSlider.value.toFixed(1) + " mm"
                            color: "#334155"
                            font.pixelSize: 12
                        }

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Button {
                                id: previewButton
                                text: "Previsualizar"
                                Layout.fillWidth: true
                                background: Rectangle {
                                    radius: 12
                                    color: "#e7f0ff"
                                    border.color: accentColor
                                }
                                contentItem: Text {
                                    text: previewButton.text
                                    font: previewButton.font
                                    color: accentColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Button {
                                id: exportButton
                                text: "Exportar G-code"
                                Layout.fillWidth: true
                                background: Rectangle {
                                    radius: 12
                                    color: accentColor
                                }
                                contentItem: Text {
                                    text: exportButton.text
                                    font: exportButton.font
                                    color: "#ffffff"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                // === PANEL ROBOT ===
                Frame {
                    Layout.fillWidth: true
                    padding: 14
                    background: Rectangle {
                        radius: 18
                        color: "#ffffff"
                        border.color: "#e7eaf2"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "Robot"
                                font.pixelSize: 16
                                font.bold: true
                                color: "#101828"
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Item { Layout.fillWidth: true }
                            Switch {
                                text: "Modo seguro"
                                checked: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Velocidad"; color: "#4b5563" }
                            Item { Layout.fillWidth: true }
                            Label { text: speedSlider.value.toFixed(1) + " m/s"; color: "#111827" }
                        }

                        Slider {
                            id: speedSlider
                            from: 0.1
                            to: 5
                            value: 1
                            stepSize: 0.1
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Button {
                                id: homingButton
                                text: "Homing"
                                Layout.fillWidth: true
                                background: Rectangle {
                                    radius: 12
                                    color: "#e7f0ff"
                                    border.color: accentColor
                                }
                                contentItem: Text {
                                    text: homingButton.text
                                    font: homingButton.font
                                    color: accentColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            Button {
                                id: resetButton
                                text: "Reset"
                                Layout.preferredWidth: 110
                                background: Rectangle {
                                    radius: 12
                                    color: "#fde8e6"
                                    border.color: "#f2b6b0"
                                }
                                contentItem: Text {
                                    text: resetButton.text
                                    font: resetButton.font
                                    color: "#7a271a"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        FileDialog {
            id: dxfDialog
            nameFilters: ["DXF Files (*.dxf)", "All Files (*.*)"]
            onAccepted: panel.dxfSelected(selectedFile)
        }
    }
}
