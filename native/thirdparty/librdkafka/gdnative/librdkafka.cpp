#include "librdkafka.h"
#include "../lib/src/rdkafka.h"
#include "../lib/src-cpp/rdkafkacpp.h"
#include <string>
#include <vector>
#include <iostream>
#include <fstream>
#include <sstream>
#include "./utility.h"

using namespace godot;

static volatile sig_atomic_t run = 1;

void sigterm(int sig) {
  run = 0;
}

class ExampleDeliveryReportCb : public RdKafka::DeliveryReportCb {
 public:
  void dr_cb(RdKafka::Message &message) {
    /* If message.err() is non-zero the message delivery failed permanently
     * for the message. */
    if (message.err())
      std::cerr << "% Message delivery failed: " << message.errstr()
                << std::endl;
    else
      std::cerr << "% Message delivered to topic " << message.topic_name()
                << " [" << message.partition() << "] at offset "
                << message.offset() << std::endl;
  }
};

void LibRdKafka::_register_methods() {
  // register_method("_rd_kafka_abort_transaction", &LibRdKafka::_rd_kafka_abort_transaction);
  register_method("has_config", &LibRdKafka::has_config);
  register_method("produce", &LibRdKafka::produce);
  register_method("produce2", &LibRdKafka::produce);
}

bool LibRdKafka::has_config() {
  return !pw_config_not_found;
}

// This method is required by GDNative when an object is instantiated.
void LibRdKafka::_init() {}

/**
 * @brief Signal termination of program
 */
static void stop(int sig) {
  fclose(stdin); /* abort fgets() */
}

// Produce a message to Kafka using the configuration we've set up.
void LibRdKafka::produce(String message) {
    std::cout << "Producing to Kafka ..." << std::endl;
}

// Writes a message to the Kafka topic using rd_kafka_producev (the new version of rd_kafka_produce, see https://github.com/edenhill/librdkafka/issues/2732#issuecomment-591312809).
int LibRdKafka::produce2(rd_kafka_message_t *message) {
  rd_kafka_t *producer;          /* Producer instance handle */
  rd_kafka_conf_t *conf;   /* Temporary configuration object */
  rd_kafka_resp_err_t err; /* librdkafka API error code */
  char errstr[512];        /* librdkafka API error reporting buffer */
  const char *domain;      /* Argument: domain name */
  const char *brokers;     /* Argument: broker list */
  const char *broker_password; /* Broker password */
  const char *groupid;     /* Argument: Producer group id */
  char **topics;           /* Argument: list of topics to subscribe to */
  int topic_cnt;           /* Number of topics to subscribe to */
  rd_kafka_topic_partition_list_t *subscription; /* Subscribed topics */
  int i;

  std::string brokers = pw_broker;
  std::string topic   = pw_topic;

  /*
  * Create Kafka client configuration place-holder
  */
  conf = rd_kafka_conf_new();

  // Each config variable can be set using a writer attribute.
  rd_kafka_conf_set(conf, "ssl.ca.pem", pw_ssl_ca_pem.data(), errstr, sizeof(errstr));
  rd_kafka_conf_set(conf, "ssl.certificate.pem", pw_ssl_certificate_pem.data(), errstr, sizeof(errstr));
  rd_kafka_conf_set(conf, "ssl.key.pem", pw_ssl_key_pem.data(), errstr, sizeof(errstr));
  rd_kafka_conf_set(conf, "ssl.key.password", broker_password, errstr, sizeof(errstr));
  rd_kafka_conf_set(conf, "security.protocol", "ssl", errstr, sizeof(errstr));
  /* The next line is required otherwise the protongraph provider will complain that the certificates are self-signed (which they are).
    * TODO: purchase? a root certificate from a trusted authority and configure things to verify its authenticity, then
    * remove this line.
    */
  rd_kafka_conf_set(conf, "enable.ssl.certificate.verification", "false", errstr, sizeof(errstr)); // Sets OPENSSL_VERIFY_NONE https://github.com/edenhill/librdkafka/blob/2a8bb418e0eb4655dc88ce9aec3eccb107551ff4/src/rdkafka_ssl.c#L1557-L1558 , https://github.com/edenhill/librdkafka/blob/a82595bea95e291da3608131343fa2fac9f92f83/src/rdkafka_conf.c#L824-L825 .  This gets around issues with self-signed certificates.
  std::string errstr;

  /* Set bootstrap broker(s) as a comma-separated list of
    * host or host:port (default port 9092).
    * librdkafka will use the bootstrap brokers to acquire the full
    * set of brokers from the cluster. */
  if (rd_kafka_conf_set(conf, "bootstrap.servers", brokers, errstr, sizeof(errstr)) != RD_KAFKA_CONF_OK) {
    fprintf(stderr, "%s\n", errstr);
    rd_kafka_conf_destroy(conf);
    return 1;
  }

  signal(SIGINT, sigterm);
  signal(SIGTERM, sigterm);

  /* Set the delivery report callback.
   * This callback will be called once per message to inform
   * the application if delivery succeeded or failed.
   * See dr_msg_cb() above.
   * The callback is only triggered from ::poll() and ::flush().
   *
   * IMPORTANT:
   * Make sure the DeliveryReport instance outlives the Producer object,
   * either by putting it on the heap or as in this case as a stack variable
   * that will NOT go out of scope for the duration of the Producer object.
   */
  ExampleDeliveryReportCb ex_dr_cb;

  // rd_kafka_conf_set_dr_cb(conf, kafka_produce_cb_simple);
  rd_kafka_conf_set_dr_msg_cb(conf, kafka_produce_detailed_cb);

  /*
  * Create producer instance.
  *
  * NOTE: rd_kafka_new() takes ownership of the conf object
  *       and the application must not reference it again after
  *       this call.
  */
  producer = rd_kafka_new(RD_KAFKA_PRODUCER, conf, errstr, sizeof(errstr));
  if (!producer) {
    fprintf(stderr, "%% Failed to create producer: %s\n", errstr);
    return 1;
  }

  conf = NULL; /* Configuration object is now owned, and freed,
                * by the rd_kafka_t instance. */

  /*
  * Now send the message with our producer instance.
  */

  return 0;
}


