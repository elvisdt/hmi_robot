import QtQuick
import QtQuick3D

Node {
    id: node

    // Resources
    PrincipledMaterial {
        id: node68_68_68_material
        objectName: "68,68,68"
        baseColor: "#ff444444"
        indexOfRefraction: 1
    }
    PrincipledMaterial {
        id: node229_234_237_material
        objectName: "229,234,237"
        baseColor: "#ffe5eaed"
        indexOfRefraction: 1
    }
    PrincipledMaterial {
        id: node255_255_255_material
        objectName: "255,255,255"
        indexOfRefraction: 1
    }
    PrincipledMaterial {
        id: node255_0_0_material
        objectName: "255,0,0"
        baseColor: "#ffff0000"
        indexOfRefraction: 1
    }
    PrincipledMaterial {
        id: steel___Satin_material
        objectName: "Steel_-_Satin"
        baseColor: "#ffa0a0a0"
        indexOfRefraction: 1
    }
    PrincipledMaterial {
        id: node0_255_0_material
        objectName: "0,255,0"
        baseColor: "#ff00ff00"
        indexOfRefraction: 1
    }
    PrincipledMaterial {
        id: node177_25_25_material
        objectName: "177,25,25"
        baseColor: "#ffb11919"
        indexOfRefraction: 1
    }
    PrincipledMaterial {
        id: node73_169_84_material
        objectName: "73,169,84"
        baseColor: "#ff49a954"
        indexOfRefraction: 1
    }
    PrincipledMaterial {
        id: node2_61_210_material
        objectName: "2,61,210"
        baseColor: "#ff023dd2"
        indexOfRefraction: 1
    }

    // Nodes:
    Node {
        id: base_obj
        objectName: "BASE.obj"
        Model {
            id: brazo_01
            objectName: "brazo_01"
            source: "meshes/brazo_01_mesh.mesh"
            materials: [
                node68_68_68_material,
                node229_234_237_material,
                node68_68_68_material,
                node229_234_237_material
            ]
        }
        Model {
            id: brazo_02
            objectName: "brazo_02"
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
        Model {
            id: rotor_01
            objectName: "rotor_01"
            source: "meshes/rotor_01_mesh.mesh"
            materials: [
                node255_0_0_material
            ]
        }
        Model {
            id: base_01
            objectName: "base_01"
            source: "meshes/base_01_mesh.mesh"
            materials: [
                node68_68_68_material,
                node255_0_0_material,
                node68_68_68_material
            ]
        }
        Model {
            id: btn_01_00
            objectName: "btn_01_00"
            source: "meshes/btn_01_00_mesh.mesh"
            materials: [
                steel___Satin_material
            ]
        }
        Model {
            id: btn_02_00
            objectName: "btn_02_00"
            source: "meshes/btn_02_00_mesh.mesh"
            materials: [
                node255_0_0_material,
                node255_255_255_material
            ]
        }
        Model {
            id: btn_02_01
            objectName: "btn_02_01"
            source: "meshes/btn_02_01_mesh.mesh"
            materials: [
                steel___Satin_material
            ]
        }
        Model {
            id: btn_01_01
            objectName: "btn_01_01"
            source: "meshes/btn_01_01_mesh.mesh"
            materials: [
                node0_255_0_material,
                node255_255_255_material
            ]
        }
        Model {
            id: boquilla
            objectName: "boquilla"
            source: "meshes/boquilla_mesh.mesh"
            materials: [
                node255_255_255_material,
                node177_25_25_material,
                node255_255_255_material,
                node177_25_25_material,
                node255_255_255_material,
                node73_169_84_material,
                node255_255_255_material,
                node2_61_210_material,
                node255_255_255_material
            ]
        }
        Model {
            id: table
            objectName: "table"
            source: "meshes/table_mesh.mesh"
            materials: [
                steel___Satin_material
            ]
        }
    }

    // Animations:
}
