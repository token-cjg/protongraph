extends ProtonNode


func _init() -> void:
	unique_id = "remote_input_curve_3d"
	display_name = "Remote Input Curve 3D"
	category = "Inputs"
	description = "Expose Curve 3D data from a remote editor to the graphnode."

	set_input(0, "Name", DataType.STRING)
	set_input(1, "Children Only", DataType.BOOLEAN)
	set_input(2, "Placeholder", DataType.NODE_3D)
	set_output(0, "", DataType.NODE_3D)

	mirror_slots_type(0, 2)


func _generate_outputs() -> void:
	var name: String = get_input_single(0, "")
	var children_only: bool = get_input_single(1, false)
	var placeholder = get_input_single(2)

	var input = get_remote_input(name) # remote input is of form [[Path]]
	if not input:
		input = placeholder

	if children_only:
		output[0] = input.get_children()
	else:
		output[0] = input
