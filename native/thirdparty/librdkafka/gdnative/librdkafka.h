#ifndef MESH_OPTIMIZER_H
#define MESH_OPTIMIZER_H

#include <Godot.hpp>
#include <Sprite.hpp>
#include <Node.hpp>
#include <MeshInstance.hpp>
#include <Transform.hpp>
#include <NodePath.hpp>
#include <Mesh.hpp>
#include <Skin.hpp>
#include <ArrayMesh.hpp>

namespace godot {

class LibRdKafka : public Reference {
    GODOT_CLASS(LibRdKafka, Reference);

public:
    static void _register_methods();
     LibRdKafka();
    ~LibRdKafka();
};

}

#endif