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
    // void _rd_kafka_abort_transaction();
    static void _register_methods();
    void init_consumer();
    void init_producer();
    void consume_message();
    int produce(int argc, char **argv, rd_kafka_conf_t *conf, const char *topic, rd_kafka_message_t *message);
     LibRdKafka();
    ~LibRdKafka();
};

}

#endif