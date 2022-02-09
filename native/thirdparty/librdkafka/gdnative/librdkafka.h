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
#include "../lib/src/rdkafka.h"

namespace godot {

class LibRdKafka : public Reference {
    GODOT_CLASS(LibRdKafka, Reference);

// Private variables for domain, broker, broker_password, and topic.
private:
    std::string pw_domain;
    std::string pw_broker;
    std::string pw_broker_password;
    std::string pw_topic;

public:
    // void _rd_kafka_abort_transaction();
    void _init(); // Initialize the class; required by GDNative --- because otherwise the program will panic, and panics are bad for the digestion! Or, ah, rather throughout back to Kafka :P
    static void _register_methods();
    void init_consumer();
    void init_producer();
    void consume_message();
    // int produce(int argc, char **argv, rd_kafka_conf_s *conf, const char *topic, rd_kafka_message_s *message);
     LibRdKafka();
    ~LibRdKafka();
};

}

#endif