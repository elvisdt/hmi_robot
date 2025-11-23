import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import component 1.0

Item {
    id: panel
    width: 280
    property color accentColor: "#0a84ff"
    property var palette: ({})
    signal dxfSelected(url url)

    property color cardColor: palette.cardBg || "#ffffff"
    property color borderColor: palette.stroke || "#e4e8f0"
    property color titleColor: palette.text || "#0f172a"
    property color mutedColor: palette.muted || "#5f6b80"
    property color panelBg: palette.panelBg || "#f8fafc"
    property color panelBorder: palette.panelBorder || "#e5e7eb"
    property color accentText: "#ffffff"

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: cardColor
        border.color: borderColor
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
                    color: titleColor
                }
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: accentColor
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Frame {
                Layout.fillWidth: true
                padding: 12
                background: Rectangle {
                    radius: 15
                    color: panelBg
                    border.color: panelBorder
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Label {
                        text: "Importar CAD"
                        font.pixelSize: 16
                        font.bold: true
                        color: titleColor
                    }

                    Label {
                        text: "Carga un DXF y visualizar el plano 2D."
                        color: mutedColor
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
                            color: accentText
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: dxfDialog.open()
                    }

                    // CustomCheckBox {
                    //     id: autoCenterCheck
                    //     text: "Auto-centrar"
                    //     checked: true
                    //     palette: panel.palette
                    //     accentColor: panel.accentColor
                    // }
                }
            }

            Frame {
                Layout.fillWidth: true
                padding: 12
                background: Rectangle {
                    radius: 15
                    color: panelBg
                    border.color: panelBorder
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
                            color: titleColor
                        }
                        Item { Layout.fillWidth: true }

                        IOSwitch {
                            text: "Optimizar"
                            checked: true
                            textColor: mutedColor
                            trackOn: accentColor
                            trackOff: panelBorder
                        }
                    }

                    Label {
                        text: "Tolerancia de muestreo"
                        color: mutedColor
                    }

                    IOSSlider {
                        id: toleranceSlider
                        minValue: 0
                        maxValue: 5
                        step: 0.1
                        sliderValue: 1
                        accentColor: accentColor
                        trackColor: panelBorder
                        handleColor: cardColor
                    }

                    Label {
                        text: "Tolerancia: " + toleranceSlider.value.toFixed(1) + " mm"
                        color: mutedColor
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
                                color: panelBg
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
                                color: accentText
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                padding: 10
                background: Rectangle {
                    radius: 18
                    color: panelBg
                    border.color: panelBorder
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
                            color: titleColor
                        }
                        Item { Layout.fillWidth: true }

                        IOSwitch {
                            text: "Modo seguro"
                            checked: true
                            textColor: mutedColor
                            trackOn: accentColor
                            trackOff: panelBorder
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Velocidad"; color: mutedColor }
                        Item { Layout.fillWidth: true }
                        Label { text: speedSlider.value.toFixed(1) + " m/s"; color: titleColor }
                    }

                    IOSSlider {
                        id: speedSlider
                        minValue: 0.1
                        maxValue: 5
                        step: 0.1
                        sliderValue: 1
                        accentColor: accentColor
                        trackColor: panelBorder
                        handleColor: cardColor
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
                                color: panelBg
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
                                color: panelBg
                                border.color: "#f2b6b0"
                            }
                            contentItem: Text {
                                text: resetButton.text
                                font: resetButton.font
                                color: "#f97316"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
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
