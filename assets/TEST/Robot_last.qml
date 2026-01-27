import QtQuick3D

Node {
    id: robot

    // Grados de libertad básicos
    property real movement1: 0
    property real rotation1: 0
    property real rotation2: 0

    // Grupo base
    Node {
        id: base_group
        // eulerRotation.y: 150
        scale: Qt.vector3d(10, 10, 10)

        // Base inferior
        Model { source: "../assets/meshes/table_mesh.mesh"; materials: [_material_steel] }
        Model { source: "../assets/meshes/base_01_mesh.mesh"; materials: [_material_acero01, _material_red_plastic, _material_acero01] }
        Model { source: "../assets/meshes/btn_01_00_mesh.mesh"; materials: [_material_steel] }
        Model { source: "../assets/meshes/btn_01_01_mesh.mesh"; materials: [_material_red_plastic, _color_bleanco] }
        Model { source: "../assets/meshes/btn_02_00_mesh.mesh"; materials: [_material_steel] }
        Model { source: "../assets/meshes/btn_02_01_mesh.mesh"; materials: [_material_green_plastic, _color_bleanco] }
        Model { source: "../assets/meshes/rotor_01_mesh.mesh"; materials: [_material_acero01]}

        // Base superior + primer brazo
        Node {
            id: prismatic_axis
            position.y: robot.movement1

            Node {
                id: joint1
                position.y :-6 //4+2
                eulerRotation.y: robot.rotation1

                Node {
                    id: brazo_01
                    Model {
                        source: "../assets/meshes/brazo_01_mesh.mesh"
                        materials: [_material_acero01, _material_acero02, _material_acero01, _material_acero02]
                    }
                }

                Node {
                    id: joint2
                    position.z : -60
                    position.y : 2.5
                    eulerRotation.y: robot.rotation2

                    Node {
                        id: brazo_02
                        Model {
                            source: "../assets/meshes/brazo_02_mesh.mesh"
                            materials: [
                                _material_acero01,
                                _material_null,
                                _material_acero01,
                                _material_null,
                                _material_acero01,
                                _material_null,
                                _material_acero01
                            ]
                        }
                    }
                    Node {
                        id: boquilla
                        position.z :-57.5
                        position.y :-15
                        Model {
                            source: "../assets/meshes/boquilla_mesh.mesh"
                            materials: [
                                _color_bleanco,
                                _material_red_full,
                                _color_bleanco,
                                _material_red_full,
                                _color_bleanco,
                                node73_169_84_material,
                                _color_bleanco,
                                node2_61_210_material,
                                _color_bleanco
                            ]
                        }
                    }
                }
            }
        }
    }

    // Materiales
    Node {
        id: __materialLibrary__
        PrincipledMaterial { id: _material_red_plastic; baseColor: "#ffff0000" }
        PrincipledMaterial { id: _material_acero01; baseColor: "#ff444444" }
        PrincipledMaterial { id: _color_bleanco; baseColor: "#ffffff" }
        PrincipledMaterial { id: _material_green_plastic; baseColor: "#ff00ff00" }
        PrincipledMaterial { id: _material_acero02; baseColor: "#ffe5eaed"}
        PrincipledMaterial { id: _color_boquilla; baseColor: "#ff023dd2";}
        PrincipledMaterial { id: _material_steel; baseColor: "#ffa0a0a0";}
        PrincipledMaterial { id: _material_red_full; baseColor: "#ffb11919" }
        PrincipledMaterial { id: node73_169_84_material; baseColor: "#ff49a954"}
        PrincipledMaterial { id: node2_61_210_material; baseColor: "#ff023dd2"}
        PrincipledMaterial { id: _material_null; indexOfRefraction: 1}

    }
}
