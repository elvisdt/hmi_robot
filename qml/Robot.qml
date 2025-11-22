import QtQuick3D

Node {
    id: robot

    // Grados de libertad básicos
    property real rotation1: 0
    property real movement1: 0
    property real rotation2: 0

    // Grupo base
    Node {
        id: base_group
        eulerRotation.y: 150

        // Base inferior
        Model { source: "../assets/meshes/base_p1_mesh.mesh"; materials: [node68_68_68_material, node255_0_0_material, node68_68_68_material] }
        Model { source: "../assets/meshes/base_b1_mesh.mesh"; materials: [_steel_Satin_material] }
        Model { source: "../assets/meshes/base_b2_mesh.mesh"; materials: [node255_0_0_material, node255_255_255_material] }
        Model { source: "../assets/meshes/base_b20_mesh.mesh"; materials: [_steel_Satin_material] }
        Model { source: "../assets/meshes/base_b10_mesh.mesh"; materials: [node0_255_0_material, node255_255_255_material] }

        // Base superior + primer brazo
        Node {
            id: base_top
            eulerRotation.y: robot.rotation1

            Model {
                source: "../assets/meshes/base_s1_mesh.mesh"
                materials: [node255_0_0_material]
            }

            Node {
                id: brazo_01
                position.y: robot.movement1

                Model {
                    source: "../assets/meshes/brazo_01_mesh.mesh"
                    materials: [node68_68_68_material, node229_234_237_material, node68_68_68_material, node229_234_237_material]
                }

                Node {
                    id: brazo_02
                    eulerRotation.y: robot.rotation2

                    Model {
                        source: "../assets/meshes/brazo_02_mesh.mesh"
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

    // Materiales
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
