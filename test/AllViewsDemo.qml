import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../qml"

ApplicationWindow {
    id: app
    visible: true
    width: 1400
    height: 820
    title: "Demo Todas las Vistas"

    header: ToolBar {
        contentHeight: 56
        RowLayout {
            anchors.fill: parent
            spacing: 10
            Label {
                text: "Demo de UI"
                font.pixelSize: 20
                font.bold: true
                color: "#0f172a"
            }
            Label {
                text: "Controls + Plano 2D + Robot 3D"
                color: "#5f6b80"
            }
        }
    }

    SplitView {
        anchors.fill: parent
        spacing: 12

        ControlsPanel {
            SplitView.preferredWidth: 360
            SplitView.minimumWidth: 320
            accentColor: "#0a84ff"
        }

        ColumnLayout {
            SplitView.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Viewer2D {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 400
                    Layout.minimumHeight: 360
                    accentColor: "#0a84ff"
                }

                RobotView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 400
                    Layout.minimumHeight: 360
                    accentColor: "#0a84ff"
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Button { text: "Play" }
                Button { text: "Pausa" }
                Button { text: "Stop" }
            }
        }
    }
}
