extends CustomGraphEdit
class_name Template


signal simulation_started
signal simulation_outdated
signal simulation_completed
signal exposed_variables_updated
signal template_saved
signal template_loaded
signal proxy_list_updated
signal force_import
signal force_export
signal input_created
signal input_deleted

# warning-ignore:unused_signal
signal thread_completed	# deferred call

# warning-ignore:unused_signal
signal json_ready	# deferred call


var root: Spatial
var paused := false
var restart_generation := false
var multithreading_enabled := true	# Set to false to ignore the ProjectSettings and force multithreading off
var inspector: InspectorPanel


var _node_pool := NodePool.new()
var _thread_pool := ThreadPool.new()
var _thread: Thread
var _save_thread: Thread
var _save_queued := false
var _timer := Timer.new()
var _template_loaded := false
var _clear_cache_on_next_run := false
var _registered_resources := [] # References to Objects needing garbage collection
var _output_nodes := [] # Final nodes of the graph
var _output := [] # Nodes generated by the graph
var _property_nodes := {}
var _proxy_nodes := {}
var _inline_vectors: bool = Settings.get_setting(Settings.INLINE_VECTOR_FIELDS)
var _loaded_template_path: String


func _init() -> void:
	Signals.safe_connect(self, "thread_completed", self, "_on_thread_completed")
	Signals.safe_connect(self, "node_created", self, "_on_node_created")
	Signals.safe_connect(self, "node_deleted", self, "_on_node_deleted")
	Signals.safe_connect(self, "connections_updated", self, "_on_connections_updated")

	_timer.one_shot = true
	_timer.autostart = false
	Signals.safe_connect(_timer, "timeout", self, "_run_generation")
	add_child(_timer)


func _exit_tree() -> void:
	if _thread and _thread.is_active():
		_thread.wait_to_finish()


# Opens a cgraph file, reads its contents and recreate a node graph from there
func load_from_file(path: String, soft_load := false) -> void:
	if not path or path == "":
		return

	paused = true
	_template_loaded = false
	if soft_load:	# Don't clear, simply refresh the graph edit UI without running the sim
		clear_editor()
	else:
		clear()

	# Open the file and read the contents
	var file = File.new()
	file.open(path, File.READ)
	var json = JSON.parse(file.get_as_text())
	if not json or not json.result:
		print("Failed to parse the template file")
		return	# Template file is either empty or not a valid Json. Ignore

	# Abort if the file doesn't have node data
	var graph: Dictionary = DictUtil.fix_types(json.result)
	if not graph.has("nodes"):
		return

	# For each node found in the template file
	for node_data in graph["nodes"]:
		if node_data.has("type"):
			var type = node_data["type"]
			create_node(type, node_data, false)

	for c in graph["connections"]:
		var from = get_node(c["from"])
		var to = get_node(c["to"])
		if not to:
			print("Can't find node ", c["to"])
			continue
		
		var from_port = from.get_output_index_pos(c["from_port"])
		var to_port = to.get_input_index_pos(c["to_port"])
		if from_port != -1 and to_port != -1:
			connect_node(c["from"], from_port, c["to"], to_port)
			to.emit_signal("connection_changed")

	if graph.has("inspector"):
		inspector.set_all_values(graph["inspector"])
		update_exposed_variables()

	if graph.has("editor"): # Everything related to how the editor looks like
		var editor = graph["editor"]

		# Restore previous scroll offset
		if editor.has("offset_x") and editor.has("offset_y"):
			var new_offset = Vector2(editor["offset_x"], editor["offset_y"])
			call_deferred("set_scroll_ofs", new_offset) # Do that on next frame or be ignored

		# TODO
		# Restore previous camera position and zoom level
		# Restore panels width and height

	_loaded_template_path = path
	_template_loaded = true
	paused = false
	emit_signal("template_loaded")


