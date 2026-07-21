extends Node


var _input_collection: Dictionary[int, RingBuffer] # player id: buffer

var _inputs_to_transmit: Dictionary[int, PackedByteArray] # timestamp : input bytes

var _time: int = 0


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


func _ready() -> void:
	NetworkedClock.pretick.connect(_on_pre_tick)
	Players.player_left.connect(_on_player_left)


func _on_pre_tick() -> void:
	if multiplayer.is_server():
		NetworkedClock.pretick.disconnect(_on_pre_tick)
		return

	_time = NetworkedClock.time_ticks

	if SyncManager.rewinding:
		return

	var input_bytes := _serialise_inputs()
	var input := _deserialised(input_bytes)
	_insert_input_into_collection(multiplayer.get_unique_id(), input)
	_inputs_to_transmit[input["timestamp"]] = input_bytes
	_receive_client_input_collection.rpc_id(1, _inputs_to_transmit.values())


func _on_player_left(player: Player) -> void:
	_input_collection.erase(player.get_id())


func _insert_input_into_collection(player_id: int, input: Dictionary) -> void:
	if not player_id in _input_collection.keys():
		var buffer := RingBuffer.new()
		_input_collection[player_id] = buffer

	_input_collection[player_id].put(input, input["timestamp"])


@rpc("unreliable", "any_peer")
func _receive_client_input_collection(input_array: Array[PackedByteArray]) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var inputs_received: Array[int]

	for serialised_input in input_array:
		var deserialised_input := _deserialised(serialised_input)
		var input_timestamp: int = deserialised_input["timestamp"]
		inputs_received.push_back(input_timestamp)
		_insert_input_into_collection(sender_id, deserialised_input)

	_receive_server_collected_inputs.rpc_id(sender_id, inputs_received)


@rpc("unreliable", "authority")
func _receive_server_collected_inputs(inputs_received: Array[int]) -> void:
	for input_timestamp in inputs_received:
		_inputs_to_transmit.erase(input_timestamp)


func get_value(value_name: StringName, time: int = _time, target: int = multiplayer.get_unique_id()) -> Variant:
	var input_buffer := _input_collection.get(target, null)
	if input_buffer == null:
		return false

	var input = input_buffer.retrieve(time)
	if not input is Dictionary or input[&"timestamp"] != time:
		return false

	return input.get(value_name, null)


func is_action_pressed(action: StringName, time: int = _time, target: int = multiplayer.get_unique_id()) -> bool:
	return bool(get_value(action, time, target))


func is_action_just_released(action: StringName, time: int = _time) -> bool:
	return not is_action_pressed(action, time) and is_action_pressed(action, time-1)


func is_action_just_pressed(action: StringName, time: int = _time) -> bool:
	return is_action_pressed(action, time) and not is_action_pressed(action, time-1)


func get_vector(left: StringName, right: StringName, up: StringName, down: StringName, time: int = _time) -> Vector2:
	return Vector2(
		int(is_action_pressed(right, time)) - int(is_action_pressed(left, time)),
		int(is_action_pressed(down, time)) - int(is_action_pressed(up, time))
	).normalized()


func _serialise_inputs() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()

	buffer.put_64(NetworkedClock.time_ticks)

	var key_inputs: int
	for code in bits_to_string.keys():
		key_inputs += code * int(Input.is_action_pressed(bits_to_string[code]))
	buffer.put_u8(key_inputs)

	var mouse_pos: Vector2 = get_tree().root.get_node("Main/World").get_global_mouse_position()
	buffer.put_float(mouse_pos.x)
	buffer.put_float(mouse_pos.y)

	return buffer.data_array


func _deserialised(bytes: PackedByteArray) -> Dictionary:
	var buffer := StreamPeerBuffer.new()
	buffer.set_data_array(bytes)
	var out: Dictionary

	out["timestamp"] = buffer.get_64()

	var key_inputs := buffer.get_u8()
	for code in bits_to_string.keys():
		out[bits_to_string[code]] = bool(key_inputs & code)

	var mouse_x := buffer.get_float()
	var mouse_y := buffer.get_float()
	out["mouse_pos"] = Vector2(mouse_x, mouse_y)

	return out
