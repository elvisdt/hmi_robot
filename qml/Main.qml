import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick3D
import component 1.0

ApplicationWindow {
    id: app
    visible: true
    width: 1200
    height: 800
    title: "Interfaz de control del Robot"
    property bool darkMode: true
    property var basePalette: ({
        windowBg: "#f5f7fb",
        cardBg: "#ffffff",
        stroke: "#e4e8f0",
        text: "#0f172a",
        muted: "#5f6b80",
        accent: "#0a84ff",
        panelBg: "#f8fafc",
        panelBorder: "#e5e7eb",
        canvasBg: "#f9fafc",
        grid: "#e7ebf3",
        label: "#9ca3af"
    })
    property var palette: {
        var p = darkMode ? (Theme ? Theme.dark : null) : (Theme ? Theme.light : null)
        return p ? p : basePalette
    }
    color: palette.windowBg

    property color accentColor: palette.accent || basePalette.accent
    property color cardColor: palette.cardBg || basePalette.cardBg
    property color mutedText: palette.muted || basePalette.muted
    property color strokeColor: palette.stroke || basePalette.stroke
    property color textColor: palette.text || basePalette.text

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
            color: cardColor
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
                color: textColor
                Layout.alignment: Qt.AlignVCenter
            }

            Label {
                text: "Robot SCARA"
                color: mutedText
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Label {
                text: darkMode ? "Modo oscuro" : "Modo claro"
                color: mutedText
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }
            IOSwitch {
                checked: darkMode
                onCheckedChanged: app.darkMode = checked
            }
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
                        palette: app.palette
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
                        palette: app.palette
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
                        palette: app.palette
                    }
                }
            }
        }
    }



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
