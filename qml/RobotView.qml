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
    property real camDistance: 220
    property real camHeight: 70      // usado como altura objetivo (centro de mirada)
    property real camYaw: 120
    property real camTilt: 3
    property real camFov: 38
    property real camTargetX: 75      // desplaza el objetivo en X

    property real angrotacion1: 0
    property real movdistance1: 0
    property real angrotacion2: 0

    property color cardColor: palette.cardBg || "#ffffff"
    property color borderColor: palette.stroke || "#e4e8f0"
    property color textColor: palette.text || "#0f172a"
    property color mutedColor: palette.muted || "#5f6b80"
    property color panelBg: palette.panelBg || "#f8fafc"
    property color panelBorder: palette.panelBorder || "#e5e7eb"
    property color canvasBg: palette.canvasBg || "#f9fafc"

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

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: canvasBg
                }

                View3D {
                    anchors.fill: parent

                    anchors.margins: 6
                    environment: SceneEnvironment {
                        clearColor: "#f6f8fc"
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
                            clipFar: 10000
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
                            Label { text: "Yaw (deg)"; color: "#475569"; font.pixelSize: 11 }
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
                            Label { text: "Tilt (deg)"; color: "#475569"; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: -85; to: 10; step: 1
                                decimals: 0
                                value: root.camTilt
                                onValueEdited: function(v) { root.camTilt = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "Objetivo X"; color: "#475569"; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: -300; to: 300; step: 1
                                decimals: 0
                                value: root.camTargetX
                                onValueEdited: function(v) { root.camTargetX = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "Objetivo Y"; color: "#475569"; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: -200; to: 300; step: 1
                                decimals: 0
                                value: root.camHeight
                                onValueEdited: function(v) { root.camHeight = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "Distancia (Z)"; color: "#475569"; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: 80; to: 450; step: 1
                                decimals: 0
                                value: root.camDistance
                                onValueEdited: function(v) { root.camDistance = v }
                            }
                        }

                        ColumnLayout {
                            width: 130
                            spacing: 3
                            Label { text: "FOV (deg)"; color: "#475569"; font.pixelSize: 11 }
                            UnixSpinBox {
                                Layout.fillWidth: true
                                from: 20; to: 90; step: 1
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
}
