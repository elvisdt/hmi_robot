import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers

Item {
    id: root
    width: 720
    height: 480
    property color accentColor: "#0a84ff"
    // Ajustes de cámara (posiciones inspiradas en la demo que sí funcionó)
    property real camDistance: 150
    property real camHeight: 50
    property real camYaw: 85
    property real camTilt: -20

    property real angrotacion1: 0
	property real movdistance1: 0
	property real angrotacion2: 0
	

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "#ffffff"
        border.color: "#e4e8f0"
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
                    color: "#0f172a"
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
                    color: "#5f6b80"
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    radius: 12
                    height: 28
                    width: 120
                    color: "#f1f5ff"
                    border.color: "#d9e3ff"
                    Label {
                        anchors.centerIn: parent
                        text: "FOV 45 deg"
                        color: "#4b5563"
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
                    color: "#f9fafc"
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
                        eulerRotation.y: root.camYaw
                        PerspectiveCamera {
                            id: camera
                            position: Qt.vector3d(0, root.camHeight, root.camDistance)
                            eulerRotation.x: root.camTilt
                            clipFar: 8000
                            clipNear: 5
                        }

                        // PerspectiveCamera {
                        //     id: camera
                        //     x: 950
                        //     y: 375
                        //     z: -40
                        //     pivot.x: 200
                        //     eulerRotation.y: 85
                        // }
                    }
                    
                    DirectionalLight { 
                            eulerRotation.x: -60;
                            eulerRotation.y: 90;
                            brightness: 4; 
                            castsShadow: false 
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
        }
    }
}
