import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers
import component 1.0

Item {
    id: root
    width: 720
    height: 480
    property color accentColor: "#0a84ff"
    property var palette: ({})
    // Ajustes de camara
    // property real camDistance: 220
    // property real camHeight: 70      // usado como altura objetivo (centro de mirada)
    // property real camYaw: 120
    // property real camTilt: 3
    // property real camFov: 38
    // property real camTargetX: 75      // desplaza el objetivo en X


    property real camDistance: 2500
    property real camHeight: 250      
    property real camYaw: -45
    property real camTilt: 20
    property real camFov: 20
    property real camTargetX: -800      


    property real movdistance1: 4
    property real angrotacion1: 0
    property real angrotacion2: 0

    property color cardColor: palette.cardBg || "#ffffff"
    property color borderColor: palette.stroke || "#e4e8f0"
    property color textColor: palette.text || "#0f172a"
    property color mutedColor: palette.muted || "#5f6b80"
    property color panelBg: palette.panelBg || "#f8fafc"
    property color panelBorder: palette.panelBorder || "#e5e7eb"
    property color canvasBg: palette.canvasBg || "#f9fafc"
    property bool showMarkers: true
    property var markers: []          // [{x:..., y:..., z:..., color: "#rrggbb"}]
    property real markerSize: 6
    property color markerColor: palette.accent || accentColor

    function updateCamera() {
        var yawRad = root.camYaw * Math.PI / 180
        var pitchRad = root.camTilt * Math.PI / 180
        var r = root.camDistance
        var targetX = root.camTargetX
        var targetY = root.camHeight
        var targetZ = 0

        var x = targetX + r * Math.sin(yawRad) * Math.cos(pitchRad)
        var y = targetY + r * Math.sin(pitchRad)
        var z = targetZ + r * Math.cos(yawRad) * Math.cos(pitchRad)

        camera.position = Qt.vector3d(x, y, z)
        camera.lookAt(Qt.vector3d(targetX, targetY, targetZ))
    }

    onCamYawChanged: updateCamera()
    onCamTiltChanged: updateCamera()
    onCamDistanceChanged: updateCamera()
    onCamHeightChanged: updateCamera()
    onCamTargetXChanged: updateCamera()
    Component.onCompleted: updateCamera()


    Rectangle {
        anchors.fill: parent
        radius: 20
        color: cardColor
        border.color: borderColor
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // 1: hedear title 
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label {
                    text: "Robot 3D"
                    font.pixelSize: 16
                    font.bold: true
                    color: textColor
                }
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: accentColor
                    Layout.alignment: Qt.AlignVCenter
                }
                Label {
                    text: "Vista interactiva"
                    color: mutedColor
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    radius: 12
                    height: 28
                    width: 120
                    color: panelBg
                    border.color: panelBorder
                    Label {
                        anchors.centerIn: parent
                        text: "FOV " + Math.round(root.camFov) + " deg"
                        color: mutedColor
                        font.pixelSize: 12
                    }
                }
            }

            // 2: matrix and slider section
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                // future matrix
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: 10
                    color: panelBg
                    border.color: panelBorder
                    border.width: 1
                }

                // slider secction
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: 10
                    color: panelBg
                    border.color: panelBorder
                    border.width: 1

                    // columnas title
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins:5
                        spacing: 5

                        // title
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "Mover robot"
                                color: textColor
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: "Control manual"
                                color: mutedColor
                                font.pixelSize: 10
                            }
                        }

                        // desplazamiento 1
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "D1:"; color: mutedColor; font.pixelSize: 11;  Layout.preferredWidth: 16}
                                Label { text: Math.round(movSlider.value) + " mm"; color: textColor; font.pixelSize: 12; Layout.preferredWidth: 40 }
                                Item { Layout.fillWidth: true }
                                IOSSlider{
                                    id: movSlider
                                    minValue: 0
                                    maxValue: 40
                                    step: 1
                                    value: movdistance1 * 10   // usamos escala x10 para permitir 0.1 mm
                                    onMoved: movdistance1 = value / 10
                                    Layout.preferredWidth: 100 
                                }
                            }
    

                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "R1:"; color: mutedColor; font.pixelSize: 11; Layout.preferredWidth: 16}
                                Label { text: Math.round(angrotacion1) + "°"; color: textColor; font.pixelSize: 11; Layout.preferredWidth: 30 }
                                Item { Layout.fillWidth: true }
                                IOSSlider{
                                    id: rot1Slider
                                    minValue: -90
                                    maxValue: 90
                                    sliderValue: 1
                                    value: angrotacion1
                                    onMoved: angrotacion1 = value
                                    Layout.preferredWidth: 100
                                }
                            }



                            
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "R2:"; color: mutedColor; font.pixelSize: 11;Layout.preferredWidth: 16 }
                                Label { text: Math.round(angrotacion2) + "°"; color: textColor; font.pixelSize: 12; Layout.preferredWidth: 30 }
                                Item { Layout.fillWidth: true }
                                IOSSlider{
                                    id: rot2Slider
                                    minValue: -150
                                    maxValue: 150
                                    sliderValue: 1
                                    value: angrotacion2
                                    onMoved: angrotacion2 = value
                                    Layout.preferredWidth: 100
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                

                // Layout.preferredHeight: 300
                radius: 12
                color: panelBg
                border.color: panelBorder
                border.width: 1

                View3D {
                    anchors.fill: parent

                    anchors.margins: 6
                    environment: SceneEnvironment {
                        clearColor: canvasBg
                        backgroundMode: SceneEnvironment.Color
                        antialiasingMode: SceneEnvironment.MSAA
                        antialiasingQuality: SceneEnvironment.Medium
                    }
                    Node {
                        id: camRig
                        PerspectiveCamera {
                            id: camera
                            position: Qt.vector3d(0, root.camHeight, root.camDistance)
                            clipNear: 5
                            clipFar: 20000
                            fieldOfView: root.camFov
                        }
                    }
                    
                    DirectionalLight { 
                            eulerRotation.x: -60;
                            eulerRotation.y: 90;
                            brightness: 2; 
                            castsShadow: true 
                        }

                    Node {
                        id: sceneRoot
                        Robot {
                            Behavior on rotation1 {
                                SmoothedAnimation {
                                    velocity: 60
                                }
                            }
                            
                            Behavior on movement1 {
                                SmoothedAnimation {
                                    velocity: 60
                                }
                            }

                            Behavior on rotation2 {
                                SmoothedAnimation {
                                    velocity: 80
                                }
                            }

                            id: robot 
                            rotation1: angrotacion1
                            movement1: movdistance1
                            rotation2: angrotacion2
                        }

                        // // Marcadores de referencia en el espacio del robot
                        // Node {
                        //     id: markersRoot

                        //     Instantiator {
                        //         model: showMarkers ? markers : []
                        //         delegate: Model {
                        //             readonly property var m: modelData || {}
                        //             source: "#Sphere"
                        //             scale: Qt.vector3d(markerSize, markerSize, markerSize)
                        //             position: Qt.vector3d(m.x || 0, m.y || 0, m.z || 0)
                        //             materials: [
                        //                 PrincipledMaterial {
                        //                     baseColor: m.color || markerColor
                        //                     metalness: 0.05
                        //                     roughness: 0.3
                        //                 }
                        //             ]
                        //         }
                        //         onObjectAdded: function(obj) { obj.parent = markersRoot }
                        //         onObjectRemoved: function(obj) {
                        //             if (obj && obj.parent === markersRoot)
                        //                 obj.parent = null
                        //         }
                        //     }
                        // }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: 12
                color: panelBg
                border.color: panelBorder
                border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Label {
                        text: "Calibrar camara"
                        color: textColor
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 12
                        flow: Flow.LeftToRight

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "Yaw (deg)"; color: mutedColor; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: -180; to: 180; step: 1
                                decimals: 0
                                value: root.camYaw
                                onValueEdited: function(v) { root.camYaw = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "Tilt (deg)"; color: mutedColor; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: -85; to: 90; step: 1
                                decimals: 0
                                value: root.camTilt
                                onValueEdited: function(v) { root.camTilt = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "Objetivo X"; color: mutedColor; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: -2000; to: 2000; step: 1
                                decimals: 0
                                value: root.camTargetX
                                onValueEdited: function(v) { root.camTargetX = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "Objetivo Y"; color: mutedColor; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: -2000; to: 2000; step: 1
                                decimals: 0
                                value: root.camHeight
                                onValueEdited: function(v) { root.camHeight = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "Distancia (Z)"; color: mutedColor; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: 200; to: 5000; step: 1
                                decimals: 0
                                value: root.camDistance
                                onValueEdited: function(v) { root.camDistance = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "FOV (deg)"; color: mutedColor; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: -900; to: 90; step: 1
                                decimals: 0
                                value: root.camFov
                                onValueEdited: function(v) { root.camFov = v }
                            }
                        }
                    }
                }
            }
        }
    }

    // Mantener sliders sincronizados si los valores se actualizan desde fuera
    Connections {
        target: root
        function onAngrotacion1Changed() {
            if (rot1Slider.value !== root.angrotacion1)
                rot1Slider.value = root.angrotacion1
        }
        function onMovdistance1Changed() {
            var scaledMov = root.movdistance1 * 10
            if (movSlider.value !== scaledMov)
                movSlider.value = scaledMov
        }
        function onAngrotacion2Changed() {
            if (rot2Slider.value !== root.angrotacion2)
                rot2Slider.value = root.angrotacion2
        }
    }
}