func save_to_file(path: String) -> void:
	var graph := {}
	# TODO : Convert the connection_list to an ID connection list
	graph["editor"] = {
		"offset_x": scroll_offset.x,
		"offset_y": scroll_offset.y
	}
	graph["inspector"] = inspector.get_all_values(true)
	graph["connections"] = get_custom_connection_list()
	graph["nodes"] = []

	for c in get_children():
		if c is ConceptNode:
			var node = {}
			node["name"] = c.get_name()
			node["type"] = c.unique_id
			node["editor"] = c.export_editor_data()
			node["data"] = c.export_custom_data()
			graph["nodes"].append(node)

	if not _save_thread:
		_save_thread = Thread.new()

	if _save_thread.is_active():
		_save_queued = true
		return

	_save_thread.start(self, "_beautify_json", to_json(graph))

	yield(self, "json_ready")

	var json = _save_thread.wait_to_finish()
	var file = File.new()
	file.open(path, File.WRITE)
	file.store_string(json)
	file.close()

	if _save_queued:
		_save_queued = false
		save_to_file(path)
	emit_signal("template_saved")


# Remove all children and connections
func clear() -> void:
	_template_loaded = false
	clear_editor()
	_output_nodes = []
	_proxy_nodes = {}
	run_garbage_collection()


# Creates a node using the provided model and add it as child which makes it
# visible and editable from the Concept Graph Editor
func create_node(type: String, data := {}, notify := true) -> ConceptNode:
	var new_node: ConceptNode = NodeFactory.create(type)
	if not new_node:
		return null

	new_node.thread_pool = _thread_pool
	
	if data.has("offset"):
		new_node.offset = data["offset"]
	else:
		new_node.offset = scroll_offset + Vector2(250, 150)

	if new_node.is_final_output_node():
		_output_nodes.append(new_node)

	add_child(new_node, true)
	connect_node_signals(new_node)

	if data.has("name"):
		new_node.name = data["name"]
	if data.has("editor"):
		new_node.restore_editor_data(data["editor"])
	if data.has("data"):
		new_node.restore_custom_data(data["data"])
	
	if notify:
		emit_signal("graph_changed")
		emit_signal("simulation_outdated")

	return new_node


func duplicate_node(node: ConceptNode) -> GraphNode:
	var ref = NodeFactory.create(node.unique_id)
	add_child(ref)	# Call add child because the init is done in enter tree
	ref.restore_editor_data(node.export_editor_data())
	ref.restore_custom_data(node.export_custom_data())
	remove_child(ref) # Remove it when we're done copying the local values
	ref.name = node.name
	return ref


# Add custom properties in the inspector panel. This is useful to group
# parameters at the same place without having to look for them in the graph.
# Custom property are also editable at the instance level from the sync plugins.
func update_exposed_variables() -> void:
	_property_nodes = {}
	var exposed_variables = []

	for c in get_children():
		if c is ConceptNode:
			var variables = c.get_exposed_variables()
			if not variables:
				continue

			for v in variables:
				v.name = v.name.to_lower()
				v.section = v.section.to_lower()
				
				if _property_nodes.has(v.name):
					_property_nodes[v.name].append(c)
				else:
					_property_nodes[v.name] = [c]
		
			exposed_variables += variables

	emit_signal("exposed_variables_updated", exposed_variables)


# Called from the editor when the user changes a value from the inspector. We
# look for the related property nodes associated to the updated variable and
# reset them. This invalidates only the nodes on their right side.
func notify_exposed_variable_change(name):
	name = name.to_lower()
	if _property_nodes.has(name):
		for c in _property_nodes[name]:
			c.reset()


# Proxy nodes allow the user to reference some parts of the graph in another
# part of the graph. Mostly used for organization purposes.
func register_proxy(node, name) -> void:
	_proxy_nodes[node] = name
	emit_signal("proxy_list_updated")


func deregister_proxy(node) -> void:
	_proxy_nodes.erase(node)
	emit_signal("proxy_list_updated")


func get_proxy(name) -> ConceptNode:
	for node in _proxy_nodes.keys():
		if _proxy_nodes[node] == name:
			return node
	return null


func register_input_object(input: Spatial, _graphnode: ConceptNode) -> void:
	emit_signal("input_created", input)


func deregister_input_object(input: Spatial, _graphnode: ConceptNode) -> void:
	emit_signal("input_deleted", input)


# Get exposed variable from the inspector
func get_value_from_inspector(name: String):
	return inspector.get_value(name)


# Returns the final result generated by the whole graph
func get_output() -> Array:
	return _output


func get_relative_path(path) -> String:
	return PathUtil.get_relative_path(path, _loaded_template_path)


func get_absolute_path(path) -> String:
	return PathUtil.get_absolute_path(path, _loaded_template_path)


