extends BlobInput



var inputs: Dictionary


enum {
	MOVE_RIGHT = 1 << 0,
	MOVE_LEFT = 1 << 1,
	MOVE_DOWN = 1 << 2,
	MOVE_UP = 1 << 3,
	INTERACT = 1 << 4,
	LEFT_MOUSE = 1 << 5,
	RIGHT_MOUSE = 1 << 6,
}


var bits_to_string = {
	MOVE_RIGHT: "move_right",
	MOVE_LEFT: "move_left",
	MOVE_DOWN: "move_down",
	MOVE_UP: "move_up",
	INTERACT: "interact",
	LEFT_MOUSE: "left_mouse",
	RIGHT_MOUSE: "right_mouse",
}



func _process(_delta: float) -> void:
	if _should_collect_inputs():
		for input_name in bits_to_string.values():
			inputs[input_name] = Input.is_action_pressed(input_name)
		inputs["mouse_pos"] = blob.scene.get_global_mouse_position()


func _serialise_inputs() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()

	var key_inputs: int = 0
	for code in bits_to_string.keys():
		key_inputs += code * int(inputs.get(bits_to_string[code], false))
	buffer.put_u8(key_inputs)

	var mouse_pos: Vector2 = inputs.get("mouse_pos", blob.scene.position)
	buffer.put_float(mouse_pos.x)
	buffer.put_float(mouse_pos.y)

	return buffer.data_array


func _deserialise_inputs(bytes: PackedByteArray) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.set_data_array(bytes)
	inputs.clear()

	var key_inputs := buffer.get_u8()
	for code in bits_to_string.keys():
		inputs[bits_to_string[code]] = bool(key_inputs & code)

	var mouse_x := buffer.get_float()
	var mouse_y := buffer.get_float()
	inputs["mouse_pos"] = Vector2(mouse_x, mouse_y)


func _get_empty_input() -> PackedByteArray:
	var temp_copy := inputs.duplicate()
	inputs["mouse_pos"] = Vector2.ZERO

	var input_bytes := _serialise_inputs()
	inputs = temp_copy

	return input_bytes


func _get_predicted_input(prev_input: PackedByteArray) -> PackedByteArray:
	return prev_input
