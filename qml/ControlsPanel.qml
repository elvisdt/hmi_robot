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
    signal csvSelected(url url)
    signal robotTrajSelected(url url)
    signal robotPlay()
    signal robotStop()
    signal robotHome()
    signal robotReset()
    signal robotSpeedChanged(real factor)

    property color cardColor: palette.cardBg || "#ffffff"
    property color borderColor: palette.stroke || "#e4e8f0"
    property color titleColor: palette.text || "#0f172a"
    property color mutedColor: palette.muted || "#5f6b80"
    property color panelBg: palette.panelBg || "#f8fafc"
    property color panelBorder: palette.panelBorder || "#e5e7eb"
    property color accentText: "#ffffff"
    property string trajPathDisplay: "TrayFinal_art.csv"
    property bool ready: false
    property real robotSpeedValue: animSpeedSlider.value
    property bool robotPlaying: false

    function fileNameFromUrl(u) {
        var s = String(u || "")
        var slash = s.lastIndexOf("/")
        var back = s.lastIndexOf("\\")
        var idx = Math.max(slash, back)
        return idx >= 0 ? s.slice(idx + 1) : s
    }

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

                    Button {
                        id: loadCsvButton
                        text: "Elegir CSV/TXT trayectoria"
                        Layout.fillWidth: true
                        background: Rectangle {
                            radius: 10
                            color: accentColor
                        }
                        contentItem: Text {
                            text: loadCsvButton.text
                            font: loadCsvButton.font
                            color: accentText
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: csvDialog.open()
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Label { text: "Tolerancia:"; color: mutedColor }

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
                            text: toleranceSlider.value.toFixed(1) + " mm"
                            color: mutedColor
                            font.pixelSize: 12
                        }
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
                        spacing: 8
                        Label { text: "Velocidad:"; color: mutedColor }

                        IOSSlider {
                            id: animSpeedSlider
                            minValue: 1
                            maxValue: 10
                            step: 1
                            sliderValue: 3
                            accentColor: accentColor
                            trackColor: panelBorder
                            handleColor: cardColor
                            onValueChanged: {
                                if (panel.ready) panel.robotSpeedChanged(value)
                            }
                        }

                        Label {
                            text: "x" + animSpeedSlider.value.toFixed(1)
                            color: mutedColor
                            font.pixelSize: 12
                        }

                        
                    }

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        Button {
                            id: homingButton
                            text: "Home"
                            Layout.fillWidth: true
                            background: Rectangle {
                                radius: 10
                                color: homingButton.pressed ? Qt.darker(panelBg, 1.05): homingButton.hovered ? Qt.lighter(panelBg, 1.05) : panelBg                      
                                border.color: homingButton.hovered ? accentColor : panelBorder
                            }
                            contentItem: Text {
                                text: homingButton.text
                                font: homingButton.font
                                color: homingButton.hovered ? accentColor : titleColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: panel.robotHome()
                        }

                        Button {
                            id: resetButton
                            text: "Reset"
                            Layout.fillWidth: true
                            background: Rectangle {
                                radius: 10
                                color: resetButton.pressed ? Qt.darker(panelBg, 1.05)
                                                           : resetButton.hovered ? Qt.lighter(panelBg, 1.05)
                                                                                   : panelBg
                                border.color: resetButton.hovered ? "#f97316" : panelBorder
                            }
                            contentItem: Text {
                                text: resetButton.text
                                font: resetButton.font
                                color: resetButton.hovered ? "#d95c0e" : "#f97316"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: panel.robotReset()
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        Button {
                            id: loadTrajButton
                            text: "Cargar trayectoria"
                            Layout.fillWidth: true
                            background: Rectangle { radius: 12; color: accentColor }
                            contentItem: Text { text: loadTrajButton.text; font: loadTrajButton.font; color: accentText; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: trajDialog.open()
                        }
                        Label {
                            id: trajPathLabel
                            text: trajPathDisplay
                            color: mutedColor
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    RowLayout{
                        spacing: 8
                        Layout.fillWidth: true
                        Button {
                            id: playButton
                            text: "Play"
                            Layout.fillWidth: true
                            enabled: !panel.robotPlaying
                            opacity: enabled ? 1 : 0.6
                            background: Rectangle {
                                radius: 10
                                color: panel.robotPlaying ? Qt.darker(accentColor, 1.1)
                                                          : playButton.pressed ? Qt.darker(accentColor, 1.2)
                                                          : playButton.hovered ? Qt.lighter(accentColor, 1.1)
                                                                                : accentColor
                            }
                            contentItem: Text {
                                text: playButton.text
                                font: playButton.font
                                color: accentText
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                panel.robotPlaying = true
                                panel.robotPlay()
                            }
                        }

                        Button {
                            id: stopButton
                            text: "Stop"
                            Layout.fillWidth: true
                            enabled: panel.robotPlaying
                            opacity: enabled ? 1 : 0.5
                            background: Rectangle {
                                radius: 10
                                color: stopButton.pressed ? panelBorder : panelBg
                                border.color: stopButton.hovered ? accentColor : panelBorder
                            }
                            contentItem: Text {
                                text: stopButton.text
                                font: stopButton.font
                                color: stopButton.pressed ? accentColor : stopButton.hovered ? accentColor : titleColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                panel.robotPlaying = false
                                panel.robotStop()
                            }
                        }

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: panel.robotPlaying ? "#22c55e" : "#ef4444"
                            border.color: panelBorder
                            Layout.alignment: Qt.AlignVCenter
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
        FileDialog {
            id: csvDialog
            nameFilters: ["CSV/TXT (*.csv *.txt)", "All Files (*.*)"]
            onAccepted: panel.csvSelected(selectedFile)
        }
        FileDialog {
            id: trajDialog
            nameFilters: ["CSV/TXT (*.csv *.txt)", "All Files (*.*)"]
            onAccepted: {
                panel.trajPathDisplay = panel.fileNameFromUrl(selectedFile)
                panel.robotTrajSelected(selectedFile)
            }
        }

        Component.onCompleted: panel.ready = true
    }
}
