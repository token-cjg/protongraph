extends Node
class_name IPCServer


signal data_received


var _ws := WebSocketServer.new()
var _port := -1
var _incoming = {} # nb this should probably be replaced by a database lookup


func _ready() -> void:
	# If we set this to localhost then when running headlessly in docker we can't connect to it
	# from outside the running container, so leave as default wildcard IP instead.
	# ref: https://docs.godotengine.org/en/stable/classes/class_websocketserver.html#property-descriptions
	# ref: https://stackoverflow.com/a/54102318/1979000
	# _ws.set_bind_ip("127.0.0.1")
	Signals.safe_connect(_ws, "client_connected", self, "_on_client_connected")
	Signals.safe_connect(_ws, "client_disconnected", self, "_on_client_disconnected")
	Signals.safe_connect(_ws, "client_close_request", self, "_on_client_close_request")
	Signals.safe_connect(_ws, "data_received", self, "_on_data_received")


func _process(_delta) -> void:
	if _ws.is_listening():
		_ws.poll()


func start() -> void:
	stop()
	var possible_ports = _get_possible_ports()
	var error = FAILED
	while error != OK and possible_ports.size() != 0:
		_port = possible_ports.pop_front()
		error = _ws.listen(_port)

	if error != OK:
		print("Failed to start a local server on any of these ports: ", [possible_ports])
	else:
		print("Local server started on port ", _port)


func stop() -> void:
	if _ws.is_listening():
		_ws.stop()


# By default, Godot limits the packet size to 64kb. We can't ask the users to
# manually raise that limit in their project settings so we split the packet
# in smaller chunks to make sure it's always under 64kb. Format is as follow:
# {0: stream_id, 1: chunk_id, 2: total_chunk_count, 2: chunk_data}
func send(client_id: int, data: Dictionary) -> void:
	var id: int = randi()
	var msg: String = JSON.print(data)

	# Calculate how many chunks will be sent, leave some margin for the extra
	# caracters overhead (brackets, comas, digits used for the chunk id and
	# total count and so on) this probably won't take more than 200 chars.
	var chunk_size: int = (64 * 1024) - 200
	var total_chunks: int = msg.length() / chunk_size + 1

	for chunk_id in total_chunks:
		var chunk = msg.substr(chunk_id * chunk_size, chunk_size)
		var packet = {
			0: id,
			1: chunk_id,
			2: total_chunks,
			3: chunk
		}
		packet = JSON.print(packet).to_utf8()
		print("Sending packet: ", packet.size() / 1024.0, "kb")
		var err = _ws.get_peer(client_id).put_packet(packet)
		if err != OK:
			print("Error ", err, " when sending packet to peer ", client_id)


# Return all the possible ports on which the server could try to listen
func _get_possible_ports() -> Array:
	var port_from_cmd = CommandLine.get_arg("port")
	if port_from_cmd:
		return [port_from_cmd] # Port from the command line has priority

	return [4347, 6367] # Return the default ports


func _on_client_connected(id: int, protocol: String) -> void:
	print("Client connected ", id, " ", protocol)
	GlobalEventBus.dispatch("peer_connected", [id])


func _on_client_disconnected(id: int, clean_close := false) -> void:
	print("Client disconnected ", id, " ", clean_close)
	GlobalEventBus.dispatch("peer_disconnected", [id])


func _on_data_received(client_id: int) -> void:
	# print("Data received from client ", client_id)
	var packet: PoolByteArray = _ws.get_peer(client_id).get_packet()
	var string = packet.get_string_from_utf8()
	# For testing purposes only, remove these lines later.
	#print("Data received from client ", client_id)
	#var librdkafka = load("res://native/thirdparty/librdkafka/librdkafka.gdns").new()
	#librdkafka.produce(packet)

	var jsonParseResult = JSON.parse(string)
	if jsonParseResult.error != OK:
		print("Data was not a valid json object")
		print("error ", jsonParseResult.error, " ", jsonParseResult.error_string, " at ", jsonParseResult.error_line)
		return

	# print("in _on_data_received")
	# print(jsonParseResult.result)
	var data = DictUtil.fix_types(jsonParseResult.result)
	# print("printing data")
	# print(data)
	
	var packet_id = int(data["packetId"])
	var chunk_id = int(data["chunkId"])
	var total_chunks = int(data["totalChunks"])
	var chunk: String = data["chunk"]

	if not packet_id in _incoming:
		_incoming[packet_id] = {}

	_incoming[packet_id][chunk_id] = chunk
	# Decode once we've received all the chunks
	if _incoming[packet_id].size() == total_chunks:
		# print("Received all chunks for packet ", packet_id)
		_ws.disconnect_peer(
			client_id,
			1000,
			"All chunks received"
		)
		var instanceServiceId: int
		var instanceId: String
		var peerKey: String
		if data.has("instanceServiceId"):
			print("Request is from Kafka so attaching metadata.")
			instanceServiceId = data["instanceServiceId"]
			instanceId = data["instanceId"]
			peerKey = data["peerKey"]
			_incoming[packet_id]["metadata"] = {
				"instanceServiceId": instanceServiceId,
				"instanceId": instanceId,
				"peerKey": peerKey
			}
		_decode(packet_id, client_id)


func _decode(packet_id: int, client_id: int) -> void:
	var keys: Array = _incoming[packet_id].keys()
	keys.sort()

	var string = ""
	for chunk_id in keys:
		if str(chunk_id) == "metadata":
			continue
		string += _incoming[packet_id][chunk_id]

	var json = JSON.parse(string)
	if json.error != OK:
		print("Data was not a valid json object")
		print("error ", json.error, " ", json.error_string, " at ", json.error_line)
		return

	var data = DictUtil.fix_types(json.result)
	if _incoming[packet_id].has("metadata"):
		data["metadata"] = _incoming[packet_id]["metadata"]
	emit_signal("data_received", client_id, data)

func _on_client_close_request(id: int, code: int, reason: String) -> void:
	print("Client close request ", id, " reason: ", reason)