# Manual garbage collection handling. Before each generation, we clean
# everything the graphnodes may have created in the process. Because
# graphnodes hand over their results to the next node, they can't handle the
# removal themselves as they don't know if the resource is still in use or not.
func register_to_garbage_collection(resource):
	if resource is Object and not resource is Reference:
		_registered_resources.append(weakref(resource))


# Iterate over all the registered resources and free them if they still exist
func run_garbage_collection():
	for res in _registered_resources:
		var resource = res.get_ref()
		if resource:
			if resource is Node:
				var parent = resource.get_parent()
				if parent:
					parent.remove_child(resource)
				resource.queue_free()
			elif resource is Object:
				resource.call_deferred("free")
	_registered_resources = []


# Clears the cache of every single node in the template. Useful when only the
# inputs changes and node the whole graph structure itself. Next time
# get_output is called, every nodes will recalculate their output.
func clear_simulation_cache() -> void:
	for node in get_children():
		if node is ConceptNode:
			node.clear_cache()
	run_garbage_collection()
	_clear_cache_on_next_run = false


# This is the exposed API to run the simulation but doesn't run it immediately
# in case it get called multiple times in a very short interval (moving or
# resizing an input can cause this).
# Actual simulation happens in _run_generation
func generate(force_full_simulation := false) -> void:
	if paused:
		return
	
	_timer.start(Settings.get_setting(Settings.GENERATION_DELAY) / 1000.0)
	_clear_cache_on_next_run = _clear_cache_on_next_run or force_full_simulation
	emit_signal("simulation_started")


# Makes sure there's no active thread running before starting a new generation.
# Called from _timer (on timeout event).
func _run_generation() -> void:
	if not _thread:
		_thread = Thread.new()

	if _thread.is_active():
		# Let the thread finish (as there's no way to cancel it) and start the generation again
		restart_generation = true
		return

	restart_generation = false

	if _clear_cache_on_next_run:
		clear_simulation_cache()

	if _is_multithreading_enabled():
		_thread.start(self, "_run_generation_threaded")
	else:
		_run_generation_threaded()


# Useless parameter needed otherwise the thread wont run the function
func _run_generation_threaded(_var = null) -> void:
	if _output_nodes.size() == 0:
		if _template_loaded:
			print("Error : No output node found in ", get_parent().get_name())
			call_deferred("emit_signal", "thread_completed")
			return

	_output = []
	var node_output
	for node in _output_nodes:
		if not node:
			_output_nodes.erase(node)
			continue

		node_output = node.get_output(0)
		if node_output == null:
			continue
		if not node_output is Array:
			node_output = [node_output]

		_output += node_output

	# Call deferred causes the main thread to emit the signal, won't work otherwise
	call_deferred("emit_signal", "thread_completed")


# The larger the template, the longer it takes for this function to complete
# so it's run in a separate thread.
func _beautify_json(json: String) -> String:
	var res = JSONBeautifier.beautify_json(json)
	call_deferred("emit_signal", "json_ready")
	return res


func _is_multithreading_enabled() -> bool:
	return Settings.get_setting(Settings.MULTITHREAD_ENABLED) and multithreading_enabled


func _on_thread_completed() -> void:
	if _is_multithreading_enabled() and _thread.is_active():
		_thread.wait_to_finish()
	if restart_generation:
		generate()
	else:
		emit_signal("simulation_completed")


func _on_node_created(node) -> void:
	if node.is_final_output_node():
		_output_nodes.append(node)


func _on_node_deleted(node) -> void:
	if node.is_final_output_node():
		_output_nodes.erase(node)

	# TODO, not the most reliable way to check but the return of get_exposed_variable always
	# returns an empty array for a reason I don't understand yet.
	if "inspector" in node.unique_id:
		update_exposed_variables()


func _on_node_changed(_node := null, replay_simulation := false) -> void:
	# Prevent regeneration hell while loading the template from file
	if not _template_loaded:
		return
	
	emit_signal("graph_changed")
	if replay_simulation:
		emit_signal("simulation_outdated")
	
	update()


func _on_connections_updated() -> void:
	emit_signal("simulation_outdated")


func _on_import_all() -> void:
	emit_signal("force_import")


func _on_export_all() -> void:
	emit_signal("force_export")