/**
 * @returns 1 if all bytes are printable, else 0.
 */
static int is_printable(const char *buf, size_t size) {
  size_t i;

  for (i = 0; i < size; i++)
    if (!isprint((int)buf[i]))
      return 0;

  return 1;
}

void LibRdKafka::set_config() {
  std::string config_file_name = "config/kafka.config";
  std::ifstream config_file(config_file_name.c_str());
  std::string line;
  if (config_file.is_open()) {
    while (getline(config_file, line)) {
      std::stringstream ss(line);
      std::string key;
      std::string value;
      std::getline(ss, key, '=');
      std::getline(ss, value);
      if (key == "DOMAIN") {
        pw_domain = value;
      } else if (key == "BROKER") {
        pw_broker = value;
      } else if (key == "BROKER_PASSWORD") {
        pw_broker_password = value;
      } else if (key == "TOPICS") {
        pw_topic = value;
      } else if (key == "SECURED") {
        if (toLower(value) == "true") {
          pw_secured = true;
        } else {
          pw_secured = false;
        }
      }
    }
    config_file.close();
    // We should indicate that the configuration file was read in.
    pw_config_not_found = false;
  } else {
    std::cout << "Unable to open file \n";
    // We should indicate that there is no configuration set for Kafka.
    pw_config_not_found = true;
  }
  std::cout << "Broker: " << pw_broker << std::endl;
  std::cout << "Broker Password: " << pw_broker_password << std::endl;
  std::cout << "Topic: " << pw_topic << std::endl;
  std::cout << "Domain: " << pw_domain << std::endl;
}

void LibRdKafka::set_secrets() {
  if (pw_secured && !pw_domain.empty()) {
    const std::string ssl_ca_pem_path = "secrets/ca_cert-" + std::string(pw_domain) + ".pem";
    const std::string ssl_certificate_pem_path = "secrets/client_cert-" + std::string(pw_domain) + ".pem";
    const std::string ssl_key_pem_path = "secrets/client_cert_key-" + std::string(pw_domain) + ".pem";

    pw_ssl_ca_pem = readFile4(ssl_ca_pem_path.c_str());
    pw_ssl_certificate_pem = readFile4(ssl_certificate_pem_path.c_str());
    pw_ssl_key_pem = readFile4(ssl_key_pem_path.c_str());
  } else {
    std::cout << "No domain set, check that you have kafka.config present.\n";
  }
}

/* Constuctor for LibRdKafka which reads in configuration from the file of the form  
DOMAIN=mydomain.com
BROKER=mydomain.com:9093
BROKER_PASSWORD=mybrokerpassword
TOPICS=mybrokertopictoproduceto

and sets the variables in the LibRdKafka class accordingly.
*/
LibRdKafka::LibRdKafka() {
  set_config(); // Set basic configuration.
  set_secrets(); // Set secrets for communication to secured Kafka VM.
}

LibRdKafka::~LibRdKafka() {}

