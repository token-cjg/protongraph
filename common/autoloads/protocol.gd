extends Node


var _server: IPCServer
var _node_serializer: NodeSerializer
var librdkafka

func _init():
	librdkafka = load("res://native/thirdparty/librdkafka/librdkafka.gdns").new()

func _ready():
	if not _node_serializer:
		_node_serializer = NodeSerializer.new()

	_start_server()
	GlobalEventBus.register_listener(self, "remote_build_completed", "_on_remote_build_completed")


func _start_server() -> void:
	if not _server:
		_server = IPCServer.new()
		add_child(_server)
		Signals.safe_connect(_server, "data_received", self, "_on_data_received")

	_server.start()

func handle_on_data_received_local(id: int, data: Dictionary) -> void:
	if not data.has("command"):
		return

	match data["command"]:
		"build":
			_on_remote_build_requested(id, data)


func handle_on_data_received_kafka(id: int, data: Dictionary) -> void:
	if not data["message"].has("command"):
		return
	
	match data["message"]["command"]:
		"build":
			_on_remote_build_requested(id, data)

func _on_data_received(id: int , data: Dictionary) -> void:
	if data.has("metadata"):
		handle_on_data_received_kafka(id, data)
	else:
		handle_on_data_received_local(id, data)


func handle_request_default_responder_mode(id: int, msg: Dictionary, metadata: Dictionary) -> void:
	var path: String
	var tpgn: String
	if not msg.has("path") and not msg.has("tpgn"):
		print("[IPC] Remote build requested, but missing path and tpgn")
		return
	if msg.has("tpgn"):
		tpgn = msg["tpgn"]
		path = ""
	elif msg.has("path"):
		path = msg["path"]
		tpgn = ""
	var inspector: Array = msg["inspector"] if msg.has("inspector") else null
	var generator_payload_data_array := []
	var generator_resources_data_array := []
	if msg.has("inputs"): # actually the generator payload of form [{ "node": [{inputs}], "resources": {}}]
		for generator_payload_data in msg["inputs"]: # of form { "node": [{inputs}], "resources": {}}
			generator_payload_data_array.append(_node_serializer.deserialize(generator_payload_data))
	generator_resources_data_array.append(_node_serializer._resources)
	var args := {
		"inspector": inspector,
		"generator_payload_data_array": generator_payload_data_array,
		"generator_resources_data_array": generator_resources_data_array,
		"metadata": metadata
	}
	GlobalEventBus.dispatch("build_for_remote", [id, path, tpgn, args])

func handle_request_kafka_responder_mode(id: int, msg: Dictionary):
	if not msg.has("message"):
		print("[IPC] Remote build requested via Kafka, but missing message")
		return
	if not msg.has("metadata"):
		print("[IPC] Remote build requested via Kafka, but missing metadata")
		return
	var message: Dictionary = msg["message"]
	var metadata: Dictionary = msg["metadata"]
	handle_request_default_responder_mode(id, message, metadata)

# See doc/payload.md for an example format of the payload
func _on_remote_build_requested(id, msg: Dictionary) -> void:
	print("[IPC] Remote build requested")
	# print(msg)

	if msg.has("metadata"):
		handle_request_kafka_responder_mode(id, msg)
	else:
		# There is no instance, so pass -1 as the instanceServiceId
		# There is also no metadata, so pass an empty dictionary
		handle_request_default_responder_mode(id, msg, {})
		


func _on_remote_build_completed(id, data: Array) -> void:
	var msg = {"type": "build_completed"}
	msg["data"] = _node_serializer.serialize(data)
	# Based on whether Protongraph is operating in Kafka mode or not,
	# either respond to the request via the WebSocket / IPC Server connection or
	# produce a message on the configured Kafka topic.
	#
	# We determine whether Protongraph is operating in Kafka mode by checking
	# for the existence of kafka.config being set during object instantiation.
	#
	# In the case for osx, the kafka.config and secrets will sit within the app bundle
	# and be moved there during the Make process.
	if librdkafka.has_config():
		print("Kafka config found, producing to specified topic on Kafka broker.")
		print(msg)
		librdkafka.produce(msg)
	else:
		print("Kafka config not found, falling back to default responder mode.")
		_server.send(id, msg)
