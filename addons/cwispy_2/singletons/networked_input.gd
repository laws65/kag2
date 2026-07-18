extends Node


@onready var _inputs := RingBuffer.new(50)


var _time: int = 0


func _ready() -> void:
	NetworkedClock.pretick.connect(_on_pre_tick)


func _on_pre_tick() -> void:
	if multiplayer.is_server():
		NetworkedClock.pretick.disconnect(_on_pre_tick)
	else:
		_time = NetworkedClock.time_ticks
		_save_inputs()


func _save_inputs() -> void:
	var input_to_save: Dictionary[StringName, Variant]
	var input_names := InputMap.get_actions()
	for input_name: StringName in input_names:
		if not input_name.begins_with("ui_"):
			input_to_save[input_name] = Input.is_action_pressed(input_name)
	input_to_save[&"mouse_pos"] = get_tree().root.get_node("Main/World").get_global_mouse_position()
	input_to_save[&"timestamp"] = _time
	_inputs.put(input_to_save, _time)


func is_action_pressed(action: StringName, time: int = _time) -> bool:
	var input: Dictionary = _inputs.retrieve(time)
	if input[&"timestamp"] != time:
		return false
	
	return input.get(action, false)


func is_action_just_released(action: StringName, time: int = _time) -> bool:
	return not is_action_pressed(action, time) and is_action_pressed(action, time-1)


func is_action_just_pressed(action: StringName, time: int = _time) -> bool:
	return is_action_pressed(action, time) and not is_action_pressed(action, time-1)


func get_vector(left: StringName, right: StringName, up: StringName, down: StringName, time: int = _time) -> Vector2:
	return Vector2(
		int(is_action_pressed(right, time)) - int(is_action_pressed(left, time)),
		int(is_action_pressed(down, time)) - int(is_action_pressed(up, time))
	).normalized()
