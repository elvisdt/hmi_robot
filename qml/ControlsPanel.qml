
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "component"
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects // <--- IMPORTANTE en PySide6

Item {
    
    id: panel
    width: 280
    property color accentColor: "#0a84ff"
    signal dxfSelected(url url)

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "#ffffff"
        border.color: "#e4e8f0"
        clip: true


        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label {
                    text: "Panel de Control"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#0f172a"
                }
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: accentColor
                    Layout.alignment: Qt.AlignVCenter
                }
                // Label {
                //     text: "Trayectoria"
                //     color: "#5f6b80"
                //     font.pixelSize: 12
                // }
            }

            // ========================
            //       PANEL CAD
            // ========================
            Frame {
                Layout.fillWidth: true
                padding: 12
                background: Rectangle {
                    radius: 15
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
                        text: "Carga un DXF y visualizar el plano 2D."
                        color: "#667085"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        id: loadDxfButton
                        text: "Elegir DXF"
                        Layout.fillWidth: true
                        background: Rectangle {
                            radius: 10
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

                    // CheckBox {
                    //     text: "Auto-centrar dibujo al cargar"
                    //     checked: true
                    // }
                    CheckBox {
                        id: autoCenterCheck
                        text: "Auto-centrar dibujo al cargar"
                        checked: true

                        contentItem: Text {
                            text: autoCenterCheck.text
                            color: "#101828"       // <- AQUÍ EL COLOR
                            // font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: autoCenterCheck.indicator.width + 6
                        }

                        indicator: Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 6
                            border.color: autoCenterCheck.checked ? "#0a84ff" : "#c7cdd6"
                            border.width: 2
                            color: autoCenterCheck.checked ? "#0a84ff" : "#ffffff"

                            // el check ✓
                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)

                                    if (autoCenterCheck.checked) {
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
                    }

                }
            }

            // ============================
            //     PANEL PROCESAMIENTO
            // ============================
            Frame {
                Layout.fillWidth: true
                padding: 12
                background: Rectangle {
                    radius: 15
                    color: "#ffffff"
                    border.color: "#e7eaf2"
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Procesamiento"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#101828"
                        }
                        Item { Layout.fillWidth: true }

                        IOSwitch {
                            text: "Optimizar"
                            checked: true
                        }
                    }

                    Label {
                        text: "Tolerancia de muestreo"
                        color: "#4b5563"
                    }

                    IOSSlider {
                        id: toleranceSlider

                        minValue: 0
                        maxValue: 5
                        step: 0.1
                        sliderValue: 1

                        // accentColor: "#22c55e"
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
                                radius: 10
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
                                radius: 10
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

            // ============================
            //        PANEL ROBOT
            // ============================
            Frame {
                Layout.fillWidth: true
                padding: 10
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
                        }
                        Item { Layout.fillWidth: true }

                        IOSwitch {
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


                    IOSSlider {
                        id: speedSlider

                        minValue: 0.1
                        maxValue: 5
                        step: 0.1
                        sliderValue: 1

                    }

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        Button {
                            id: homingButton
                            text: "Home"
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

        // === File Dialog ===
        FileDialog {
            id: dxfDialog
            nameFilters: ["DXF Files (*.dxf)", "All Files (*.*)"]
            onAccepted: panel.dxfSelected(selectedFile)
        }
    }
}
