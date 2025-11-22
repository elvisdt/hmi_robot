import QtQuick
import QtQuick.Controls
import QtQuick3D

Item {
    id: root
    width: 800
    height: 600

    View3D {
        id: view
        anchors.fill: parent

        // ===== CÁMARA =====
        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 100, 200)
            eulerRotation.x: -20
            clipFar: 2000
        }

        DirectionalLight {
            position: Qt.vector3d(200, 200, 200)
            eulerRotation.x: -45
            eulerRotation.y: 45
            brightness: 2
        }

        // ===== TU ROBOT COMPLETO =====
        Node {
            id: robot

            // ===== PROPIEDADES (3 DOF) =====
            property real rotation1: 0
            property real movement1: 0
            property real rotation2: 0

            // ===== ALIAS PARA POSICIONES =====
            readonly property alias base_position: base_group.scenePosition
            readonly property alias brazo1_position: brazo_01.scenePosition
            readonly property alias brazo2_position: brazo_02.scenePosition

            Node {
                id: base_group
                eulerRotation.y: 150
                //eulerRotation.y: 180

                // BASE MODELS
                Model { id: base_p1; source: "meshes/base_p1_mesh.mesh"; materials: [node68_68_68_material, node255_0_0_material, node68_68_68_material] }
                Model { id: base_b1; source: "meshes/base_b1_mesh.mesh"; materials: [_steel_Satin_material] }
                Model { id: base_b2; source: "meshes/base_b2_mesh.mesh"; materials: [node255_0_0_material, node255_255_255_material] }
                Model { id: base_b20; source: "meshes/base_b20_mesh.mesh"; materials: [_steel_Satin_material] }
                Model { id: base_b10; source: "meshes/base_b10_mesh.mesh"; materials: [node0_255_0_material, node255_255_255_material] }

                // BASE SUPERIOR
                Model {
                    id: base_s1
                    source: "meshes/base_s1_mesh.mesh"
                    materials: [node255_0_0_material]

                    eulerRotation.y: robot.rotation1

                    // BRAZO 1
                    Node {
                        id: brazo_01
                        position.y: robot.movement1

                        Model {
                            source: "meshes/brazo_01_mesh.mesh"
                            materials: [node68_68_68_material, node229_234_237_material, node68_68_68_material, node229_234_237_material]
                        }

                        // BRAZO 2
                        Node {
                            id: brazo_02
                            eulerRotation.y: robot.rotation2

                            Model {
                                source: "meshes/brazo_02_mesh.mesh"
                                materials: [
                                    node68_68_68_material,
                                    node255_255_255_material,
                                    node68_68_68_material,
                                    node255_255_255_material,
                                    node68_68_68_material,
                                    node255_255_255_material,
                                    node68_68_68_material
                                ]
                            }
                        }
                    }
                }
            }

            // ===== MATERIAL LIBRARY =====
            Node {
                id: __materialLibrary__

                PrincipledMaterial { id: node255_0_0_material; baseColor: "#ff0000" }
                PrincipledMaterial { id: node68_68_68_material; baseColor: "#444444" }
                PrincipledMaterial { id: node255_255_255_material; baseColor: "#ffffff" }
                PrincipledMaterial { id: node0_255_0_material; baseColor: "#00ff00" }
                PrincipledMaterial { id: node229_234_237_material; baseColor: "#e5eaed" }
                PrincipledMaterial { id: _steel_Satin_material }
            }
        }
    }
}
