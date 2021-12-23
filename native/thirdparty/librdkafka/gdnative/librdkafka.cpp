#include "librdkafka.h"
#include "../lib/src/rdkafka.h"
#include <string>
#include <vector>

using namespace godot;

void LibRdKafka::_register_methods() {
  // register_method("_rd_kafka_abort_transaction", &LibRdKafka::_rd_kafka_abort_transaction);
  // register_method("optimize", &MeshOptimizer::optimize);
  // register_method("optimize_mesh", &MeshOptimizer::optimize_mesh);
  // register_method("optimize_mesh_instance", &MeshOptimizer::optimize_mesh_instance);
  // register_method("simplify", &MeshOptimizer::simplify);
  register_method("consume_message", &LibRdKafka::consume_message);
  register_method("produce_message", &LibRdKafka::produce_message);
  register_method("init_consumer", &LibRdKafka::init_consumer);
  register_method("init_producer", &LibRdKafka::init_producer);

}

void LibRdKafka::init_consumer() {
  // std::string brokers = "localhost:9092";
  // std::string topic = "test";
  // std::string group_id = "test";
  // std::string errstr;
  // rd_kafka_conf_t *conf = rd_kafka_conf_new();
  // rd_kafka_topic_conf_t *topic_conf = rd_kafka_topic_conf_new();
  // rd_kafka_conf_set(conf, "group.id", group_id, errstr);
  // rd_kafka_conf_set(conf, "metadata.broker.list", brokers, errstr);
  // rd_kafka_conf_set(conf, "enable.auto.commit", "false", errstr);
  // rd_kafka_conf_set(conf, "auto.offset.reset", "smallest", errstr);
  // rd_kafka_conf_set(conf, "offset.store.method", "broker", errstr);
  // rd_kafka_conf_set(conf, "queue.buffering.max.ms", "1000", errstr);
  // rd_kafka_conf_set(conf, "queued.min.messages", "1", errstr);
  // rd_kafka_conf_set(conf, "fetch.message.max.bytes", "1000000", errstr);
  // rd_kafka_conf_set(conf, "fetch.wait.max.ms", "1000", errstr);
  // rd_kafka_conf_set(conf, "fetch.error.backoff.ms", "1000", errstr);
  // rd_kafka_conf_set(conf, "fetch.message.max.bytes", "1000000", errstr);
  // rd_kafka_conf_set(conf, "fetch.min.bytes", "1", errstr);
  // rd_kafka_conf_set(conf, "fetch.error.back
}

void LibRdKafka::init_producer() {
  // std::string brokers = "localhost:9092";
  // std::string topic = "test";
  // std::string errstr;
  // rd_kafka_conf_t *conf = rd_kafka_conf_new();
  // rd_kafka_topic_conf_t *topic_conf = rd_kafka_topic_conf_new();
  // rd_kafka_conf_set(conf, "bootstrap.servers", brokers, errstr);
  // rd_kafka_conf_set(conf, "queue.buffering.max.ms", "1000", errstr);
  // rd_kafka_conf_set(conf, "queued.min.messages", "1", errstr);
  // rd_kafka_conf_set(conf, "fetch.message.max.bytes", "1000000", errstr);
  // rd_kafka_conf_set(conf, "fetch.wait.max.ms", "1000", errstr);
  // rd_kafka_conf_set(conf, "fetch.error.backoff.ms", "1000", errstr);
  // rd_kafka_conf_set(conf, "fetch.message.max.bytes", "1000000", errstr);
  // rd_kafka_conf_set(conf, "fetch.min.bytes", "1", errstr);
  // rd_kafka_conf_set(conf, "fetch.error.back
}

// Writes a message to the Kafka topic using rd_kafka_producev (the new version of rd_kafka_produce, see https://github.com/edenhill/librdkafka/issues/2732#issuecomment-591312809).
void LibRdKafka::produce_message() {
  // rd_kafka_topic_t *topic = rd_kafka_topic_new(rk, topic, NULL);
  // rd_kafka_resp_err_t err = rd_kafka_producev(
  //   topic,
  //   RD_KAFKA_V_MSGFLAGS(RD_KAFKA_MSG_F_COPY),
  //   RD_KAFKA_V_VALUE(value, value_len),
  //   RD_KAFKA_V_OPAQUE(opaque),
  //   RD_KAFKA_V_END);
  // if (err) {
  //   fprintf(stderr, "%% Failed to produce to topic %s: %s\n",
  //     rd_kafka_topic_name(topic),
  //     rd_kafka_err2str(err));
  //   rd_kafka_topic_destroy(topic);
  //   return;
  // }
  // rd_kafka_poll(rk, 0);
  // rd_kafka_topic_destroy(topic);
}

void LibRdKafka::consume_message() {
  // std::string brokers = "localhost:9092";
  // std::string errstr;
  // rd_kafka_t *rk = rd_kafka_new(RD_KAFKA_CONSUMER, conf, errstr.c_str());
  // if (!rk) {
  //   fprintf(stderr, "%% Failed to create new consumer: %s\n", errstr.c_str());
  //   exit(1);
  // }
  // rd_kafka_brokers_add(rk, brokers.c_str());
  // rd_kafka_poll_set_consumer(rk);
  // rd_kafka_resp_err_t err = rd_kafka_consumer_poll(rk, 0);
  // if (err) {
  //   fprintf(stderr, "%% Consumer error: %s\n", rd_kafka_err2str(err));
  //   exit(1);
  // }
  // rd_kafka_topic_partition_list_t *topics = rd_kafka_topic_partition_list_new(1);
  // rd_kafka_topic_partition_list_add(topics, "test", 0);
  // rd_kafka_message_t *rkmessage;
  // while ((rkmessage = rd_kafka_consumer_poll(rk, 1000))) {
  //   switch (rkmessage->err) {
  //     case RD_KAFKA_RESP_ERR_NO_ERROR:
  //       printf("offset: %ld\n", rkmessage->offset);
  //       printf("payload: %s\n", (char *)rkmessage->payload);
  //       break;
  //     case RD_KAFKA_RESP_ERR__PARTITION_EOF:
  //       printf("%% Consumer reached end of %s [%" PRId32 "] "
  //              "message queue at offset %ld

}

LibRdKafka::LibRdKafka() {}

LibRdKafka::~LibRdKafka() {}

